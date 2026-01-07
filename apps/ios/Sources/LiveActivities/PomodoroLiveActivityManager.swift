#if canImport(ActivityKit)
import ActivityKit
import Foundation
import OSLog
import PomafocusKit
import UserNotifications

@MainActor
final class PomodoroLiveActivityManager {
    private var activity: Activity<PomodoroActivityAttributes>?
    private let logger = Logger(subsystem: "com.staskus.pomafocus", category: "LiveActivity")
    private var hasRequestedNotificationPermission = false

    func bind(to session: PomodoroSessionController) {
        Task { @MainActor [weak self] in
            await self?.performUpdate(for: session, isRemoteUpdate: false)
        }
    }

    func startOrUpdate(from session: PomodoroSessionController) {
        Task { @MainActor [weak self] in
            await self?.performUpdate(for: session, isRemoteUpdate: false)
        }
    }

    func startOrUpdateImmediately(from session: PomodoroSessionController) async {
        await performUpdate(for: session, isRemoteUpdate: true)
    }

    private func performUpdate(for session: PomodoroSessionController, isRemoteUpdate: Bool) async {
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

        await reconcileExistingActivities()
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
            } catch ActivityAuthorizationError.visibility {
                logger.info("Cannot start Live Activity from background, sending local notification")
                if isRemoteUpdate {
                    await sendBackgroundSessionNotification(remainingMinutes: remaining / 60)
                }
            } catch {
                self.logger.error("Failed to start live activity: \(String(describing: error))")
            }
        } else {
            await self.end()
        }
    }

    private func sendBackgroundSessionNotification(remainingMinutes: Int) async {
        let center = UNUserNotificationCenter.current()

        if !hasRequestedNotificationPermission {
            hasRequestedNotificationPermission = true
            try? await center.requestAuthorization(options: [.alert, .sound])
        }

        let content = UNMutableNotificationContent()
        content.title = "Focus Session Active"
        content.body = "A \(remainingMinutes)-minute focus session started. Tap to track progress."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "com.staskus.pomafocus.backgroundSession",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to send background session notification: \(error)")
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

    private func reconcileExistingActivities() async {
        let existing = Activity<PomodoroActivityAttributes>.activities
        if let first = existing.first {
            if activity?.id != first.id {
                activity = first
            }
            if existing.count > 1 {
                for duplicate in existing.dropFirst() {
                    await duplicate.end(dismissalPolicy: .immediate)
                }
            }
        } else {
            activity = nil
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
