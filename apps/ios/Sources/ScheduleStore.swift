import Foundation
import Observation

@MainActor
@Observable
final class ScheduleStore {
    var schedules: [FocusSchedule]
    var selectedScheduleID: UUID?

    private let defaults: UserDefaults
    private let schedulesKey = "pomafocus.schedules"
    private let selectedKey = "pomafocus.schedules.selected"

    init() {
        if let appGroup = UserDefaults(suiteName: "group.com.staskus.pomafocus") {
            self.defaults = appGroup
        } else {
            self.defaults = .standard
        }
        if let data = defaults.data(forKey: schedulesKey),
           let decoded = try? JSONDecoder().decode([FocusSchedule].self, from: data) {
            self.schedules = decoded
        } else {
            self.schedules = [FocusSchedule(name: "Workday", isEnabled: false, blocks: [])]
        }
        if let storedID = defaults.string(forKey: selectedKey),
           let uuid = UUID(uuidString: storedID),
           schedules.contains(where: { $0.id == uuid }) {
            self.selectedScheduleID = uuid
        } else {
            self.selectedScheduleID = schedules.first?.id
        }
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
        persist()
    }

    func addBlock(_ block: ScheduleBlock, to scheduleID: UUID) {
        guard var schedule = schedules.first(where: { $0.id == scheduleID }) else { return }
        schedule.blocks.append(block)
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

    private func persist() {
        guard let data = try? JSONEncoder().encode(schedules) else { return }
        defaults.set(data, forKey: schedulesKey)
        persistSelection()
    }

    private func persistSelection() {
        defaults.set(selectedScheduleID?.uuidString, forKey: selectedKey)
    }
}
