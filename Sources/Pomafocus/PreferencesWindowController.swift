import AppKit
import PomafocusKit

final class PreferencesWindowController: NSWindowController {
    private let settings: PomodoroSettings
    private let onUpdate: (PomodoroSettings.Snapshot) -> Void
    private let minutesField = NSTextField(string: "")
    private lazy var hotkeyField: HotkeyField = HotkeyField(hotkey: currentSnapshot.hotkey)
    private let deepBreathCheckbox = NSButton(checkboxWithTitle: "Require a 30-second deep breath before stopping", target: nil, action: nil)
    private let setupButton = NSButton(title: "Setup Blocking", target: nil, action: nil)
    private let daemonStatusLabel = NSTextField(labelWithString: "")
    private let domainField = NSTextField(string: "")
    private let addDomainButton = NSButton(title: "Add", target: nil, action: nil)
    private let domainScrollView = NSScrollView()
    private let domainStackView = NSStackView()
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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
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

        setupButton.target = self
        setupButton.action = #selector(setupDaemon)
        setupButton.bezelStyle = .rounded

        daemonStatusLabel.textColor = .secondaryLabelColor
        daemonStatusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        domainField.placeholderString = "example.com"
        domainField.focusRingType = .none
        domainField.target = self
        domainField.action = #selector(addDomain)
        addDomainButton.target = self
        addDomainButton.action = #selector(addDomain)
        addDomainButton.bezelStyle = .rounded

        domainStackView.orientation = .vertical
        domainStackView.spacing = 2
        domainStackView.translatesAutoresizingMaskIntoConstraints = false

        let clipView = NSClipView()
        clipView.documentView = domainStackView
        domainScrollView.contentView = clipView
        domainScrollView.hasVerticalScroller = true
        domainScrollView.borderType = .bezelBorder
        domainScrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            domainStackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            domainStackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            domainStackView.topAnchor.constraint(equalTo: clipView.topAnchor)
        ])
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

        let blockingLabel = NSTextField(labelWithString: "Website Blocking")
        blockingLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        let setupRow = NSStackView(views: [setupButton, daemonStatusLabel])
        setupRow.orientation = .horizontal
        setupRow.spacing = 8

        let domainRow = NSStackView(views: [domainField, addDomainButton])
        domainRow.orientation = .horizontal
        domainRow.spacing = 8

        let saveButton = NSButton(title: "Save", target: self, action: #selector(savePreferences))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        stack.addArrangedSubview(minutesLabel)
        stack.addArrangedSubview(minutesField)
        stack.addArrangedSubview(hotkeyLabel)
        stack.addArrangedSubview(hotkeyField)
        stack.addArrangedSubview(deepBreathCheckbox)
        stack.addArrangedSubview(blockingLabel)
        stack.addArrangedSubview(setupRow)
        stack.addArrangedSubview(domainRow)
        stack.addArrangedSubview(domainScrollView)
        stack.addArrangedSubview(saveButton)

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            domainScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
    }

    private func applySnapshotToFields() {
        minutesField.stringValue = "\(currentSnapshot.minutes)"
        hotkeyField.hotkey = currentSnapshot.hotkey
        deepBreathCheckbox.state = currentSnapshot.deepBreathEnabled ? .on : .off
        updateDaemonStatus()
        rebuildDomainList()
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
        onUpdate(currentSnapshot)
        window?.close()
    }

    @objc private func toggleDeepBreath(_ sender: NSButton) {
        currentSnapshot.deepBreathEnabled = sender.state == .on
    }

    @objc private func setupDaemon() {
        if blocker.isDaemonInstalled {
            let alert = NSAlert()
            alert.messageText = "Remove blocking helper?"
            alert.informativeText = "This will remove the background helper that applies website blocking."
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            _ = blocker.uninstallDaemon()
        } else {
            _ = blocker.installDaemon()
        }
        updateDaemonStatus()
    }

    @objc private func addDomain() {
        let domain = domainField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !domain.isEmpty else { return }
        blocker.addDomain(domain)
        domainField.stringValue = ""
        rebuildDomainList()
    }

    @objc private func removeDomainClicked(_ sender: NSButton) {
        guard let domain = sender.cell?.representedObject as? String else { return }
        blocker.removeDomain(domain)
        rebuildDomainList()
    }

    private func updateDaemonStatus() {
        if blocker.isDaemonInstalled {
            setupButton.title = "Remove Helper"
            daemonStatusLabel.stringValue = "Installed - blocks without password"
            daemonStatusLabel.textColor = .systemGreen
            domainField.isEnabled = true
            addDomainButton.isEnabled = true
        } else {
            setupButton.title = "Setup Blocking"
            daemonStatusLabel.stringValue = "One-time admin password to install"
            daemonStatusLabel.textColor = .secondaryLabelColor
            domainField.isEnabled = false
            addDomainButton.isEnabled = false
        }
    }

    private func rebuildDomainList() {
        domainStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for domain in blocker.blockedDomains {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 4

            let label = NSTextField(labelWithString: domain)
            label.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            label.lineBreakMode = .byTruncatingTail

            let removeBtn = NSButton(title: "x", target: self, action: #selector(removeDomainClicked(_:)))
            removeBtn.bezelStyle = .inline
            removeBtn.font = .systemFont(ofSize: 10, weight: .bold)
            removeBtn.cell?.representedObject = domain
            removeBtn.setContentHuggingPriority(.required, for: .horizontal)

            row.addArrangedSubview(label)
            row.addArrangedSubview(removeBtn)
            domainStackView.addArrangedSubview(row)
        }

        if blocker.blockedDomains.isEmpty {
            let empty = NSTextField(labelWithString: "No domains added yet")
            empty.textColor = .tertiaryLabelColor
            empty.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            domainStackView.addArrangedSubview(empty)
        }
    }
}
