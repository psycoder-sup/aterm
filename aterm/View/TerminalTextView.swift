import AppKit

final class TerminalInputTextView: NSTextView {
    var onInput: ((String) -> Void)?
    var onBytes: (([UInt8]) -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Handle Ctrl+key combinations
        if modifiers.contains(.control), let chars = event.charactersIgnoringModifiers {
            for char in chars.unicodeScalars {
                let value = char.value
                if value >= UInt32(Character("a").asciiValue!),
                   value <= UInt32(Character("z").asciiValue!)
                {
                    let controlCode = UInt8(value - UInt32(Character("a").asciiValue!) + 1)
                    onBytes?([controlCode])
                    return
                }
                if value == UInt32(Character("[").asciiValue!) {
                    onBytes?([0x1B])
                    return
                }
                if value == UInt32(Character("\\").asciiValue!) {
                    onBytes?([0x1C])
                    return
                }
                if value == UInt32(Character("]").asciiValue!) {
                    onBytes?([0x1D])
                    return
                }
            }
        }

        // Handle special keys
        if let chars = event.charactersIgnoringModifiers, let scalar = chars.unicodeScalars.first {
            switch scalar {
            case "\u{F700}": onBytes?([0x1B, 0x5B, 0x41]); return // Up
            case "\u{F701}": onBytes?([0x1B, 0x5B, 0x42]); return // Down
            case "\u{F702}": onBytes?([0x1B, 0x5B, 0x44]); return // Left
            case "\u{F703}": onBytes?([0x1B, 0x5B, 0x43]); return // Right
            case "\u{F728}": onBytes?([0x1B, 0x5B, 0x33, 0x7E]); return // Delete forward
            case "\u{F729}": onBytes?([0x1B, 0x5B, 0x48]); return // Home
            case "\u{F72B}": onBytes?([0x1B, 0x5B, 0x46]); return // End
            case "\u{F72C}": onBytes?([0x1B, 0x5B, 0x35, 0x7E]); return // Page Up
            case "\u{F72D}": onBytes?([0x1B, 0x5B, 0x36, 0x7E]); return // Page Down
            default: break
            }
        }

        if let chars = event.characters, !chars.isEmpty {
            onInput?(chars)
            return
        }

        super.keyDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        onInput?("\r")
    }

    override func insertTab(_ sender: Any?) {
        onInput?("\t")
    }

    override func deleteBackward(_ sender: Any?) {
        onBytes?([0x7F])
    }
}
