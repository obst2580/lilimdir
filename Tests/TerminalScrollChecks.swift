import Foundation

enum TerminalScrollChecks {
    static func run() throws {
        let buffer = TerminalBuffer(columns: 300, rows: 30)
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw CheckFailure(message: message) }
        }
        func feed(_ text: String) { buffer.feed(Array(text.utf8)) }

        feed("shell output\r\nprompt> ")
        let shell = buffer.allLines
        try expect(!buffer.handlesScrollInput && buffer.scrollInput(up: true, column: 2, row: 3) == nil,
                   "ordinary shell wheel remains local history scrolling")
        // This is the actual mode sequence observed from Codex CLI 0.159.2.
        feed("\u{1b}[?1049h\u{1b}[?1007l\u{1b}[?1000h\u{1b}[?1002h\u{1b}[?1003h\u{1b}[?1006h")
        try expect(buffer.alternateScreen && buffer.handlesScrollInput, "Codex requests application wheel input")
        try expect(buffer.scrollInput(up: true, column: 249, row: 4) == Array("\u{1b}[<64;250;5M".utf8),
                   "SGR wheel up uses one-based coordinates beyond legacy byte range")
        try expect(buffer.scrollInput(up: false, column: 2, row: 3) == Array("\u{1b}[<65;3;4M".utf8),
                   "SGR wheel down is a press without a release")
        try expect(buffer.scrollInput(up: true, column: -2, row: 100, modifiers: 24) == Array("\u{1b}[<88;1;30M".utf8),
                   "mouse coordinates stay in the screen and preserve option/control modifiers")
        feed("\u{1b}[?1006l\u{1b}[?1003l\u{1b}[?1002l\u{1b}[?1000l\u{1b}[?1049l")
        try expect(buffer.allLines == shell && !buffer.handlesScrollInput,
                   "Codex exit restores the shell screen and ordinary wheel scrolling")

        feed("\u{1b}[?1006h")
        try expect(!buffer.handlesScrollInput, "encoding alone does not enable mouse capture")
        feed("\u{1b}[?1000h\u{1b}[?1006l")
        try expect(buffer.scrollInput(up: true, column: 2, row: 3) == [27, 91, 77, 96, 35, 36],
                   "legacy xterm wheel encoding")
        try expect(buffer.scrollInput(up: false, column: 250, row: 3) == [],
                   "legacy coordinates never overflow or report a different cell")
        feed("\u{1b}[?1002h\u{1b}[?1000l")
        try expect(buffer.mouseTrackingMode == 1002, "disabling an inactive tracking mode preserves the active one")
        feed("\u{1b}[?1002l\u{1b}[?1049h")
        try expect(buffer.scrollInput(up: true, column: 0, row: 0) == nil,
                   "alternate screen alone does not inject unexpected arrow keys")
        feed("\u{1b}[?1007h")
        try expect(buffer.scrollInput(up: true, column: 0, row: 0) == Array("\u{1b}[A".utf8),
                   "explicit alternate-scroll mode sends normal cursor keys")
        feed("\u{1b}[?1h")
        try expect(buffer.scrollInput(up: false, column: 0, row: 0) == Array("\u{1b}OB".utf8),
                   "alternate-scroll honors application cursor mode")
        feed("\u{1b}[?1007l\u{1b}[?1000;1006h\u{1b}c")
        try expect(!buffer.handlesScrollInput && !buffer.sgrMouse, "terminal reset clears mouse input modes")

        // Incremental PTY reads may divide a mode sequence at any byte.
        for byte in "\u{1b}[?1000;1006h".utf8 { buffer.feed([byte]) }
        try expect(buffer.scrollInput(up: false, column: 0, row: 0) == Array("\u{1b}[<65;1;1M".utf8),
                   "split private-mode sequences still enable wheel input")
        print("PASS · Codex 마우스 휠 모드·SGR/기존 좌표·대체 화면 스크롤·종료 후 일반 셸 복귀")
    }
}
