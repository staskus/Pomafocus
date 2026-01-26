import AppKit
import PomafocusKit

final class PreferencesWindowController: NSWindowController {
    private let settings: PomodoroSettings
    private let onUpdate: (PomodoroSettings.Snapshot) -> Void
    private let minutesField = NSTextField(string: "")
    private lazy var hotkeyField: HotkeyField = HotkeyField(hotkey: currentSnapshot.hotkey)
    private let deepBreathCheckbox = NSButton(checkboxWithTitle: "Require a 30-second deep breath before stopping", target: nil, action: nil)
    private let blockedSitesView = NSTextView()
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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 440),
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

        configureSitesView(blockedSitesView)

        hotkeyField.onChange = { [weak self] hotkey in
            self?.currentSnapshot.hotkey = hotkey
        }
        deepBreathCheckbox.target = self
        deepBreathCheckbox.action = #selector(toggleDeepBreath(_:))
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
        let blockedSitesLabel = NSTextField(labelWithString: "Blocked websites (one per line)")
        let saveButton = NSButton(title: "Save", target: self, action: #selector(savePreferences))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let blockedSitesScrollView = makeSitesScrollView(for: blockedSitesView)

        stack.addArrangedSubview(minutesLabel)
        stack.addArrangedSubview(minutesField)
        stack.addArrangedSubview(hotkeyLabel)
        stack.addArrangedSubview(hotkeyField)
        stack.addArrangedSubview(deepBreathCheckbox)
        stack.addArrangedSubview(blockedSitesLabel)
        stack.addArrangedSubview(blockedSitesScrollView)
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
        blockedSitesView.string = blocker.blockedDomainsText
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
        blocker.updateBlockedDomainsText(blockedSitesView.string)
        onUpdate(currentSnapshot)
        window?.close()
    }

    @objc private func toggleDeepBreath(_ sender: NSButton) {
        currentSnapshot.deepBreathEnabled = sender.state == .on
    }

    private func configureSitesView(_ view: NSTextView) {
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.heightTracksTextView = false
        view.isEditable = true
        view.isRichText = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    }

    private func makeSitesScrollView(for textView: NSTextView) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView
        scrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        return scrollView
    }
}
