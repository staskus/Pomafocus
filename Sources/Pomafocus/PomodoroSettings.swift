import AppKit
#if canImport(PomafocusKit)
import PomafocusKit
#endif

@MainActor
final class PomodoroSettings {
    struct Snapshot {
        var minutes: Int
        var hotkey: Hotkey
    }

    private enum Keys {
        static let minutes = "pomodoro.minutes"
        static let hotkey = "pomodoro.hotkey"
    }

    private let defaults: UserDefaults
    private let syncManager: PomodoroSyncManager

    init(defaults: UserDefaults = .standard, syncManager: PomodoroSyncManager = .shared) {
        self.defaults = defaults
        self.syncManager = syncManager
    }

    func snapshot() -> Snapshot {
        let minutes = syncManager.currentPreferences().minutes
        return Snapshot(minutes: minutes, hotkey: storedHotkey())
    }

    func save(_ snapshot: Snapshot) {
        defaults.set(snapshot.minutes, forKey: Keys.minutes)
        syncManager.publishPreferences(minutes: snapshot.minutes)
        if let data = try? JSONEncoder().encode(snapshot.hotkey) {
            defaults.set(data, forKey: Keys.hotkey)
        }
    }

    func updateMinutesFromSync(_ minutes: Int) {
        defaults.set(minutes, forKey: Keys.minutes)
    }

    private func storedHotkey() -> Hotkey {
        guard let data = defaults.data(forKey: Keys.hotkey),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return .default
        }
        return hotkey
    }
}
