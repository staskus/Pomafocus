import Foundation
#if canImport(Combine)
import Combine
#endif

@MainActor
public final class PomodoroSessionController: ObservableObject {
    @Published public private(set) var minutes: Int
    @Published public private(set) var isRunning: Bool
    @Published public private(set) var remaining: TimeInterval
    @Published public private(set) var deepBreathEnabled: Bool
    @Published public private(set) var deepBreathRemaining: TimeInterval?
    @Published public private(set) var deepBreathReady: Bool = false

    public var remainingDisplay: String {
        PomodoroSessionController.format(seconds: Int(remaining))
    }

    public var displayStateText: String {
        isRunning ? "Focus in progress" : "Ready"
    }

    public var deviceIdentifier: String {
        syncManager.deviceIdentifier
    }

    public var canAdjustMinutes: Bool { !isRunning }
    public var isDeepBreathing: Bool {
        deepBreathRemaining != nil || deepBreathReady
    }
    public private(set) var currentSessionStart: Date?
    public var currentDurationSeconds: Int {
        activeDuration == 0 ? minutes * 60 : activeDuration
    }

#if canImport(Combine)
    public enum Event {
        case started
        case stopped
        case completed
    }

    public let events = PassthroughSubject<Event, Never>()
#endif

    private let timer: PomodoroTimer
    private let deepBreathTimer: PomodoroTimer
    private let syncManager: PomodoroSyncManaging
    private let blocker: PomodoroBlocking
    private var activeDuration: Int = 0
    public static let deepBreathDuration: TimeInterval = 30
    private let deepBreathClock: () -> Date

    public init(
        timer: PomodoroTimer? = nil,
        deepBreathTimer: PomodoroTimer? = nil,
        deepBreathClock: @escaping () -> Date = Date.init,
        syncManager: PomodoroSyncManaging? = nil,
        blocker: PomodoroBlocking? = nil
    ) {
        self.timer = timer ?? PomodoroTimer()
        self.deepBreathTimer = deepBreathTimer ?? PomodoroTimer()
        self.syncManager = syncManager ?? PomodoroSyncManager.shared
        self.blocker = blocker ?? PomodoroBlocker.shared
        self.deepBreathClock = deepBreathClock

        self.syncManager.start()
        let initialPreferences = self.syncManager.currentPreferences()
        self.minutes = initialPreferences.minutes
        self.deepBreathEnabled = initialPreferences.deepBreathEnabled
        self.remaining = TimeInterval(initialPreferences.minutes * 60)
        let state = self.syncManager.currentState()
        self.isRunning = state.isRunning

        bindTimer()
        configureDeepBreathTimer()
        configureSync()

        if state.isRunning, let startDate = state.startedAt {
            startSession(durationSeconds: state.duration, startDate: startDate, shouldSync: false)
        } else {
            updateDisplay()
        }
    }

    public func toggleTimer() {
        if isRunning {
            handleStopRequest()
        } else {
            resetDeepBreath()
            startSession(durationSeconds: minutes * 60, startDate: Date(), shouldSync: true)
        }
    }

    public func setMinutes(_ newValue: Int) {
        minutes = max(1, newValue)
        if !isRunning {
            remaining = TimeInterval(minutes * 60)
        }
        syncManager.publishPreferences(minutes: minutes, deepBreathEnabled: deepBreathEnabled)
    }

    public func setDeepBreathEnabled(_ enabled: Bool) {
        deepBreathEnabled = enabled
        if !enabled {
            resetDeepBreath()
        }
        syncManager.publishPreferences(minutes: minutes, deepBreathEnabled: enabled)
    }

    public func applyExternalState(_ state: PomodoroSharedState) {
        guard state.originIdentifier != syncManager.deviceIdentifier else { return }
        guard state.isRunning, let started = state.startedAt else {
            stopSession(shouldSync: false)
            return
        }
        minutes = max(1, state.duration / 60)
        startSession(durationSeconds: state.duration, startDate: started, shouldSync: false)
    }

    public func applyExternalPreferences(_ snapshot: PomodoroPreferencesSnapshot) {
        guard snapshot.originIdentifier != syncManager.deviceIdentifier else { return }
        minutes = snapshot.minutes
        if deepBreathEnabled && !snapshot.deepBreathEnabled {
            resetDeepBreath()
        }
        deepBreathEnabled = snapshot.deepBreathEnabled
        if !isRunning {
            remaining = TimeInterval(minutes * 60)
        }
    }

    private func bindTimer() {
        timer.onTick = { [weak self] remaining in
            guard let self else { return }
            self.remaining = remaining
        }

        timer.onStateChange = { [weak self] running in
            guard let self else { return }
            self.isRunning = running
            #if canImport(Combine)
            self.events.send(running ? .started : .stopped)
            #endif
        }

        timer.onCompletion = { [weak self] in
            guard let self else { return }
            #if canImport(Combine)
            self.events.send(.completed)
            #endif
            self.stopSession(shouldSync: true)
        }
    }

    private func configureDeepBreathTimer() {
        deepBreathTimer.onTick = { [weak self] remaining in
            self?.deepBreathRemaining = remaining
        }
        deepBreathTimer.onCompletion = { [weak self] in
            guard let self else { return }
            self.deepBreathRemaining = 0
            self.deepBreathReady = true
        }
        deepBreathTimer.onStateChange = { [weak self] running in
            guard let self else { return }
            if !running && !self.deepBreathReady {
                self.deepBreathRemaining = nil
            }
        }
    }

    private func configureSync() {
        syncManager.onPreferencesChange = { [weak self] snapshot in
            self?.applyExternalPreferences(snapshot)
        }

        syncManager.onStateChange = { [weak self] state in
            self?.applyExternalState(state)
        }
    }

    private func startSession(durationSeconds: Int, startDate: Date, shouldSync: Bool) {
        resetDeepBreath()
        activeDuration = durationSeconds
        currentSessionStart = startDate
        timer.start(duration: TimeInterval(durationSeconds), startDate: startDate)
        remaining = TimeInterval(durationSeconds)
        isRunning = true
        blocker.beginBlocking()
        if shouldSync {
            syncManager.publishState(duration: durationSeconds, startedAt: startDate, isRunning: true)
        }
    }

    private func stopSession(shouldSync: Bool) {
        resetDeepBreath()
        timer.stop()
        blocker.endBlocking()
        isRunning = false
        currentSessionStart = nil
        let duration = activeDuration == 0 ? minutes * 60 : activeDuration
        if shouldSync {
            syncManager.publishState(duration: duration, startedAt: nil, isRunning: false)
        }
        activeDuration = 0
        remaining = TimeInterval(minutes * 60)
    }

    private func handleStopRequest() {
        guard isRunning else { return }
        if deepBreathEnabled {
            if deepBreathReady {
                resetDeepBreath()
                stopSession(shouldSync: true)
            } else if deepBreathRemaining == nil {
                beginDeepBreathCountdown()
            }
        } else {
            stopSession(shouldSync: true)
        }
    }

    private func beginDeepBreathCountdown() {
        deepBreathReady = false
        deepBreathRemaining = PomodoroSessionController.deepBreathDuration
        deepBreathTimer.start(duration: PomodoroSessionController.deepBreathDuration, startDate: deepBreathClock())
    }

    private func resetDeepBreath() {
        deepBreathTimer.stop()
        deepBreathRemaining = nil
        deepBreathReady = false
    }

    private func updateDisplay() {
        remaining = TimeInterval(minutes * 60)
    }

    public static func format(seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let seconds = max(0, seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
