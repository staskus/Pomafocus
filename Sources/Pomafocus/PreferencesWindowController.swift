import AppKit
import PomafocusKit

final class PreferencesWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let settings: PomodoroSettings
    private let onUpdate: (PomodoroSettings.Snapshot) -> Void
    private let minutesField = NSTextField(string: "")
    private lazy var hotkeyField: HotkeyField = HotkeyField(hotkey: currentSnapshot.hotkey)
    private let deepBreathCheckbox = NSButton(checkboxWithTitle: "Require a 30-second deep breath before stopping", target: nil, action: nil)
    private let setupButton = NSButton(title: "Setup Blocking", target: nil, action: nil)
    private let daemonStatusLabel = NSTextField(labelWithString: "")
    private let domainField = NSTextField(string: "")
    private let addDomainButton = NSButton(title: "Add", target: nil, action: nil)
    private let removeDomainButton = NSButton(title: "Remove", target: nil, action: nil)
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let blocker = PomodoroBlocker.shared
    private var currentSnapshot: PomodoroSettings.Snapshot

    private static let domainColumnID = NSUserInterfaceItemIdentifier("domain")

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
        removeDomainButton.target = self
        removeDomainButton.action = #selector(removeSelectedDomain)
        removeDomainButton.bezelStyle = .rounded
        removeDomainButton.isEnabled = false

        let column = NSTableColumn(identifier: Self.domainColumnID)
        column.title = "Blocked Domains"
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 22
        tableView.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
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

        let domainRow = NSStackView(views: [domainField, addDomainButton, removeDomainButton])
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
        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(domainRow)
        stack.addArrangedSubview(saveButton)

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    private func applySnapshotToFields() {
        minutesField.stringValue = "\(currentSnapshot.minutes)"
        hotkeyField.hotkey = currentSnapshot.hotkey
        deepBreathCheckbox.state = currentSnapshot.deepBreathEnabled ? .on : .off
        updateDaemonStatus()
        tableView.reloadData()
    }

    func applyExternalSnapshot(_ snapshot: PomodoroSettings.Snapshot) {
        currentSnapshot = snapshot
        if window?.isVisible == true {
            applySnapshotToFields()
        }
    }

    // MARK: - Actions

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
        tableView.reloadData()
    }

    @objc private func removeSelectedDomain() {
        let row = tableView.selectedRow
        guard row >= 0, row < blocker.blockedDomains.count else { return }
        blocker.removeDomain(blocker.blockedDomains[row])
        tableView.reloadData()
        removeDomainButton.isEnabled = false
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

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        blocker.blockedDomains.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        blocker.blockedDomains[row]
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellID = NSUserInterfaceItemIdentifier("DomainCell")
        let cell = tableView.makeView(withIdentifier: cellID, owner: nil) as? NSTextField
            ?? {
                let tf = NSTextField(labelWithString: "")
                tf.identifier = cellID
                tf.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
                tf.lineBreakMode = .byTruncatingTail
                return tf
            }()
        cell.stringValue = blocker.blockedDomains[row]
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeDomainButton.isEnabled = tableView.selectedRow >= 0
    }
}
