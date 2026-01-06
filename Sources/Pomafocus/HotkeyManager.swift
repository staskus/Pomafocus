import AppKit
import Carbon

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handler: (() -> Void)?

    init() {
        installEventHandler()
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(hotkey: Hotkey, handler: @escaping () -> Void) {
        unregister()
        self.handler = handler
        let hotKeyID = EventHotKeyID(signature: FourCharCode(from: "Poma"), id: 1)
        let status = RegisterEventHotKey(UInt32(hotkey.keyCode), hotkey.carbonFlags, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Failed to register hotkey with status \(status)")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        handler = nil
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            hotkeyManager.handleHotkeyEvent()
            return noErr
        }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandler)
    }

    private func handleHotkeyEvent() {
        handler?()
    }
}

private extension FourCharCode {
    init(from string: String) {
        var result: UInt32 = 0
        for scalar in string.utf16 {
            result = (result << 8) + UInt32(scalar)
        }
        self = result
    }
}
