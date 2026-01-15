import Foundation
import Testing
@testable import PomafocusKit

@MainActor
@Suite struct PomodoroSyncManagerTests {
    @Test func publishesPreferencesAndStoresFallback() throws {
        let store = MockStore()
        let defaults = temporaryDefaults()
        let cloud = MockCloudSync()
        let manager = PomodoroSyncManager(
            store: store,
            defaults: defaults,
            cloudSync: cloud
        )

        var received: PomodoroPreferencesSnapshot?
        manager.onPreferencesChange = { received = $0 }
        manager.publishPreferences(minutes: 35, deepBreathEnabled: true)

        #expect(received?.minutes == 35)
        #expect(received?.deepBreathEnabled == true)
        #expect(defaults.integer(forKey: "pomodoro.minutes") == 35)
        #expect(defaults.bool(forKey: "pomodoro.deepBreathEnabled") == true)

        let data = store.data(forKey: "pomafocus.shared.preferences")
        #expect(data != nil)
        if let data {
            let decoded = try JSONDecoder().decode(PomodoroPreferencesSnapshot.self, from: data)
            #expect(decoded.minutes == 35)
            #expect(decoded.deepBreathEnabled == true)
        }
    }

    @Test func currentPreferencesFallsBackToStoredMinutes() {
        let defaults = temporaryDefaults()
        defaults.set(42, forKey: "pomodoro.minutes")
        defaults.set(true, forKey: "pomodoro.deepBreathEnabled")
        let cloud = MockCloudSync()
        let manager = PomodoroSyncManager(
            store: MockStore(),
            defaults: defaults,
            cloudSync: cloud
        )

        let snapshot = manager.currentPreferences()
        #expect(snapshot.minutes == 42)
        #expect(snapshot.deepBreathEnabled == true)
    }

    @Test func publishStateForwardsToCloud() {
        let store = MockStore()
        let defaults = temporaryDefaults()
        let cloud = MockCloudSync()
        let manager = PomodoroSyncManager(
            store: store,
            defaults: defaults,
            cloudSync: cloud
        )

        manager.publishState(duration: 1500, startedAt: Date(), isRunning: true)
        #expect(cloud.publishedStates.count == 1)
        #expect(cloud.publishedStates.first?.duration == 1500)
        #expect(cloud.startCount == 0)
    }

    @Test func cloudStateUpdatesPersistAndEmit() {
        let store = MockStore()
        let defaults = temporaryDefaults()
        let cloud = MockCloudSync()
        let manager = PomodoroSyncManager(
            store: store,
            defaults: defaults,
            cloudSync: cloud
        )
        var received: PomodoroSharedState?
        manager.onStateChange = { received = $0 }

        let state = PomodoroSharedState(
            duration: 600,
            startedAt: Date(),
            isRunning: true,
            updatedAt: Date(),
            originIdentifier: "remote-device"
        )

        cloud.triggerState(state)

        #expect(received == state)
        #expect(manager.currentState() == state)
    }

    @Test func handleRemoteNotificationDelegatesToCloud() async {
        let cloud = MockCloudSync()
        cloud.handleRemoteNotificationResult = true
        let manager = PomodoroSyncManager(
            store: MockStore(),
            defaults: temporaryDefaults(),
            cloudSync: cloud
        )

        let handled = await manager.handleRemoteNotification(["foo": "bar"])
        #expect(handled == true)
        #expect(cloud.handleRemoteNotificationCalls == 1)
    }
}

// MARK: - Test Helpers

private final class MockStore: NSUbiquitousKeyValueStore {
    private var storage: [String: Any] = [:]

    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func data(forKey defaultName: String) -> Data? {
        storage[defaultName] as? Data
    }

    override func synchronize() -> Bool { true }
}

private func temporaryDefaults() -> UserDefaults {
    let suite = "pomafocus.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

private final class MockCloudSync: PomodoroCloudSyncing {
    var onStateChange: ((PomodoroSharedState) -> Void)?
    var onPreferencesChange: ((PomodoroPreferencesSnapshot) -> Void)?
    var onTimerCommand: ((TimerCommand) -> Void)?
    var userRecordName: String? = "_mock_user_record"

    private(set) var startCount = 0
    private(set) var publishedStates: [PomodoroSharedState] = []
    private(set) var publishedPreferences: [PomodoroPreferencesSnapshot] = []
    var handleRemoteNotificationResult = false
    private(set) var handleRemoteNotificationCalls = 0

    func start() {
        startCount += 1
    }

    func publish(state: PomodoroSharedState) {
        publishedStates.append(state)
    }

    func publish(preferences: PomodoroPreferencesSnapshot) {
        publishedPreferences.append(preferences)
    }

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
        handleRemoteNotificationCalls += 1
        return handleRemoteNotificationResult
    }

    func triggerState(_ state: PomodoroSharedState) {
        onStateChange?(state)
    }

    func triggerPreferences(_ snapshot: PomodoroPreferencesSnapshot) {
        onPreferencesChange?(snapshot)
    }
}
