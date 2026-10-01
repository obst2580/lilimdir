import AppKit

enum TerminalKeyInputChecks {
    static func run() throws {
        func expect(_ modifiers: NSEvent.ModifierFlags, _ bytes: [UInt8], _ message: String) throws {
            if Array(TerminalKeyInput.enterSequence(modifiers: modifiers).utf8) != bytes {
                throw CheckFailure(message: message)
            }
        }
        try expect([], [13], "plain Enter keeps the shell submit byte")
        try expect(.shift, [27, 91, 49, 51, 59, 50, 117], "Shift+Enter is an unambiguous modified key, never a submit byte")
        try expect([.shift, .capsLock, .numericPad, .function], [27, 91, 49, 51, 59, 50, 117], "keypad and lock flags do not change Shift+Enter")
        try expect([.shift, .control], Array("\u{1b}[13;6u".utf8), "Ctrl+Shift+Enter preserves both modifiers")
        try expect([.shift, .option], Array("\u{1b}[13;4u".utf8), "Option+Shift+Enter preserves both modifiers")
        try expect(.option, [27, 13], "Option+Enter uses the CLI-compatible Meta-Enter encoding")
        try expect(.control, [13], "Ctrl+Enter retains legacy encoding")
        print("PASS · Enter 실행·Shift+Enter 줄바꿈 구분·키패드/잠금 키·조합 키 인코딩")
    }
}
