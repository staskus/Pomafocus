import AppKit
import PomafocusKit

final class PreferencesWindowController: NSWindowController {
    private let settings: PomodoroSettings
    private let onUpdate: (PomodoroSettings.Snapshot) -> Void
    private let minutesField = NSTextField(string: "")
    private lazy var hotkeyField: HotkeyField = HotkeyField(hotkey: currentSnapshot.hotkey)
    private let deepBreathCheckbox = NSButton(checkboxWithTitle: "Require a 30-second deep breath before stopping", target: nil, action: nil)
    private let screenTimeCheckbox = NSButton(checkboxWithTitle: "Use Screen Time companion app for blocking", target: nil, action: nil)
    private let screenTimeStatusLabel = NSTextField(labelWithString: "")
    private let openScreenTimeButton = NSButton(title: "Open Screen Time Selection", target: nil, action: nil)
    private let blocker = PomodoroBlocker.shared
    private var currentSnapshot: PomodoroSettings.Snapshot

    init(settings: PomodoroSettings, onUpdate: @escaping (PomodoroSettings.Snapshot) -> Void) {
        self.settings = settings
        self.onUpdate = onUpdate
        self.currentSnapshot = settings.snapshot()
        super.init(window: nil)
        setupWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        currentSnapshot = settings.snapshot()
        applySnapshotToFields()
        super.showWindow(sender)
    }

    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        self.window = window

        configureFields()
        buildLayout(in: window)
        applySnapshotToFields()
    }

    private func configureFields() {
        minutesField.translatesAutoresizingMaskIntoConstraints = false
        minutesField.alignment = .left
        minutesField.placeholderString = "Minutes"
        minutesField.focusRingType = .none
        minutesField.formatter = {
            let formatter = NumberFormatter()
            formatter.minimum = 1
            formatter.maximum = 180
            formatter.allowsFloats = false
            return formatter
        }()

        hotkeyField.onChange = { [weak self] hotkey in
            self?.currentSnapshot.hotkey = hotkey
        }
        deepBreathCheckbox.target = self
        deepBreathCheckbox.action = #selector(toggleDeepBreath(_:))
        screenTimeCheckbox.target = self
        screenTimeCheckbox.action = #selector(toggleScreenTimeCompanion(_:))
        openScreenTimeButton.target = self
        openScreenTimeButton.action = #selector(openScreenTimeSelection)
        openScreenTimeButton.bezelStyle = .rounded
        screenTimeStatusLabel.textColor = .secondaryLabelColor
    }

    private func buildLayout(in window: NSWindow) {
        guard let contentView = window.contentView else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let minutesLabel = NSTextField(labelWithString: "Session length (minutes)")
        let hotkeyLabel = NSTextField(labelWithString: "Global shortcut")
        let saveButton = NSButton(title: "Save", target: self, action: #selector(savePreferences))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        stack.addArrangedSubview(minutesLabel)
        stack.addArrangedSubview(minutesField)
        stack.addArrangedSubview(hotkeyLabel)
        stack.addArrangedSubview(hotkeyField)
        stack.addArrangedSubview(deepBreathCheckbox)
        stack.addArrangedSubview(screenTimeCheckbox)
        stack.addArrangedSubview(screenTimeStatusLabel)
        stack.addArrangedSubview(openScreenTimeButton)
        stack.addArrangedSubview(NSView())
        stack.addArrangedSubview(saveButton)

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func applySnapshotToFields() {
        minutesField.stringValue = "\(currentSnapshot.minutes)"
        hotkeyField.hotkey = currentSnapshot.hotkey
        deepBreathCheckbox.state = currentSnapshot.deepBreathEnabled ? .on : .off
        screenTimeCheckbox.state = blocker.screenTimeCompanionEnabled ? .on : .off
        updateScreenTimeStatus(enabled: blocker.screenTimeCompanionEnabled)
    }

    func applyExternalSnapshot(_ snapshot: PomodoroSettings.Snapshot) {
        currentSnapshot = snapshot
        if window?.isVisible == true {
            applySnapshotToFields()
        }
    }

    @objc private func savePreferences() {
        let minutesValue = Int(minutesField.stringValue) ?? currentSnapshot.minutes
        currentSnapshot.minutes = max(1, minutesValue)
        blocker.setScreenTimeCompanionEnabled(screenTimeCheckbox.state == .on)
        onUpdate(currentSnapshot)
        window?.close()
    }

    @objc private func toggleDeepBreath(_ sender: NSButton) {
        currentSnapshot.deepBreathEnabled = sender.state == .on
    }

    @objc private func toggleScreenTimeCompanion(_ sender: NSButton) {
        updateScreenTimeStatus(enabled: sender.state == .on)
    }

    @objc private func openScreenTimeSelection() {
        guard blocker.openScreenTimeSettings() else {
            let alert = NSAlert()
            alert.messageText = "Unable to open companion app"
            alert.informativeText = "Install or launch the iOS/Catalyst Pomafocus app on this Mac, then try again."
            alert.runModal()
            return
        }
    }

    private func updateScreenTimeStatus(enabled: Bool) {
        openScreenTimeButton.isEnabled = enabled
        if enabled {
            screenTimeStatusLabel.stringValue = blocker.isCompanionInstalled
                ? "When focus starts, Pomafocus asks the companion app to enforce Screen Time blocking."
                : "Companion app not found. Install/open the iOS/Catalyst Pomafocus app on this Mac."
        } else {
            screenTimeStatusLabel.stringValue = "Companion integration is disabled."
        }
    }
}
