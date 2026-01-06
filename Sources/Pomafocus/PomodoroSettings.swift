import AppKit

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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func snapshot() -> Snapshot {
        Snapshot(minutes: storedMinutes(), hotkey: storedHotkey())
    }

    func save(_ snapshot: Snapshot) {
        defaults.set(snapshot.minutes, forKey: Keys.minutes)
        if let data = try? JSONEncoder().encode(snapshot.hotkey) {
            defaults.set(data, forKey: Keys.hotkey)
        }
    }

    private func storedMinutes() -> Int {
        let value = defaults.integer(forKey: Keys.minutes)
        return value > 0 ? value : 25
    }

    private func storedHotkey() -> Hotkey {
        guard let data = defaults.data(forKey: Keys.hotkey),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return .default
        }
        return hotkey
    }
}
