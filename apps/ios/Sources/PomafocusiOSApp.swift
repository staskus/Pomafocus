import PomafocusKit
import SwiftUI
import UIKit

@main
struct PomafocusiOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var core = PomafocusCore.shared

    var body: some Scene {
        WindowGroup {
            ContentView(session: core.session)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = PomafocusCore.shared
        if EntitlementChecker.hasPushEntitlement {
            application.registerForRemoteNotifications()
        } else {
            NSLog("Skipping remote notifications registration; APS entitlement missing.")
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            _ = PomafocusCore.shared
            let handled = await PomodoroSyncManager.shared.handleRemoteNotification(userInfo)
            await PomafocusCore.shared.refreshLiveActivity()
            completionHandler(handled ? .newData : .noData)
        }
    }
}
