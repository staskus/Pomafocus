import AppKit

@MainActor
final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let timer = PomodoroTimer()
    private let settings = PomodoroSettings()
    private let hotkeyManager = HotkeyManager()
    private lazy var preferencesWindowController = PreferencesWindowController(settings: settings) { [weak self] snapshot in
        self?.apply(snapshot: snapshot, persist: true)
    }
    private var currentSnapshot: PomodoroSettings.Snapshot

    private lazy var toggleItem: NSMenuItem = {
        let item = NSMenuItem(title: "Start Pomodoro", action: #selector(toggleTimer), keyEquivalent: "")
        item.target = self
        return item
    }()

    init() {
        currentSnapshot = settings.snapshot()
        configureStatusItem()
        bindTimerCallbacks()
        apply(snapshot: currentSnapshot)
    }

    func showPreferences() {
        preferencesWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleTimer() {
        if timer.isRunning {
            timer.stop()
        } else {
            timer.start(duration: TimeInterval(currentSnapshot.minutes * 60))
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
            if !isRunning {
                updateStatusTitle()
            }
        }

        timer.onCompletion = { [weak self] in
            self?.updateStatusTitle()
        }
    }

    private func apply(snapshot: PomodoroSettings.Snapshot, persist: Bool = false) {
        if persist {
            settings.save(snapshot)
        }
        currentSnapshot = snapshot
        registerHotkey()
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
            button.title = formattedTime(from: secondsLeft)
        } else {
            button.title = "Pomafocus"
        }
    }

    private func formattedTime(from seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
