import Foundation
import Testing
@testable import PomafocusKit

@MainActor
@Suite struct PomodoroSessionControllerTests {
    @Test func startPublishesStateAndBlocks() async throws {
        let ticker = MockTicker()
        var now = Date()
        let timer = PomodoroTimer(now: { now }, ticker: ticker)
        let sync = MockSyncManager()
        let blocker = MockBlocker()

        let controller = PomodoroSessionController(timer: timer, syncManager: sync, blocker: blocker)
        #expect(blocker.beginCount == 0)

        controller.toggleTimer()
        #expect(sync.publishedStates.last?.isRunning == true)
        #expect(blocker.beginCount == 1)
        #expect(controller.isRunning == true)

        guard let startDate = controller.currentSessionStart else {
            Issue.record("Missing start date")
            return
        }

        now = startDate.addingTimeInterval(TimeInterval(controller.currentDurationSeconds))
        ticker.fire()
        await Task.yield()
        #expect(sync.publishedStates.last?.isRunning == false)
        #expect(blocker.endCount == 1)
    }

    @Test func remoteStateStartsSession() {
        let ticker = MockTicker()
        let timer = PomodoroTimer(now: Date.init, ticker: ticker)
        let sync = MockSyncManager()
        let blocker = MockBlocker()
        let controller = PomodoroSessionController(timer: timer, syncManager: sync, blocker: blocker)

        let remoteState = PomodoroSharedState(
            duration: 900,
            startedAt: Date(),
            isRunning: true,
            updatedAt: Date(),
            originIdentifier: "remote"
        )

        sync.onStateChange?(remoteState)
        #expect(controller.isRunning == true)
        #expect(controller.minutes == 15)
        #expect(blocker.beginCount == 1)
    }

    @Test func preferencesUpdateAdjustsMinutesWhenIdle() {
        let timer = PomodoroTimer()
        let sync = MockSyncManager()
        let blocker = MockBlocker()
        let controller = PomodoroSessionController(timer: timer, syncManager: sync, blocker: blocker)

        let snapshot = PomodoroPreferencesSnapshot(minutes: 42, deepBreathEnabled: true, updatedAt: Date(), originIdentifier: "remote")
        sync.onPreferencesChange?(snapshot)
        #expect(controller.minutes == 42)
        #expect(controller.remainingDisplay == "42:00")
        #expect(controller.deepBreathEnabled == true)
    }

    @Test func deepBreathRequiresSecondTap() async {
        let timer = PomodoroTimer()
        var deepNow = Date()
        let deepTicker = MockTicker()
        let deepTimer = PomodoroTimer(now: { deepNow }, ticker: deepTicker)
        let sync = MockSyncManager()
        let blocker = MockBlocker()
        let controller = PomodoroSessionController(
            timer: timer,
            deepBreathTimer: deepTimer,
            deepBreathClock: { deepNow },
            syncManager: sync,
            blocker: blocker
        )

        controller.setDeepBreathEnabled(true)
        controller.toggleTimer()
        controller.toggleTimer()

        #expect(controller.isRunning == true)
        #expect(controller.isDeepBreathing == true)

        controller.toggleTimer()
        #expect(controller.isRunning == true)

        deepNow = deepNow.addingTimeInterval(30)
        deepTicker.fire()
        await Task.yield()
        #expect(controller.deepBreathReady == true)

        controller.toggleTimer()
        #expect(controller.isRunning == false)
    }
}

// MARK: - Test Doubles

@MainActor
private final class MockSyncManager: PomodoroSyncManaging {
    var onStateChange: ((PomodoroSharedState) -> Void)?
    var onPreferencesChange: ((PomodoroPreferencesSnapshot) -> Void)?
    let deviceIdentifier = "local"

    private var state = PomodoroSharedState(
        duration: 1500,
        startedAt: nil,
        isRunning: false,
        updatedAt: Date(),
        originIdentifier: "local"
    )
    private var preferences = PomodoroPreferencesSnapshot(
        minutes: 25,
        deepBreathEnabled: false,
        updatedAt: Date(),
        originIdentifier: "local"
    )

    private(set) var publishedStates: [PomodoroSharedState] = []
    private(set) var publishedPreferences: [PomodoroPreferencesSnapshot] = []

    func start() {}

    func currentState() -> PomodoroSharedState {
        state
    }

    func currentPreferences() -> PomodoroPreferencesSnapshot {
        preferences
    }

    func publishState(duration: Int, startedAt: Date?, isRunning: Bool) {
        let newState = PomodoroSharedState(
            duration: duration,
            startedAt: startedAt,
            isRunning: isRunning,
            updatedAt: Date(),
            originIdentifier: deviceIdentifier
        )
        state = newState
        publishedStates.append(newState)
    }

    func publishPreferences(minutes: Int, deepBreathEnabled: Bool) {
        let snapshot = PomodoroPreferencesSnapshot(
            minutes: minutes,
            deepBreathEnabled: deepBreathEnabled,
            updatedAt: Date(),
            originIdentifier: deviceIdentifier
        )
        preferences = snapshot
        publishedPreferences.append(snapshot)
    }
}

@MainActor
private final class MockBlocker: PomodoroBlocking {
    private(set) var beginCount = 0
    private(set) var endCount = 0

    var hasSelection: Bool { true }
    var selectionSummary: String { "Mock" }

    func beginBlocking() {
        beginCount += 1
    }

    func endBlocking() {
        endCount += 1
    }
}

@MainActor
private final class MockTicker: PomodoroTicker {
    var handler: (@MainActor () -> Void)?

    func schedule(interval: TimeInterval, handler: @escaping @MainActor () -> Void) -> PomodoroTickerToken {
        self.handler = handler
        return MockToken {}
    }

    func fire() {
        handler?()
    }

    private struct MockToken: PomodoroTickerToken {
        let cancel: () -> Void
        func invalidate() { cancel() }
    }
}
