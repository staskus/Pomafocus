import Foundation
import UserNotifications

@MainActor
final class PomodoroSyncNotificationManager {
    static let shared = PomodoroSyncNotificationManager()

    private var didRequestAuthorization = false

    private init() {}

    func requestAuthorizationIfNeeded() async {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            // Ignore; notifications are best-effort.
        }
    }

    func notifyExternalStart(durationMinutes: Int) {
        Task { @MainActor in
            await requestAuthorizationIfNeeded()
            let content = UNMutableNotificationContent()
            content.title = "Focus started on another device"
            content.body = "\(max(1, durationMinutes))-minute timer is now running."
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                // Ignore; notifications are best-effort.
            }
        }
    }
}
