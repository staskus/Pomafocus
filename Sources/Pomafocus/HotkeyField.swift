import AppKit

final class HotkeyField: NSView {
    var hotkey: Hotkey {
        didSet {
            label.stringValue = hotkey.displayName
        }
    }

    var onChange: ((Hotkey) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private let validModifiers: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
    private var isRecording = false

    init(hotkey: Hotkey) {
        self.hotkey = hotkey
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 6
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 32),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        label.stringValue = hotkey.displayName
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        beginRecording()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let modifiers = event.modifierFlags.intersection(validModifiers)
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }

        let capturedHotkey = Hotkey(keyCode: UInt32(event.keyCode), modifierFlags: modifiers)
        hotkey = capturedHotkey
        onChange?(capturedHotkey)
        endRecording()
    }

    override func resignFirstResponder() -> Bool {
        endRecording()
        return super.resignFirstResponder()
    }

    private func beginRecording() {
        isRecording = true
        updateAppearance()
        label.stringValue = "Press shortcut"
    }

    private func endRecording() {
        if isRecording {
            isRecording = false
            updateAppearance()
            label.stringValue = hotkey.displayName
        }
    }

    private func updateAppearance() {
        layer?.borderWidth = 1
        layer?.borderColor = (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
    }
}
