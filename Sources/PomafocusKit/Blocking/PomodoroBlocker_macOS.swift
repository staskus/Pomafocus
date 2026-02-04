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

    private enum Keys {
        static let screenTimeCompanionEnabled = "pomodoro.screenTimeCompanionEnabled"
    }

    public private(set) var screenTimeCompanionEnabled: Bool

    init(
        defaults: UserDefaults = .standard,
        openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) {
        self.defaults = defaults
        self.openURL = openURL
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
        return openURL(url)
    }
}
#endif
