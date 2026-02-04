#if os(macOS)
import AppKit
import Foundation

@MainActor
public final class PomodoroBlocker: ObservableObject, PomodoroBlocking {
    public static let shared = PomodoroBlocker()

    private let defaults: UserDefaults
    private let commandURLBase = "pomafocus://"
    private let companionBundleID = "com.povilasstaskus.pomafocus.ios"
    private let openURL: (URL) -> Bool
    private let canOpenCommandURL: (URL) -> Bool
    private let openCommandWithCompanion: (URL) -> Bool
    private let launchCompanionApp: () -> Bool

    private enum Keys {
        static let screenTimeCompanionEnabled = "pomodoro.screenTimeCompanionEnabled"
    }

    public private(set) var screenTimeCompanionEnabled: Bool

    init(
        defaults: UserDefaults = .standard,
        openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) },
        canOpenCommandURL: @escaping (URL) -> Bool = { url in
            NSWorkspace.shared.urlForApplication(toOpen: url) != nil
        },
        openCommandWithCompanion: @escaping (URL) -> Bool = { url in
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.povilasstaskus.pomafocus.ios") else {
                return false
            }
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: .init()) { _, error in
                if let error {
                    NSLog("Failed to open companion command URL: %@", error.localizedDescription)
                }
            }
            return true
        },
        launchCompanionApp: @escaping () -> Bool = {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.povilasstaskus.pomafocus.ios") else {
                return false
            }
            NSWorkspace.shared.openApplication(at: appURL, configuration: .init(), completionHandler: nil)
            return true
        }
    ) {
        self.defaults = defaults
        self.openURL = openURL
        self.canOpenCommandURL = canOpenCommandURL
        self.openCommandWithCompanion = openCommandWithCompanion
        self.launchCompanionApp = launchCompanionApp
        screenTimeCompanionEnabled = defaults.bool(forKey: Keys.screenTimeCompanionEnabled)
    }

    public func setScreenTimeCompanionEnabled(_ enabled: Bool) {
        screenTimeCompanionEnabled = enabled
        defaults.set(enabled, forKey: Keys.screenTimeCompanionEnabled)
    }

    public func beginBlocking() {
        guard screenTimeCompanionEnabled else { return }
        _ = sendCompanionCommand("block-on")
    }

    public func endBlocking() {
        guard screenTimeCompanionEnabled else { return }
        _ = sendCompanionCommand("block-off")
    }

    @discardableResult
    public func openScreenTimeSettings() -> Bool {
        sendCompanionCommand("screen-time")
    }

    public var isCompanionInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: companionBundleID) != nil
    }

    public var hasSelection: Bool {
        screenTimeCompanionEnabled
    }

    public var selectionSummary: String {
        screenTimeCompanionEnabled ? "Screen Time via companion app" : "Screen Time companion disabled"
    }

    @discardableResult
    private func sendCompanionCommand(_ command: String) -> Bool {
        guard let url = URL(string: "\(commandURLBase)\(command)") else {
            return false
        }
        if canOpenCommandURL(url) {
            return openURL(url)
        }
        if openCommandWithCompanion(url) {
            return true
        }
        return launchCompanionApp()
    }
}
#endif
