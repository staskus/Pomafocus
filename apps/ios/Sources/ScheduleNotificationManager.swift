import Foundation
import UserNotifications

@MainActor
final class ScheduleNotificationManager {
    static let shared = ScheduleNotificationManager()

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

    func notifyScheduleChange(isEnabled: Bool, scheduleName: String) {
        let title = isEnabled ? "Schedule started" : "Schedule paused"
        let body = isEnabled ? "\(scheduleName) is now active." : "\(scheduleName) is now paused."
        deliver(title: title, body: body)
    }

    func notifyBlockStart(_ block: ScheduleBlock) {
        let title = block.kind == .focus ? "Focus block started" : "Break started"
        let body = "\(block.title) • \(timeRange(for: block))"
        deliver(title: title, body: body)
    }

    func notifyBlockEnd(_ block: ScheduleBlock) {
        let title = block.kind == .focus ? "Focus block ended" : "Break ended"
        let body = "\(block.title) • \(timeRange(for: block))"
        deliver(title: title, body: body)
    }

    private func deliver(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func timeRange(for block: ScheduleBlock) -> String {
        let start = format(minutes: block.startMinutes)
        let end = format(minutes: block.endMinutes)
        return "\(start)–\(end)"
    }

    private func format(minutes: Int) -> String {
        let hour = minutes / 60
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}
