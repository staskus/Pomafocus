import Foundation
import Testing
@testable import PomafocusKit

@MainActor
@Suite struct PomodoroSyncManagerTests {
    @Test func publishesPreferencesAndStoresFallback() throws {
        let store = MockStore()
        let defaults = temporaryDefaults()
        let manager = PomodoroSyncManager(
            store: store,
            defaults: defaults,
            notificationCenter: NotificationCenter()
        )

        var received: PomodoroPreferencesSnapshot?
        manager.onPreferencesChange = { received = $0 }
        manager.publishPreferences(minutes: 35)

        #expect(received?.minutes == 35)
        #expect(defaults.integer(forKey: "pomodoro.minutes") == 35)

        let data = store.data(forKey: "pomafocus.shared.preferences")
        #expect(data != nil)
        if let data {
            let decoded = try JSONDecoder().decode(PomodoroPreferencesSnapshot.self, from: data)
            #expect(decoded.minutes == 35)
        }
    }

    @Test func currentPreferencesFallsBackToStoredMinutes() {
        let defaults = temporaryDefaults()
        defaults.set(42, forKey: "pomodoro.minutes")
        let manager = PomodoroSyncManager(
            store: MockStore(),
            defaults: defaults,
            notificationCenter: NotificationCenter()
        )

        let snapshot = manager.currentPreferences()
        #expect(snapshot.minutes == 42)
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
