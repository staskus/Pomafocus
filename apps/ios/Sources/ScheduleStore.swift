import Foundation
import Observation
import Combine
import FamilyControls
import PomafocusKit

@MainActor
@Observable
final class ScheduleStore {
    var schedules: [FocusSchedule]
    var selectedScheduleID: UUID?
    var blockLists: [BlockList]
    var defaultBlockListID: UUID?
    var activeBlock: ScheduleBlock?

    private let defaults: UserDefaults
    private let schedulesKey = "pomafocus.schedules"
    private let selectedKey = "pomafocus.schedules.selected"
    private let blockListsKey = "pomafocus.blocklists"
    private let defaultBlockListKey = "pomafocus.blocklists.default"
    private var blockerSelectionCancellable: AnyCancellable?

    init() {
        let defaults: UserDefaults
        if let appGroup = UserDefaults(suiteName: "group.com.staskus.pomafocus") {
            defaults = appGroup
        } else {
            defaults = .standard
        }

        let blockerSelection = PomodoroBlocker.shared.selection
        let decodedBlockLists: [BlockList]
        if let data = defaults.data(forKey: blockListsKey),
           let decoded = try? JSONDecoder().decode([BlockList].self, from: data) {
            decodedBlockLists = decoded
        } else {
            decodedBlockLists = [BlockList(name: "Default", selection: blockerSelection)]
        }

        let defaultBlockListID: UUID?
        if let storedID = defaults.string(forKey: defaultBlockListKey),
           let uuid = UUID(uuidString: storedID),
           decodedBlockLists.contains(where: { $0.id == uuid }) {
            defaultBlockListID = uuid
        } else {
            defaultBlockListID = decodedBlockLists.first?.id
        }

        let decodedSchedules: [FocusSchedule]
        if let data = defaults.data(forKey: schedulesKey) {
            if let decoded = try? JSONDecoder().decode([LegacyFocusSchedule].self, from: data) {
                decodedSchedules = decoded.map { legacy in
                    let blocks = legacy.blocks.map { block -> ScheduleBlock in
                        guard block.kind == .focus, block.blockListID == nil else { return block }
                        guard let legacyDefault = legacy.defaultBlockListID else { return block }
                        var updated = block
                        updated.blockListID = legacyDefault
                        return updated
                    }
                    return FocusSchedule(id: legacy.id, name: legacy.name, isEnabled: legacy.isEnabled, blocks: blocks)
                }
            } else if let decoded = try? JSONDecoder().decode([FocusSchedule].self, from: data) {
                decodedSchedules = decoded
            } else {
                decodedSchedules = [FocusSchedule(name: "Workday", isEnabled: false, blocks: [])]
            }
        } else {
            decodedSchedules = [FocusSchedule(name: "Workday", isEnabled: false, blocks: [])]
        }

        let selectedScheduleID: UUID?
        if let storedID = defaults.string(forKey: selectedKey),
           let uuid = UUID(uuidString: storedID),
           decodedSchedules.contains(where: { $0.id == uuid }) {
            selectedScheduleID = uuid
        } else {
            selectedScheduleID = decodedSchedules.first?.id
        }

        self.defaults = defaults
        self.blockLists = decodedBlockLists
        self.defaultBlockListID = defaultBlockListID
        self.schedules = decodedSchedules
        self.selectedScheduleID = selectedScheduleID

        migrateLegacyBlockSelections()
        syncDefaultBlockListToBlocker()
        observeBlockerSelection()
    }

    var selectedSchedule: FocusSchedule? {
        guard let selectedScheduleID else { return nil }
        return schedules.first(where: { $0.id == selectedScheduleID })
    }

    func updateSchedule(_ schedule: FocusSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            schedules.append(schedule)
        }
        persistSchedules()
    }

    func addSchedule(named name: String) -> FocusSchedule {
        let schedule = FocusSchedule(name: name, isEnabled: false, blocks: [])
        schedules.append(schedule)
        persistSchedules()
        return schedule
    }

    func removeSchedule(_ scheduleID: UUID) {
        schedules.removeAll { $0.id == scheduleID }
        if selectedScheduleID == scheduleID {
            selectedScheduleID = schedules.first?.id
        }
        persistSchedules()
        persistSelection()
    }

    func addBlock(_ block: ScheduleBlock, to scheduleID: UUID) {
        guard var schedule = schedules.first(where: { $0.id == scheduleID }) else { return }
        schedule.blocks.append(block)
        schedule.blocks.sort { $0.startMinutes < $1.startMinutes }
        updateSchedule(schedule)
    }

    func addBlocks(_ blocks: [ScheduleBlock], to scheduleID: UUID) {
        guard var schedule = schedules.first(where: { $0.id == scheduleID }) else { return }
        schedule.blocks.append(contentsOf: blocks)
        schedule.blocks.sort { $0.startMinutes < $1.startMinutes }
        updateSchedule(schedule)
    }

    func updateBlock(_ block: ScheduleBlock, in scheduleID: UUID) {
        guard var schedule = schedules.first(where: { $0.id == scheduleID }) else { return }
        if let index = schedule.blocks.firstIndex(where: { $0.id == block.id }) {
            schedule.blocks[index] = block
            schedule.blocks.sort { $0.startMinutes < $1.startMinutes }
            updateSchedule(schedule)
        }
    }

    func removeBlock(_ blockID: UUID, from scheduleID: UUID) {
        guard var schedule = schedules.first(where: { $0.id == scheduleID }) else { return }
        schedule.blocks.removeAll { $0.id == blockID }
        updateSchedule(schedule)
    }

    func setSelectedSchedule(_ scheduleID: UUID?) {
        selectedScheduleID = scheduleID
        persistSelection()
    }

    func updateBlockList(_ list: BlockList) {
        if let index = blockLists.firstIndex(where: { $0.id == list.id }) {
            blockLists[index] = list
        } else {
            blockLists.append(list)
        }
        persistBlockLists()
        if defaultBlockListID == list.id {
            syncDefaultBlockListToBlocker()
        }
    }

    func addBlockList(named name: String, selection: FamilyActivitySelection) -> BlockList {
        let list = BlockList(name: name, selection: selection)
        blockLists.append(list)
        persistBlockLists()
        return list
    }

    func removeBlockList(_ listID: UUID) {
        blockLists.removeAll { $0.id == listID }
        schedules = schedules.map { schedule in
            var updated = schedule
            updated.blocks = updated.blocks.map { block in
                guard block.blockListID == listID else { return block }
                var replacement = block
                replacement.blockListID = nil
                return replacement
            }
            return updated
        }
        if defaultBlockListID == listID {
            defaultBlockListID = blockLists.first?.id
        }
        persistBlockLists()
        persistSchedules()
        syncDefaultBlockListToBlocker()
    }

    func setDefaultBlockList(_ listID: UUID?) {
        defaultBlockListID = listID
        persistBlockLists()
        syncDefaultBlockListToBlocker()
    }

    func blockListSelection(for block: ScheduleBlock) -> FamilyActivitySelection? {
        if let blockID = block.blockListID,
           let list = blockLists.first(where: { $0.id == blockID }) {
            return list.selection
        }
        if let defaultBlockListID,
           let list = blockLists.first(where: { $0.id == defaultBlockListID }) {
            return list.selection
        }
        return nil
    }

    private func persistSchedules() {
        guard let data = try? JSONEncoder().encode(schedules) else { return }
        defaults.set(data, forKey: schedulesKey)
        persistSelection()
    }

    private func persistBlockLists() {
        guard let data = try? JSONEncoder().encode(blockLists) else { return }
        defaults.set(data, forKey: blockListsKey)
        defaults.set(defaultBlockListID?.uuidString, forKey: defaultBlockListKey)
    }

    private func persistSelection() {
        defaults.set(selectedScheduleID?.uuidString, forKey: selectedKey)
    }

    private func migrateLegacyBlockSelections() {
        guard blockLists.count == 1, let defaultBlockListID else { return }
        let hasLegacySelections = schedules.contains { schedule in
            schedule.blocks.contains { $0.selection != nil }
        }
        guard hasLegacySelections else { return }

        let migratedDefault = blockLists.first
        var createdLists: [BlockList] = []

        schedules = schedules.map { schedule in
            var updated = schedule
            updated.blocks = schedule.blocks.map { block in
                guard let selection = block.selection else { return block }
                if selection == migratedDefault?.selection {
                    var updatedBlock = block
                    updatedBlock.blockListID = defaultBlockListID
                    updatedBlock.selection = nil
                    return updatedBlock
                }
                let list = BlockList(name: "Imported", selection: selection)
                createdLists.append(list)
                var updatedBlock = block
                updatedBlock.blockListID = list.id
                updatedBlock.selection = nil
                return updatedBlock
            }
            return updated
        }

        if !createdLists.isEmpty {
            blockLists.append(contentsOf: createdLists)
        }
        persistBlockLists()
        persistSchedules()
    }

    private struct LegacyFocusSchedule: Codable {
        var id: UUID
        var name: String
        var isEnabled: Bool
        var defaultBlockListID: UUID?
        var blocks: [ScheduleBlock]
    }

    private func syncDefaultBlockListToBlocker() {
        guard let defaultBlockListID,
              let list = blockLists.first(where: { $0.id == defaultBlockListID }) else { return }
        PomodoroBlocker.shared.selection = list.selection
    }

    private func observeBlockerSelection() {
        blockerSelectionCancellable = PomodoroBlocker.shared.$selection.sink { [weak self] selection in
            guard let self,
                  let defaultBlockListID,
                  let index = self.blockLists.firstIndex(where: { $0.id == defaultBlockListID }) else { return }
            if self.isSameSelection(self.blockLists[index].selection, selection) {
                return
            }
            self.blockLists[index].selection = selection
            self.persistBlockLists()
        }
    }

    private func isSameSelection(_ lhs: FamilyActivitySelection, _ rhs: FamilyActivitySelection) -> Bool {
        let encoder = JSONEncoder()
        guard let left = try? encoder.encode(lhs),
              let right = try? encoder.encode(rhs) else { return false }
        return left == right
    }
}
