import Foundation
#if canImport(Combine)
import Combine
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
public final class PomodoroSessionController: ObservableObject {
    public enum SessionOrigin: Equatable {
        case manual
        case schedule(UUID)
    }

    @Published public private(set) var minutes: Int
    @Published public private(set) var isRunning: Bool
    @Published public private(set) var remaining: TimeInterval
    @Published public private(set) var deepBreathEnabled: Bool
    @Published public private(set) var deepBreathRemaining: TimeInterval?
    @Published public private(set) var deepBreathReady: Bool = false
    @Published public private(set) var deepBreathConfirmationRemaining: TimeInterval?
    @Published public private(set) var sessionTag: String?
    @Published public private(set) var sessionOrigin: SessionOrigin = .manual

    public var remainingDisplay: String {
        PomodoroSessionController.format(seconds: Int(ceil(remaining)))
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
    public var onExternalStart: ((PomodoroSharedState) -> Void)?

    private let timer: PomodoroTimer
    private let deepBreathTimer: PomodoroTimer
    private let deepBreathConfirmTimer: PomodoroTimer
    private let syncManager: PomodoroSyncManaging
    private let blocker: PomodoroBlocking
    private let widgetStateManager: WidgetStateManager
    private let statsStore: StatsStore
    private var activeDuration: Int = 0
    private var manualMinutes: Int
    private var restoreMinutesAfterStop: Int?
    private var restoreTagAfterStop: String?
    public static let deepBreathDuration: TimeInterval = 30
    public static let deepBreathConfirmationWindow: TimeInterval = 60
    private let deepBreathClock: () -> Date

    public init(
        timer: PomodoroTimer? = nil,
        deepBreathTimer: PomodoroTimer? = nil,
        deepBreathConfirmTimer: PomodoroTimer? = nil,
        deepBreathClock: @escaping () -> Date = Date.init,
        syncManager: PomodoroSyncManaging? = nil,
        blocker: PomodoroBlocking? = nil,
        widgetStateManager: WidgetStateManager? = nil,
        statsStore: StatsStore? = nil
    ) {
        self.timer = timer ?? PomodoroTimer()
        self.deepBreathTimer = deepBreathTimer ?? PomodoroTimer()
        self.deepBreathConfirmTimer = deepBreathConfirmTimer ?? PomodoroTimer()
        self.syncManager = syncManager ?? PomodoroSyncManager.shared
        self.blocker = blocker ?? PomodoroBlocker.shared
        self.widgetStateManager = widgetStateManager ?? WidgetStateManager.shared
        self.statsStore = statsStore ?? StatsStore.shared
        self.deepBreathClock = deepBreathClock

        self.syncManager.start()
        let initialPreferences = self.syncManager.currentPreferences()
        self.minutes = initialPreferences.minutes
        self.manualMinutes = initialPreferences.minutes
        self.deepBreathEnabled = initialPreferences.deepBreathEnabled
        self.remaining = TimeInterval(initialPreferences.minutes * 60)
        let state = self.syncManager.currentState()
        self.isRunning = state.isRunning

        bindTimer()
        configureDeepBreathTimers()
        configureSync()

        if state.isRunning, let startDate = state.startedAt {
            startSession(durationSeconds: state.duration, startDate: startDate, shouldSync: false)
        } else {
            updateDisplay()
        }

        publishWidgetState()
    }

    public func toggleTimer() {
        if isRunning {
            handleStopRequest()
        } else {
            resetDeepBreath()
            sessionOrigin = .manual
            restoreMinutesAfterStop = nil
            restoreTagAfterStop = nil
            startSession(durationSeconds: minutes * 60, startDate: Date(), shouldSync: true)
        }
    }

    public func setMinutes(_ newValue: Int) {
        manualMinutes = max(1, newValue)
        minutes = manualMinutes
        if !isRunning {
            remaining = TimeInterval(minutes * 60)
        }
        syncManager.publishPreferences(minutes: minutes, deepBreathEnabled: deepBreathEnabled)
    }

    public func setSessionTag(_ tag: String?) {
        guard !isRunning else { return }
        sessionTag = tag
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
            stopSession(shouldSync: false, outcome: nil)
            return
        }
        if !isRunning || currentSessionStart != started {
            onExternalStart?(state)
        }
        minutes = max(1, state.duration / 60)
        sessionOrigin = .manual
        startSession(durationSeconds: state.duration, startDate: started, shouldSync: false)
    }

    public func applyExternalPreferences(_ snapshot: PomodoroPreferencesSnapshot) {
        guard snapshot.originIdentifier != syncManager.deviceIdentifier else { return }
        manualMinutes = snapshot.minutes
        if restoreMinutesAfterStop == nil {
            minutes = snapshot.minutes
        }
        if deepBreathEnabled && !snapshot.deepBreathEnabled {
            resetDeepBreath()
        }
        deepBreathEnabled = snapshot.deepBreathEnabled
        if !isRunning && restoreMinutesAfterStop == nil {
            remaining = TimeInterval(minutes * 60)
        }
    }

    public func startScheduledSession(durationMinutes: Int, tag: String?, blockID: UUID) {
        guard !isRunning else { return }
        let clampedMinutes = max(1, durationMinutes)
        restoreMinutesAfterStop = manualMinutes
        restoreTagAfterStop = sessionTag
        minutes = clampedMinutes
        remaining = TimeInterval(clampedMinutes * 60)
        sessionOrigin = .schedule(blockID)
        sessionTag = tag
        resetDeepBreath()
        startSession(durationSeconds: clampedMinutes * 60, startDate: Date(), shouldSync: true)
    }

    public func stopScheduledSessionIfNeeded() {
        guard case .schedule = sessionOrigin else { return }
        stopSession(shouldSync: true, outcome: .stopped)
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
            self.stopSession(shouldSync: true, outcome: .completed)
        }
    }

    private func configureDeepBreathTimers() {
        deepBreathTimer.onTick = { [weak self] remaining in
            self?.deepBreathRemaining = remaining
            self?.publishWidgetState()
        }
        deepBreathTimer.onCompletion = { [weak self] in
            guard let self else { return }
            self.deepBreathRemaining = nil
            self.beginDeepBreathConfirmation()
            self.publishWidgetState()
        }
        deepBreathTimer.onStateChange = { [weak self] running in
            guard let self else { return }
            if !running && !self.deepBreathReady {
                self.deepBreathRemaining = nil
                self.publishWidgetState()
            }
        }

        deepBreathConfirmTimer.onTick = { [weak self] remaining in
            self?.deepBreathConfirmationRemaining = remaining
            self?.publishWidgetState()
        }
        deepBreathConfirmTimer.onCompletion = { [weak self] in
            guard let self else { return }
            self.deepBreathReady = false
            self.deepBreathConfirmationRemaining = nil
            self.statsStore.recordDeepBreathEvent(.timedOut)
            self.publishWidgetState()
        }
        deepBreathConfirmTimer.onStateChange = { [weak self] running in
            guard let self else { return }
            if !running {
                self.deepBreathConfirmationRemaining = nil
                self.publishWidgetState()
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
        publishWidgetState()
    }

    private func stopSession(shouldSync: Bool, outcome: FocusSessionOutcome?) {
        if let outcome, let start = currentSessionStart {
            let end = Date()
            let elapsed = max(0, Int(end.timeIntervalSince(start)))
            let duration: Int
            switch outcome {
            case .completed:
                duration = activeDuration > 0 ? activeDuration : elapsed
            case .stopped:
                duration = elapsed
            }
            statsStore.recordSession(
                startedAt: start,
                endedAt: end,
                durationSeconds: duration,
                outcome: outcome,
                tag: sessionTag
            )
        }
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
        if let restoredMinutes = restoreMinutesAfterStop {
            minutes = restoredMinutes
            restoreMinutesAfterStop = nil
        }
        if let restoredTag = restoreTagAfterStop {
            sessionTag = restoredTag
            restoreTagAfterStop = nil
        }
        remaining = TimeInterval(minutes * 60)
        sessionOrigin = .manual
        publishWidgetState()
    }

    private func handleStopRequest() {
        guard isRunning else { return }
        if deepBreathEnabled {
            if deepBreathReady {
                statsStore.recordDeepBreathEvent(.confirmed)
                resetDeepBreath()
                stopSession(shouldSync: true, outcome: .stopped)
            } else if deepBreathRemaining == nil {
                beginDeepBreathCountdown()
            }
        } else {
            stopSession(shouldSync: true, outcome: .stopped)
        }
    }

    private func beginDeepBreathCountdown() {
        deepBreathConfirmTimer.stop()
        deepBreathReady = false
        deepBreathRemaining = PomodoroSessionController.deepBreathDuration
        statsStore.recordDeepBreathEvent(.started)
        deepBreathTimer.start(duration: PomodoroSessionController.deepBreathDuration, startDate: deepBreathClock())
    }

    private func beginDeepBreathConfirmation() {
        deepBreathReady = true
        deepBreathConfirmationRemaining = PomodoroSessionController.deepBreathConfirmationWindow
        deepBreathConfirmTimer.start(
            duration: PomodoroSessionController.deepBreathConfirmationWindow,
            startDate: deepBreathClock()
        )
    }

    private func resetDeepBreath() {
        deepBreathTimer.stop()
        deepBreathConfirmTimer.stop()
        deepBreathRemaining = nil
        deepBreathReady = false
        deepBreathConfirmationRemaining = nil
    }

    private func updateDisplay() {
        remaining = TimeInterval(minutes * 60)
    }

    public static func format(seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let seconds = max(0, seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Widget Integration

    public func checkWidgetCommands() {
        guard let command = widgetStateManager.consumeCommand() else { return }
        switch command {
        case .start:
            if !isRunning {
                resetDeepBreath()
                startSession(durationSeconds: minutes * 60, startDate: Date(), shouldSync: true)
            }
        case .stop:
            handleStopRequest()
        }
    }

    private func publishWidgetState() {
        let endsAt: Date? = isRunning ? currentSessionStart?.addingTimeInterval(TimeInterval(currentDurationSeconds)) : nil
        let state = WidgetTimerState(
            isRunning: isRunning,
            remainingSeconds: Int(remaining),
            durationSeconds: currentDurationSeconds,
            startedAt: currentSessionStart,
            endsAt: endsAt,
            minutes: minutes,
            deepBreathEnabled: deepBreathEnabled,
            deepBreathRemainingSeconds: deepBreathRemaining.map { max(0, Int($0)) },
            deepBreathReady: deepBreathReady,
            deepBreathConfirmationRemainingSeconds: deepBreathConfirmationRemaining.map { max(0, Int($0)) }
        )
        widgetStateManager.saveState(state)
        reloadWidgets()
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit) && os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
