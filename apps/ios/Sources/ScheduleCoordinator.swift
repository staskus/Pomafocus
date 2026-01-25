import Foundation
import FamilyControls
import PomafocusKit

@MainActor
final class ScheduleCoordinator {
    private let session: PomodoroSessionController
    private let blocker: PomodoroBlocker
    private let store: ScheduleStore
    private let calendar = Calendar.current
    private var timer: Timer?
    private var activeBlockID: UUID?

    init(session: PomodoroSessionController, blocker: PomodoroBlocker, store: ScheduleStore) {
        self.session = session
        self.blocker = blocker
        self.store = store
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
        guard let schedule = store.selectedSchedule, schedule.isEnabled else {
            activeBlockID = nil
            blocker.overrideSelection = nil
            if session.isRunning {
                session.stopScheduledSessionIfNeeded()
            }
            return
        }

        let now = Date()
        guard let block = activeBlock(in: schedule, at: now) else {
            activeBlockID = nil
            blocker.overrideSelection = nil
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
