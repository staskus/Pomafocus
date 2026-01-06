import AppKit
import Carbon

struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var modifierFlags: NSEvent.ModifierFlags

    static let `default` = Hotkey(keyCode: UInt32(kVK_ANSI_P), modifierFlags: [.command, .shift])

    var displayName: String {
        let modifiers = modifierSymbols()
        let key = Self.keyName(for: UInt16(keyCode))
        return (modifiers + [key]).joined(separator: " + ")
    }

    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if modifierFlags.contains(.command) { flags |= UInt32(cmdKey) }
        if modifierFlags.contains(.option) { flags |= UInt32(optionKey) }
        if modifierFlags.contains(.shift) { flags |= UInt32(shiftKey) }
        if modifierFlags.contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }

    private func modifierSymbols() -> [String] {
        var symbols: [String] = []
        if modifierFlags.contains(.control) { symbols.append("⌃") }
        if modifierFlags.contains(.option) { symbols.append("⌥") }
        if modifierFlags.contains(.shift) { symbols.append("⇧") }
        if modifierFlags.contains(.command) { symbols.append("⌘") }
        return symbols
    }

    private static func keyName(for keyCode: UInt16) -> String {
        if let name = keyCodeNames[keyCode] {
            return name
        }
        return "Key \(keyCode)"
    }

    private static let keyCodeNames: [UInt16: String] = [
        UInt16(kVK_Space): "Space",
        UInt16(kVK_Return): "Return",
        UInt16(kVK_Escape): "Esc",
        UInt16(kVK_Delete): "Delete",
        UInt16(kVK_Tab): "Tab",
        UInt16(kVK_ANSI_A): "A",
        UInt16(kVK_ANSI_B): "B",
        UInt16(kVK_ANSI_C): "C",
        UInt16(kVK_ANSI_D): "D",
        UInt16(kVK_ANSI_E): "E",
        UInt16(kVK_ANSI_F): "F",
        UInt16(kVK_ANSI_G): "G",
        UInt16(kVK_ANSI_H): "H",
        UInt16(kVK_ANSI_I): "I",
        UInt16(kVK_ANSI_J): "J",
        UInt16(kVK_ANSI_K): "K",
        UInt16(kVK_ANSI_L): "L",
        UInt16(kVK_ANSI_M): "M",
        UInt16(kVK_ANSI_N): "N",
        UInt16(kVK_ANSI_O): "O",
        UInt16(kVK_ANSI_P): "P",
        UInt16(kVK_ANSI_Q): "Q",
        UInt16(kVK_ANSI_R): "R",
        UInt16(kVK_ANSI_S): "S",
        UInt16(kVK_ANSI_T): "T",
        UInt16(kVK_ANSI_U): "U",
        UInt16(kVK_ANSI_V): "V",
        UInt16(kVK_ANSI_W): "W",
        UInt16(kVK_ANSI_X): "X",
        UInt16(kVK_ANSI_Y): "Y",
        UInt16(kVK_ANSI_Z): "Z",
        UInt16(kVK_ANSI_0): "0",
        UInt16(kVK_ANSI_1): "1",
        UInt16(kVK_ANSI_2): "2",
        UInt16(kVK_ANSI_3): "3",
        UInt16(kVK_ANSI_4): "4",
        UInt16(kVK_ANSI_5): "5",
        UInt16(kVK_ANSI_6): "6",
        UInt16(kVK_ANSI_7): "7",
        UInt16(kVK_ANSI_8): "8",
        UInt16(kVK_ANSI_9): "9",
        UInt16(kVK_ANSI_Slash): "/",
        UInt16(kVK_ANSI_Backslash): "\\",
        UInt16(kVK_ANSI_Comma): ",",
        UInt16(kVK_ANSI_Period): ".",
        UInt16(kVK_ANSI_Semicolon): ";",
        UInt16(kVK_ANSI_Quote): "'",
        UInt16(kVK_ANSI_LeftBracket): "[",
        UInt16(kVK_ANSI_RightBracket): "]",
        UInt16(kVK_ANSI_Grave): "`",
        UInt16(kVK_UpArrow): "↑",
        UInt16(kVK_DownArrow): "↓",
        UInt16(kVK_LeftArrow): "←",
        UInt16(kVK_RightArrow): "→",
        UInt16(kVK_F1): "F1",
        UInt16(kVK_F2): "F2",
        UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4",
        UInt16(kVK_F5): "F5",
        UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7",
        UInt16(kVK_F8): "F8",
        UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10",
        UInt16(kVK_F11): "F11",
        UInt16(kVK_F12): "F12"
    ]
}

extension Hotkey {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt32.self, forKey: .keyCode)
        let modifierRaw = try container.decode(UInt64.self, forKey: .modifierFlags)
        modifierFlags = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.RawValue(modifierRaw))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(UInt64(modifierFlags.rawValue), forKey: .modifierFlags)
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode
        case modifierFlags
    }
}
