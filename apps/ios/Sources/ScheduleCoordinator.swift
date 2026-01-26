import Foundation
import FamilyControls
import PomafocusKit

@MainActor
final class ScheduleCoordinator {
    private let session: PomodoroSessionController
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
        session: PomodoroSessionController,
        blocker: PomodoroBlocker,
        store: ScheduleStore,
        notifier: ScheduleNotificationManager = .shared
    ) {
        self.session = session
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
            activeBlockID = nil
            blocker.overrideSelection = nil
            if let lastActiveBlock {
                notifier.notifyBlockEnd(lastActiveBlock)
                self.lastActiveBlock = nil
            }
            if session.isRunning {
                session.stopScheduledSessionIfNeeded()
            }
            return
        }

        let now = Date()
        guard let block = activeBlock(in: schedule, at: now) else {
            activeBlockID = nil
            blocker.overrideSelection = nil
            if let lastActiveBlock {
                notifier.notifyBlockEnd(lastActiveBlock)
                self.lastActiveBlock = nil
            }
            if session.isRunning {
                session.stopScheduledSessionIfNeeded()
            }
            return
        }

        if session.isRunning {
            if case .schedule(let blockID) = session.sessionOrigin, blockID == block.id {
                return
            }
            return
        }

        if let lastActiveBlock, lastActiveBlock.id != block.id {
            notifier.notifyBlockEnd(lastActiveBlock)
        }
        let remainingMinutes = max(1, block.endMinutes - minutesSinceMidnight(for: now))
        let selection = store.blockListSelection(for: block)
        switch block.kind {
        case .focus:
            blocker.overrideSelection = selection
            session.startScheduledSession(durationMinutes: remainingMinutes, tag: block.title, blockID: block.id)
        case .break:
            blocker.overrideSelection = FamilyActivitySelection()
            session.startScheduledSession(durationMinutes: remainingMinutes, tag: block.title, blockID: block.id)
        }
        activeBlockID = block.id
        lastActiveBlock = block
        notifier.notifyBlockStart(block)
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
