import Foundation

@MainActor
public final class PomodoroSyncManager {
    public static let shared = PomodoroSyncManager()

    public var onStateChange: ((PomodoroSharedState) -> Void)?
    public var onPreferencesChange: ((PomodoroPreferencesSnapshot) -> Void)?
    public let deviceIdentifier: String

    private let store: NSUbiquitousKeyValueStore
    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var observing = false

    private enum Keys {
        static let state = "pomafocus.shared.state"
        static let preferences = "pomafocus.shared.preferences"
        static let deviceID = "pomafocus.device.identifier"
        static let fallbackMinutes = "pomodoro.minutes"
    }

    public init(
        store: NSUbiquitousKeyValueStore = .default,
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        self.store = store
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        if let storedID = defaults.string(forKey: Keys.deviceID) {
            deviceIdentifier = storedID
        } else {
            let identifier = UUID().uuidString
            defaults.set(identifier, forKey: Keys.deviceID)
            deviceIdentifier = identifier
        }
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    public func start() {
        guard !observing else { return }
        observing = true
        notificationCenter.addObserver(
            self,
            selector: #selector(storeDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    public func currentState() -> PomodoroSharedState {
        if let data = store.data(forKey: Keys.state),
           let decoded = try? decoder.decode(PomodoroSharedState.self, from: data) {
            return decoded
        }
        let minutes = currentPreferences().minutes
        return PomodoroSharedState(
            duration: minutes * 60,
            startedAt: nil,
            isRunning: false,
            updatedAt: Date(),
            originIdentifier: deviceIdentifier
        )
    }

    public func currentPreferences() -> PomodoroPreferencesSnapshot {
        if let data = store.data(forKey: Keys.preferences),
           let decoded = try? decoder.decode(PomodoroPreferencesSnapshot.self, from: data) {
            defaults.set(decoded.minutes, forKey: Keys.fallbackMinutes)
            return decoded
        }
        let fallback = storedFallbackMinutes()
        return PomodoroPreferencesSnapshot(
            minutes: fallback,
            updatedAt: Date(),
            originIdentifier: deviceIdentifier
        )
    }

    public func publishState(duration: Int, startedAt: Date?, isRunning: Bool) {
        let state = PomodoroSharedState(
            duration: duration,
            startedAt: startedAt,
            isRunning: isRunning,
            updatedAt: Date(),
            originIdentifier: deviceIdentifier
        )
        saveState(state)
    }

    public func publishPreferences(minutes: Int) {
        defaults.set(minutes, forKey: Keys.fallbackMinutes)
        let snapshot = PomodoroPreferencesSnapshot(
            minutes: minutes,
            updatedAt: Date(),
            originIdentifier: deviceIdentifier
        )
        savePreferences(snapshot)
        onPreferencesChange?(snapshot)
    }

    private func saveState(_ state: PomodoroSharedState) {
        guard let data = try? encoder.encode(state) else { return }
        store.set(data, forKey: Keys.state)
        store.synchronize()
    }

    private func savePreferences(_ preferences: PomodoroPreferencesSnapshot) {
        guard let data = try? encoder.encode(preferences) else { return }
        store.set(data, forKey: Keys.preferences)
        store.synchronize()
    }

    private func storedFallbackMinutes() -> Int {
        let stored = defaults.integer(forKey: Keys.fallbackMinutes)
        return stored > 0 ? stored : 25
    }

    @objc private func storeDidChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self,
                  let userInfo = notification.userInfo,
                  let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            else {
                return
            }

            switch reason {
            case NSUbiquitousKeyValueStoreServerChange,
                 NSUbiquitousKeyValueStoreInitialSyncChange,
                 NSUbiquitousKeyValueStoreQuotaViolationChange:
                let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
                if changedKeys.contains(Keys.state) {
                    onStateChange?(currentState())
                }
                if changedKeys.contains(Keys.preferences) {
                    let prefs = currentPreferences()
                    onPreferencesChange?(prefs)
                }
            default:
                break
            }
        }
    }
}
