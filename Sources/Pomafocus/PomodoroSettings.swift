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
    }

    private enum Keys {
        static let minutes = "pomodoro.minutes"
        static let hotkey = "pomodoro.hotkey"
        static let deepBreath = "pomodoro.deepBreathEnabled"
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
            deepBreathEnabled: preferences.deepBreathEnabled
        )
    }

    func save(_ snapshot: Snapshot) {
        defaults.set(snapshot.minutes, forKey: Keys.minutes)
        defaults.set(snapshot.deepBreathEnabled, forKey: Keys.deepBreath)
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
