import AppKit
import PomafocusKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if EntitlementChecker.hasPushEntitlement {
            NSApplication.shared.registerForRemoteNotifications()
        } else {
            NSLog("Skipping remote notifications registration; APS entitlement missing.")
        }
        statusBarController = StatusBarController()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showPreferences()
        return true
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        handleRemoteNotification(userInfo)
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NSLog("Failed to register for remote notifications: \(error)")
    }

    private func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        Task {
            _ = await PomodoroSyncManager.shared.handleRemoteNotification(userInfo)
        }
    }
}
