import AppKit

enum TerminalKeyInput {
    static func enterSequence(modifiers: NSEvent.ModifierFlags) -> String {
        if modifiers.contains(.shift) {
            // CSI-u preserves Shift, so CLI prompt editors can insert a newline
            // instead of mistaking this key for a submit. Return and keypad Enter
            // share the encoding; lock and AppKit bookkeeping flags are ignored.
            let modifier = 1 + 1 + (modifiers.contains(.option) ? 2 : 0) + (modifiers.contains(.control) ? 4 : 0)
            return "\u{1b}[13;\(modifier)u"
        }
        return modifiers.contains(.option) ? "\u{1b}\r" : "\r"
    }
}
