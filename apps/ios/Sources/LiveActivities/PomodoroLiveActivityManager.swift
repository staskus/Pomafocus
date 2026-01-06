#if canImport(ActivityKit)
import ActivityKit
import Foundation
import OSLog
import PomafocusKit

@MainActor
final class PomodoroLiveActivityManager {
    private var activity: Activity<PomodoroActivityAttributes>?
    private let logger = Logger(subsystem: "com.staskus.pomafocus", category: "LiveActivity")

    func bind(to session: PomodoroSessionController) {
        startOrUpdate(from: session)
    }

    func startOrUpdate(from session: PomodoroSessionController) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let remaining = Int(session.remaining)
        let duration = session.currentDurationSeconds
        let startDate = session.currentSessionStart
        let endDate = startDate?.addingTimeInterval(TimeInterval(duration))
        let contentState = PomodoroActivityAttributes.ContentState(
            remainingSeconds: remaining,
            durationSeconds: duration,
            startedAt: startDate,
            endsAt: endDate,
            isRunning: session.isRunning
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            if let activity = self.activity, session.isRunning {
                await activity.update(ActivityContent(state: contentState, staleDate: nil))
            } else if session.isRunning {
                let attributes = PomodoroActivityAttributes(title: "Focus Session")
                do {
                    self.activity = try Activity.request(
                        attributes: attributes,
                        contentState: contentState,
                        pushType: nil
                    )
                } catch {
                    self.logger.error("Failed to start live activity: \(String(describing: error))")
                }
            } else {
                await self.end()
            }
        }
    }

    func end() async {
        guard let activity else { return }
        await activity.end(dismissalPolicy: .immediate)
        self.activity = nil
    }

    func end() {
        Task { @MainActor [weak self] in
            await self?.end()
        }
    }
}
#else
final class PomodoroLiveActivityManager {
    func bind(to session: PomodoroSessionController) {}
    func startOrUpdate(from session: PomodoroSessionController) {}
    func end() {}
}
#endif
