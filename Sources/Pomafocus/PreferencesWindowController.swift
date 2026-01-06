import AppKit
import PomafocusKit

final class PreferencesWindowController: NSWindowController {
    private let settings: PomodoroSettings
    private let onUpdate: (PomodoroSettings.Snapshot) -> Void

    private let minutesField = NSTextField(string: "")
    private lazy var hotkeyField: HotkeyField = HotkeyField(hotkey: currentSnapshot.hotkey)
    private let websitesTextView = NSTextView(frame: .zero)
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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 320),
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

        websitesTextView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        websitesTextView.isAutomaticQuoteSubstitutionEnabled = false
        websitesTextView.isAutomaticDashSubstitutionEnabled = false
        websitesTextView.string = blocker.blockedWebsites.joined(separator: "\n")
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
        let websitesLabel = NSTextField(labelWithString: "Blocked websites (one per line)")

        let saveButton = NSButton(title: "Save", target: self, action: #selector(savePreferences))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = websitesTextView
        scrollView.contentView.automaticallyAdjustsContentInsets = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true

        stack.addArrangedSubview(minutesLabel)
        stack.addArrangedSubview(minutesField)
        stack.addArrangedSubview(hotkeyLabel)
        stack.addArrangedSubview(hotkeyField)
        stack.addArrangedSubview(websitesLabel)
        stack.addArrangedSubview(scrollView)
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
        websitesTextView.string = blocker.blockedWebsites.joined(separator: "\n")
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
        blocker.setBlockedWebsites(parsedWebsites())
        onUpdate(currentSnapshot)
        window?.close()
    }

    private func parsedWebsites() -> [String] {
        websitesTextView.string
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
