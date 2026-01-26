import AppKit
#if canImport(PomafocusKit)
import PomafocusKit
#endif

@MainActor
final class PomodoroSettings {
    struct Snapshot {
        var minutes: Int
        var hotkey: Hotkey
        var deepBreathEnabled: Bool
        var startScriptPath: String
        var stopScriptPath: String
    }

    private enum Keys {
        static let minutes = "pomodoro.minutes"
        static let hotkey = "pomodoro.hotkey"
        static let deepBreath = "pomodoro.deepBreathEnabled"
        static let startScriptPath = "pomodoro.startScriptPath"
        static let stopScriptPath = "pomodoro.stopScriptPath"
    }

    private let defaults: UserDefaults
    private let syncManager: PomodoroSyncManager

    init(defaults: UserDefaults = .standard, syncManager: PomodoroSyncManager = .shared) {
        self.defaults = defaults
        self.syncManager = syncManager
    }

    func snapshot() -> Snapshot {
        let preferences = syncManager.currentPreferences()
        return Snapshot(
            minutes: preferences.minutes,
            hotkey: storedHotkey(),
            deepBreathEnabled: preferences.deepBreathEnabled,
            startScriptPath: defaults.string(forKey: Keys.startScriptPath) ?? "",
            stopScriptPath: defaults.string(forKey: Keys.stopScriptPath) ?? ""
        )
    }

    func save(_ snapshot: Snapshot) {
        defaults.set(snapshot.minutes, forKey: Keys.minutes)
        defaults.set(snapshot.deepBreathEnabled, forKey: Keys.deepBreath)
        defaults.set(snapshot.startScriptPath, forKey: Keys.startScriptPath)
        defaults.set(snapshot.stopScriptPath, forKey: Keys.stopScriptPath)
        syncManager.publishPreferences(minutes: snapshot.minutes, deepBreathEnabled: snapshot.deepBreathEnabled)
        if let data = try? JSONEncoder().encode(snapshot.hotkey) {
            defaults.set(data, forKey: Keys.hotkey)
        }
    }

    func updatePreferencesFromSync(minutes: Int, deepBreathEnabled: Bool) {
        defaults.set(minutes, forKey: Keys.minutes)
        defaults.set(deepBreathEnabled, forKey: Keys.deepBreath)
    }

    private func storedHotkey() -> Hotkey {
        guard let data = defaults.data(forKey: Keys.hotkey),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return .default
        }
        return hotkey
    }
}
