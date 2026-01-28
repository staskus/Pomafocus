import Foundation
import FamilyControls
import PomafocusKit

@MainActor
final class ScheduleCoordinator {
    private let blocker: PomodoroBlocker
    private let store: ScheduleStore
    private let notifier: ScheduleNotificationManager
    private let calendar = Calendar.current
    private var timer: Timer?
    private var activeBlockID: UUID?
    private var lastActiveBlock: ScheduleBlock?
    private var lastScheduleEnabled: Bool?
    private var lastScheduleName: String?

    init(
        blocker: PomodoroBlocker,
        store: ScheduleStore,
        notifier: ScheduleNotificationManager = .shared
    ) {
        self.blocker = blocker
        self.store = store
        self.notifier = notifier
        Task { @MainActor in
            await notifier.requestAuthorizationIfNeeded()
        }
        startTimer()
        evaluateSchedule()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateSchedule()
            }
        }
    }

    private func evaluateSchedule() {
        let schedule = store.selectedSchedule
        let isEnabled = schedule?.isEnabled ?? false
        if let previous = lastScheduleEnabled, previous != isEnabled, let scheduleName = schedule?.name ?? lastScheduleName {
            notifier.notifyScheduleChange(isEnabled: isEnabled, scheduleName: scheduleName)
        }
        lastScheduleEnabled = isEnabled
        lastScheduleName = schedule?.name ?? lastScheduleName

        guard let schedule, isEnabled else {
            stopActiveBlock()
            return
        }

        let now = Date()
        guard let block = activeBlock(in: schedule, at: now) else {
            stopActiveBlock()
            return
        }

        let selection = store.blockListSelection(for: block)
        switch block.kind {
        case .focus:
            blocker.beginScheduleBlocking(selection: selection ?? FamilyActivitySelection())
        case .break:
            blocker.endScheduleBlocking()
        }

        if activeBlockID != block.id {
            if let lastActiveBlock {
                notifier.notifyBlockEnd(lastActiveBlock)
            }
            notifier.notifyBlockStart(block)
        }
        activeBlockID = block.id
        lastActiveBlock = block
        store.activeBlock = block
    }

    private func stopActiveBlock() {
        if let lastActiveBlock {
            notifier.notifyBlockEnd(lastActiveBlock)
        }
        activeBlockID = nil
        lastActiveBlock = nil
        store.activeBlock = nil
        blocker.endScheduleBlocking()
    }

    private func activeBlock(in schedule: FocusSchedule, at date: Date) -> ScheduleBlock? {
        let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .monday
        let minute = minutesSinceMidnight(for: date)
        return schedule.blocks.first { block in
            block.applies(to: weekday) && minute >= block.startMinutes && minute < block.endMinutes
        }
    }

    private func minutesSinceMidnight(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return (hour * 60) + minute
    }
}
