import AppKit
#if canImport(PomafocusKit)
import PomafocusKit
#endif

@MainActor
final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let timer = PomodoroTimer()
    private let deepBreathTimer = PomodoroTimer()
    private let deepBreathConfirmTimer = PomodoroTimer()
    private let settings = PomodoroSettings()
    private let hotkeyManager = HotkeyManager()
    private let syncManager = PomodoroSyncManager.shared
    private let blocker = PomodoroBlocker.shared
    private lazy var preferencesWindowController = PreferencesWindowController(settings: settings) { [weak self] snapshot in
        self?.apply(snapshot: snapshot, persist: true)
    }
    private var currentSnapshot: PomodoroSettings.Snapshot
    private var currentSessionStart: Date?
    private var activeDuration: Int = 0
    private var deepBreathRemaining: TimeInterval?
    private var deepBreathReady = false
    private var deepBreathConfirmationRemaining: TimeInterval?

    private lazy var toggleItem: NSMenuItem = {
        let item = NSMenuItem(title: "Start Pomodoro", action: #selector(toggleTimer), keyEquivalent: "")
        item.target = self
        return item
    }()

    init() {
        currentSnapshot = settings.snapshot()
        configureStatusItem()
        bindTimerCallbacks()
        configureDeepBreathTimer()
        apply(snapshot: currentSnapshot)
        configureSync()
    }

    func showPreferences() {
        preferencesWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleTimer() {
        if timer.isRunning {
            if currentSnapshot.deepBreathEnabled {
                handleDeepBreathToggle()
            } else {
                stopSession(shouldSync: true)
            }
        } else {
            let duration = currentSnapshot.minutes * 60
            resetDeepBreath()
            startSession(durationSeconds: duration, startDate: Date(), shouldSync: true)
        }
    }

    @objc private func openPreferences() {
        showPreferences()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        menu.autoenablesItems = false
        menu.addItem(toggleItem)
        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        preferencesItem.keyEquivalentModifierMask = [.command]
        menu.addItem(preferencesItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Pomafocus", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateStatusTitle()
    }

    private func bindTimerCallbacks() {
        timer.onTick = { [weak self] remaining in
            self?.updateStatusTitle(remaining: remaining)
        }

        timer.onStateChange = { [weak self] isRunning in
            guard let self else { return }
            toggleItem.title = isRunning ? "Stop Pomodoro" : "Start Pomodoro"
            if isRunning {
                self.playStartSound()
            }
            if !isRunning {
                updateStatusTitle()
            }
        }

        timer.onCompletion = { [weak self] in
            self?.playCompletionSound()
            self?.stopSession(shouldSync: true)
            self?.updateStatusTitle()
        }
    }

    private func apply(snapshot: PomodoroSettings.Snapshot, persist: Bool = false) {
        if persist {
            settings.save(snapshot)
        }
        currentSnapshot = snapshot
        if !snapshot.deepBreathEnabled {
            resetDeepBreath()
        }
        registerHotkey()
    }

    private func configureSync() {
        syncManager.onStateChange = { [weak self] state in
            self?.handleSharedState(state, ignoreIfLocalOrigin: true)
        }
        syncManager.onPreferencesChange = { [weak self] snapshot in
            self?.handleSharedPreferences(snapshot, ignoreIfLocalOrigin: true)
        }
        syncManager.start()
        handleSharedPreferences(syncManager.currentPreferences(), ignoreIfLocalOrigin: false)
        handleSharedState(syncManager.currentState(), ignoreIfLocalOrigin: false)
    }

    private func handleSharedState(_ state: PomodoroSharedState, ignoreIfLocalOrigin: Bool) {
        if ignoreIfLocalOrigin && state.originIdentifier == syncManager.deviceIdentifier {
            return
        }

        guard state.isRunning, let start = state.startedAt else {
            stopSession(shouldSync: false)
            return
        }

        let minutes = max(1, state.duration / 60)
        if minutes != currentSnapshot.minutes {
            var updatedSnapshot = currentSnapshot
            updatedSnapshot.minutes = minutes
            settings.updatePreferencesFromSync(minutes: minutes, deepBreathEnabled: currentSnapshot.deepBreathEnabled)
            currentSnapshot = updatedSnapshot
            preferencesWindowController.applyExternalSnapshot(updatedSnapshot)
        }
        startSession(durationSeconds: state.duration, startDate: start, shouldSync: false)
    }

    private func handleSharedPreferences(_ preferences: PomodoroPreferencesSnapshot, ignoreIfLocalOrigin: Bool) {
        if ignoreIfLocalOrigin && preferences.originIdentifier == syncManager.deviceIdentifier {
            return
        }
        var snapshot = currentSnapshot
        snapshot.minutes = preferences.minutes
        snapshot.deepBreathEnabled = preferences.deepBreathEnabled
        settings.updatePreferencesFromSync(minutes: preferences.minutes, deepBreathEnabled: preferences.deepBreathEnabled)
        apply(snapshot: snapshot, persist: false)
        preferencesWindowController.applyExternalSnapshot(snapshot)
        updateStatusTitle()
    }

    private func startSession(durationSeconds: Int, startDate: Date, shouldSync: Bool) {
        resetDeepBreath()
        activeDuration = durationSeconds
        currentSessionStart = startDate
        timer.start(duration: TimeInterval(durationSeconds), startDate: startDate)
        blocker.beginBlocking()
        if shouldSync {
            syncManager.publishState(duration: durationSeconds, startedAt: startDate, isRunning: true)
        }
    }

    private func stopSession(shouldSync: Bool) {
        resetDeepBreath()
        timer.stop()
        blocker.endBlocking()
        currentSessionStart = nil
        if shouldSync {
            let duration = activeDuration == 0 ? currentSnapshot.minutes * 60 : activeDuration
            syncManager.publishState(duration: duration, startedAt: nil, isRunning: false)
        }
        activeDuration = 0
    }

    private func registerHotkey() {
        hotkeyManager.register(hotkey: currentSnapshot.hotkey) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleTimer()
            }
        }
    }

    private func updateStatusTitle(remaining: TimeInterval? = nil) {
        guard let button = statusItem.button else { return }
        if timer.isRunning {
            let secondsLeft = Int(remaining ?? timer.remaining)
            var title = formattedTime(from: secondsLeft)
            if currentSnapshot.deepBreathEnabled {
                if let breath = deepBreathRemaining {
                    title += " (breathe \(formattedTime(from: Int(ceil(breath)))))"
                } else if deepBreathReady, let confirm = deepBreathConfirmationRemaining {
                    title += " (confirm \(formattedTime(from: Int(ceil(confirm)))))"
                }
            }
            button.title = title
        } else {
            if currentSnapshot.deepBreathEnabled {
                if let breath = deepBreathRemaining {
                    button.title = "Breathe \(formattedTime(from: Int(ceil(breath))))"
                    return
                } else if deepBreathReady, let confirm = deepBreathConfirmationRemaining {
                    button.title = "Confirm \(formattedTime(from: Int(ceil(confirm))))"
                    return
                }
            }
            button.title = "Pomafocus"
        }
    }

    private func formattedTime(from seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func playStartSound() {
        NSSound(named: NSSound.Name("Pop"))?.play()
    }

    private func playCompletionSound() {
        NSSound(named: NSSound.Name("Glass"))?.play()
    }

    private func configureDeepBreathTimer() {
        deepBreathTimer.onTick = { [weak self] remaining in
            self?.deepBreathRemaining = remaining
            self?.updateStatusTitle()
        }
        deepBreathTimer.onCompletion = { [weak self] in
            guard let self else { return }
            self.deepBreathRemaining = nil
            self.beginDeepBreathConfirmation()
        }
        deepBreathTimer.onStateChange = { [weak self] running in
            guard let self else { return }
            if !running && !self.deepBreathReady {
                self.deepBreathRemaining = nil
            }
            self.updateStatusTitle()
        }

        deepBreathConfirmTimer.onTick = { [weak self] remaining in
            self?.deepBreathConfirmationRemaining = remaining
            self?.updateStatusTitle()
        }
        deepBreathConfirmTimer.onCompletion = { [weak self] in
            guard let self else { return }
            self.deepBreathReady = false
            self.deepBreathConfirmationRemaining = nil
            self.updateStatusTitle()
        }
        deepBreathConfirmTimer.onStateChange = { [weak self] running in
            guard let self else { return }
            if !running {
                self.deepBreathConfirmationRemaining = nil
            }
            self.updateStatusTitle()
        }
    }

    private func handleDeepBreathToggle() {
        if deepBreathReady {
            stopSession(shouldSync: true)
        } else if deepBreathRemaining == nil {
            beginDeepBreathCountdown()
        }
    }

    private func beginDeepBreathCountdown() {
        deepBreathConfirmTimer.stop()
        deepBreathReady = false
        deepBreathConfirmationRemaining = nil
        deepBreathRemaining = PomodoroSessionController.deepBreathDuration
        deepBreathTimer.start(duration: PomodoroSessionController.deepBreathDuration)
        updateStatusTitle()
    }

    private func beginDeepBreathConfirmation() {
        deepBreathReady = true
        deepBreathConfirmationRemaining = PomodoroSessionController.deepBreathConfirmationWindow
        deepBreathConfirmTimer.start(duration: PomodoroSessionController.deepBreathConfirmationWindow)
        updateStatusTitle()
    }

    private func resetDeepBreath() {
        deepBreathTimer.stop()
        deepBreathConfirmTimer.stop()
        deepBreathRemaining = nil
        deepBreathReady = false
        deepBreathConfirmationRemaining = nil
        updateStatusTitle()
    }

}
