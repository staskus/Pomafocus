@preconcurrency import Foundation

@MainActor
public final class PomodoroSyncManager {
    public static let shared = PomodoroSyncManager()

    public var onStateChange: ((PomodoroSharedState) -> Void)?
    public var onPreferencesChange: ((PomodoroPreferencesSnapshot) -> Void)?
    public let deviceIdentifier: String

    private let store: NSUbiquitousKeyValueStore?
    private let defaults: UserDefaults
    private let cloudSync: PomodoroCloudSyncing
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var observing = false
    @preconcurrency private var storeObserver: NSObjectProtocol?

    private enum Keys {
        static let state = "pomafocus.shared.state"
        static let preferences = "pomafocus.shared.preferences"
        static let deviceID = "pomafocus.device.identifier"
        static let fallbackMinutes = "pomodoro.minutes"
        static let deepBreathEnabled = "pomodoro.deepBreathEnabled"
    }

    init(
        store: NSUbiquitousKeyValueStore? = .default,
        defaults: UserDefaults = .standard,
        cloudSync: PomodoroCloudSyncing? = nil
    ) {
        self.store = store
        self.defaults = defaults
        self.cloudSync = cloudSync ?? CloudKitPomodoroSync()
        if let storedID = defaults.string(forKey: Keys.deviceID) {
            deviceIdentifier = storedID
        } else {
            let identifier = UUID().uuidString
            defaults.set(identifier, forKey: Keys.deviceID)
            deviceIdentifier = identifier
        }
        wireCloudCallbacks()
    }

    deinit {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
    }

    public func start() {
        guard !observing else { return }
        observing = true
        if let store {
            storeObserver = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store,
                queue: .main
            ) { [weak self] notification in
                guard
                    let userInfo = notification.userInfo,
                    let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
                else {
                    return
                }
                let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
                Task { @MainActor [weak self] in
                    self?.handleStoreChange(reason: reason, changedKeys: changedKeys)
                }
            }
            store.synchronize()
        }
        cloudSync.start()
    }

    public func currentState() -> PomodoroSharedState {
        if let data = data(forKey: Keys.state),
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
        if let data = data(forKey: Keys.preferences),
           let decoded = try? decoder.decode(PomodoroPreferencesSnapshot.self, from: data) {
            defaults.set(decoded.minutes, forKey: Keys.fallbackMinutes)
            defaults.set(decoded.deepBreathEnabled, forKey: Keys.deepBreathEnabled)
            return decoded
        }
        let fallback = storedFallbackPreferences()
        return PomodoroPreferencesSnapshot(
            minutes: fallback.minutes,
            deepBreathEnabled: fallback.deepBreathEnabled,
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
        cloudSync.publish(state: state)
    }

    public func publishPreferences(minutes: Int, deepBreathEnabled: Bool) {
        defaults.set(minutes, forKey: Keys.fallbackMinutes)
        defaults.set(deepBreathEnabled, forKey: Keys.deepBreathEnabled)
        let snapshot = PomodoroPreferencesSnapshot(
            minutes: minutes,
            deepBreathEnabled: deepBreathEnabled,
            updatedAt: Date(),
            originIdentifier: deviceIdentifier
        )
        savePreferences(snapshot)
        onPreferencesChange?(snapshot)
        cloudSync.publish(preferences: snapshot)
    }

    @discardableResult
    public func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
        await cloudSync.handleRemoteNotification(userInfo)
    }

    private func saveState(_ state: PomodoroSharedState) {
        guard let data = try? encoder.encode(state) else { return }
        set(data, forKey: Keys.state)
    }

    private func savePreferences(_ preferences: PomodoroPreferencesSnapshot) {
        guard let data = try? encoder.encode(preferences) else { return }
        set(data, forKey: Keys.preferences)
    }

    private func storedFallbackPreferences() -> (minutes: Int, deepBreathEnabled: Bool) {
        let stored = defaults.integer(forKey: Keys.fallbackMinutes)
        let minutes = stored > 0 ? stored : 25
        let deepBreath = defaults.bool(forKey: Keys.deepBreathEnabled)
        return (minutes, deepBreath)
    }

    private func handleStoreChange(reason: Int, changedKeys: [String]) {
        switch reason {
        case NSUbiquitousKeyValueStoreServerChange,
             NSUbiquitousKeyValueStoreInitialSyncChange,
             NSUbiquitousKeyValueStoreQuotaViolationChange:
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

    private func data(forKey key: String) -> Data? {
        if let store {
            return store.data(forKey: key)
        } else {
            return defaults.data(forKey: key)
        }
    }

    private func set(_ data: Data, forKey key: String) {
        if let store {
            store.set(data, forKey: key)
            store.synchronize()
        } else {
            defaults.set(data, forKey: key)
        }
    }
    
    private func wireCloudCallbacks() {
        cloudSync.onStateChange = { [weak self] state in
            guard let self else { return }
            if state.originIdentifier == self.deviceIdentifier { return }
            self.saveState(state)
            self.onStateChange?(state)
        }
        cloudSync.onPreferencesChange = { [weak self] snapshot in
            guard let self else { return }
            if snapshot.originIdentifier == self.deviceIdentifier { return }
            self.savePreferences(snapshot)
            self.onPreferencesChange?(snapshot)
        }
    }
}
extension PomodoroSyncManager: PomodoroSyncManaging {}
