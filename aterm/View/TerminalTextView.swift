import AppKit

final class TerminalInputTextView: NSTextView {
    var onInput: ((String) -> Void)?
    var onKeyEvent: ((GhosttyKeyAction, GhosttyKey, GhosttyMods, String?) -> Void)?

    override func keyDown(with event: NSEvent) {
        let mods = Self.ghosttyMods(from: event.modifierFlags)

        // Try key encoder for all mapped keys
        if let ghosttyKey = Self.ghosttyKey(from: event.keyCode) {
            let text = event.characters
            onKeyEvent?(GHOSTTY_KEY_ACTION_PRESS, ghosttyKey, mods, text)
            return
        }

        // Fallback: regular text input
        if let chars = event.characters, !chars.isEmpty {
            onInput?(chars)
            return
        }

        super.keyDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        onKeyEvent?(GHOSTTY_KEY_ACTION_PRESS, GHOSTTY_KEY_ENTER, 0, "\r")
    }

    override func insertTab(_ sender: Any?) {
        onKeyEvent?(GHOSTTY_KEY_ACTION_PRESS, GHOSTTY_KEY_TAB, 0, "\t")
    }

    override func deleteBackward(_ sender: Any?) {
        onKeyEvent?(GHOSTTY_KEY_ACTION_PRESS, GHOSTTY_KEY_BACKSPACE, 0, nil)
    }

    // MARK: - Key Mapping

    static func ghosttyMods(from flags: NSEvent.ModifierFlags) -> GhosttyMods {
        var mods: UInt16 = 0
        let clean = flags.intersection(.deviceIndependentFlagsMask)
        if clean.contains(.shift) { mods |= UInt16(GHOSTTY_MODS_SHIFT) }
        if clean.contains(.control) { mods |= UInt16(GHOSTTY_MODS_CTRL) }
        if clean.contains(.option) { mods |= UInt16(GHOSTTY_MODS_ALT) }
        if clean.contains(.command) { mods |= UInt16(GHOSTTY_MODS_SUPER) }
        if clean.contains(.capsLock) { mods |= UInt16(GHOSTTY_MODS_CAPS_LOCK) }
        return mods
    }

    // macOS keyCode → GhosttyKey mapping
    // Based on W3C UIEvents KeyboardEvent code values
    static func ghosttyKey(from keyCode: UInt16) -> GhosttyKey? {
        switch keyCode {
        // Letters
        case 0: return GHOSTTY_KEY_A
        case 11: return GHOSTTY_KEY_B
        case 8: return GHOSTTY_KEY_C
        case 2: return GHOSTTY_KEY_D
        case 14: return GHOSTTY_KEY_E
        case 3: return GHOSTTY_KEY_F
        case 5: return GHOSTTY_KEY_G
        case 4: return GHOSTTY_KEY_H
        case 34: return GHOSTTY_KEY_I
        case 38: return GHOSTTY_KEY_J
        case 40: return GHOSTTY_KEY_K
        case 37: return GHOSTTY_KEY_L
        case 46: return GHOSTTY_KEY_M
        case 45: return GHOSTTY_KEY_N
        case 31: return GHOSTTY_KEY_O
        case 35: return GHOSTTY_KEY_P
        case 12: return GHOSTTY_KEY_Q
        case 15: return GHOSTTY_KEY_R
        case 1: return GHOSTTY_KEY_S
        case 17: return GHOSTTY_KEY_T
        case 32: return GHOSTTY_KEY_U
        case 9: return GHOSTTY_KEY_V
        case 13: return GHOSTTY_KEY_W
        case 7: return GHOSTTY_KEY_X
        case 16: return GHOSTTY_KEY_Y
        case 6: return GHOSTTY_KEY_Z

        // Digits
        case 29: return GHOSTTY_KEY_DIGIT_0
        case 18: return GHOSTTY_KEY_DIGIT_1
        case 19: return GHOSTTY_KEY_DIGIT_2
        case 20: return GHOSTTY_KEY_DIGIT_3
        case 21: return GHOSTTY_KEY_DIGIT_4
        case 23: return GHOSTTY_KEY_DIGIT_5
        case 22: return GHOSTTY_KEY_DIGIT_6
        case 26: return GHOSTTY_KEY_DIGIT_7
        case 28: return GHOSTTY_KEY_DIGIT_8
        case 25: return GHOSTTY_KEY_DIGIT_9

        // Punctuation
        case 27: return GHOSTTY_KEY_MINUS
        case 24: return GHOSTTY_KEY_EQUAL
        case 33: return GHOSTTY_KEY_BRACKET_LEFT
        case 30: return GHOSTTY_KEY_BRACKET_RIGHT
        case 42: return GHOSTTY_KEY_BACKSLASH
        case 41: return GHOSTTY_KEY_SEMICOLON
        case 39: return GHOSTTY_KEY_QUOTE
        case 43: return GHOSTTY_KEY_COMMA
        case 47: return GHOSTTY_KEY_PERIOD
        case 44: return GHOSTTY_KEY_SLASH
        case 50: return GHOSTTY_KEY_BACKQUOTE

        // Function keys
        case 53: return GHOSTTY_KEY_ESCAPE
        case 36: return GHOSTTY_KEY_ENTER
        case 48: return GHOSTTY_KEY_TAB
        case 49: return GHOSTTY_KEY_SPACE
        case 51: return GHOSTTY_KEY_BACKSPACE
        case 117: return GHOSTTY_KEY_DELETE

        // Navigation
        case 126: return GHOSTTY_KEY_ARROW_UP
        case 125: return GHOSTTY_KEY_ARROW_DOWN
        case 123: return GHOSTTY_KEY_ARROW_LEFT
        case 124: return GHOSTTY_KEY_ARROW_RIGHT
        case 115: return GHOSTTY_KEY_HOME
        case 119: return GHOSTTY_KEY_END
        case 116: return GHOSTTY_KEY_PAGE_UP
        case 121: return GHOSTTY_KEY_PAGE_DOWN

        // F-keys
        case 122: return GHOSTTY_KEY_F1
        case 120: return GHOSTTY_KEY_F2
        case 99: return GHOSTTY_KEY_F3
        case 118: return GHOSTTY_KEY_F4
        case 96: return GHOSTTY_KEY_F5
        case 97: return GHOSTTY_KEY_F6
        case 98: return GHOSTTY_KEY_F7
        case 100: return GHOSTTY_KEY_F8
        case 101: return GHOSTTY_KEY_F9
        case 109: return GHOSTTY_KEY_F10
        case 103: return GHOSTTY_KEY_F11
        case 111: return GHOSTTY_KEY_F12

        default: return nil
        }
    }
}
