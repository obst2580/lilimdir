import Foundation

// A small VT-style screen used by the dependency-free terminal.
// The terminal frontend and PTY transport are separate so another emulator can replace this one.
final class TerminalBuffer {
    private(set) var columns: Int
    private(set) var rows: Int
    private(set) var screen: [[TerminalCell]]
    private(set) var scrollback: [[TerminalCell]] = []
    private(set) var cursorX = 0
    private(set) var cursorY = 0
    private(set) var cursorVisible = true
    private(set) var bracketedPaste = false
    private(set) var applicationCursor = false
    private(set) var alternateScreen = false
    private(set) var mouseTrackingMode = 0
    private(set) var sgrMouse = false
    private(set) var alternateScroll = false
    var titleChanged: ((String) -> Void)?
    var directoryChanged: ((String) -> Void)?
    var respond: (([UInt8]) -> Void)?

    private var style = TerminalCell()
    private var savedCursor = (x: 0, y: 0)
    private var savedScreen: [[TerminalCell]]?
    private var normalCursor = (x: 0, y: 0)
    private var scrollTop = 0
    private var scrollBottom: Int
    private var wrapPending = false
    private var lastWrittenCell: (x: Int, y: Int)?
    private var state = 0 // 0 text, 1 ESC, 2 CSI, 3 OSC, 4 OSC escape, 5 charset
    private var sequence = ""
    private var unicodeBytes: [UInt8] = []
    private var unicodeExpected = 0

    init(columns: Int = 80, rows: Int = 24) {
        self.columns = columns
        self.rows = rows
        self.scrollBottom = rows - 1
        screen = Array(repeating: Array(repeating: TerminalCell(), count: columns), count: rows)
    }

    var allLines: [[TerminalCell]] { alternateScreen ? screen : scrollback + screen }
    var cursorLine: Int { (alternateScreen ? 0 : scrollback.count) + cursorY }

    var handlesScrollInput: Bool { mouseTrackingMode != 0 || (alternateScreen && alternateScroll) }

    // Xterm wheel presses have no release event. Coordinates are one-based screen cells.
    func scrollInput(up: Bool, column: Int, row: Int, modifiers: Int = 0) -> [UInt8]? {
        if mouseTrackingMode != 0 {
            let x = min(columns - 1, max(0, column)) + 1
            let y = min(rows - 1, max(0, row)) + 1
            let button = (up ? 64 : 65) | (modifiers & 28)
            if sgrMouse { return Array("\u{1b}[<\(button);\(x);\(y)M".utf8) }
            // The original byte protocol cannot represent cells beyond 223.
            guard x <= 223, y <= 223 else { return [] }
            return [27, 91, 77, UInt8(button + 32), UInt8(x + 32), UInt8(y + 32)]
        }
        if alternateScreen && alternateScroll {
            return Array(((applicationCursor ? "\u{1b}O" : "\u{1b}[") + (up ? "A" : "B")).utf8)
        }
        return nil
    }

    func resize(columns newColumns: Int, rows newRows: Int) {
        let width = max(10, newColumns), height = max(3, newRows)
        guard width != columns || height != rows else { return }
        lastWrittenCell = nil
        for index in screen.indices {
            if width > screen[index].count { screen[index] += Array(repeating: TerminalCell(), count: width - screen[index].count) }
            else { screen[index] = Array(screen[index].prefix(width)) }
        }
        if height > screen.count { screen += Array(repeating: Array(repeating: TerminalCell(), count: width), count: height - screen.count) }
        else if height < screen.count {
            var removed = screen.count - height
            // Shrinking unused space must not put the current prompt into history.
            // Keep the cursor row, and scroll only content that no longer fits.
            while removed > 0, screen.count - 1 > cursorY,
                  screen.last?.allSatisfy({ $0.text == " " && !$0.continuation }) == true {
                screen.removeLast()
                removed -= 1
            }
            if removed > 0 {
                if !alternateScreen { scrollback += screen.prefix(removed) }
                screen.removeFirst(removed)
                cursorY = max(0, cursorY - removed)
            }
        }
        columns = width; rows = height
        cursorX = min(cursorX, width - 1); cursorY = min(cursorY, height - 1)
        scrollTop = 0; scrollBottom = height - 1; wrapPending = false
        capScrollback()
    }

    func feed(_ bytes: [UInt8]) {
        for byte in bytes {
            switch state {
            case 1: escape(byte)
            case 2:
                if byte >= 0x40 && byte <= 0x7e {
                    executeCSI(final: byte); sequence = ""; state = 0
                } else if sequence.count < 256 { sequence.append(Character(UnicodeScalar(byte))) }
                else { sequence = ""; state = 0; lastWrittenCell = nil }
            case 3:
                if byte == 7 { executeOSC(); state = 0 }
                else if byte == 27 { state = 4 }
                else if sequence.utf8.count < 8192 { sequence.append(Character(UnicodeScalar(byte))) }
                else { sequence = ""; state = 0 }
            case 4:
                if byte == 92 { executeOSC(); state = 0 }
                else { state = 3 }
            case 5: state = 0
            default: consume(byte)
            }
        }
    }

    func text(from start: (line: Int, column: Int), to end: (line: Int, column: Int)) -> String {
        let lines = allLines
        let a = (start.line, start.column) <= (end.line, end.column) ? start : end
        let b = (start.line, start.column) <= (end.line, end.column) ? end : start
        guard !lines.isEmpty, a.line < lines.count, b.line >= 0 else { return "" }
        var result: [String] = []
        for line in max(0, a.line)...min(lines.count - 1, max(a.line, b.line)) {
            let lower = line == a.line ? max(0, a.column) : 0
            let upper = line == b.line ? min(lines[line].count, b.column + 1) : lines[line].count
            guard lower < upper else { result.append(""); continue }
            let value = lines[line][lower..<upper].filter { !$0.continuation }.map(\.text).joined()
            result.append(value.replacingOccurrences(of: " +$", with: "", options: .regularExpression))
        }
        return result.joined(separator: "\n")
    }

    private func consume(_ byte: UInt8) {
        if byte < 32 || byte == 127 {
            unicodeBytes = []; unicodeExpected = 0
            if byte != 27 && byte != 7 { lastWrittenCell = nil }
            switch byte {
            case 27: state = 1
            case 13: cursorX = 0; wrapPending = false
            case 10, 11, 12: lineFeed()
            case 8: cursorX = max(0, cursorX - 1); wrapPending = false
            case 9: cursorX = min(columns - 1, ((cursorX / 8) + 1) * 8); wrapPending = false
            default: break
            }
        } else if byte < 128 {
            if !unicodeBytes.isEmpty { unicodeBytes = []; unicodeExpected = 0 }
            write(String(UnicodeScalar(byte)))
        } else {
            if unicodeBytes.isEmpty {
                unicodeExpected = byte < 0xe0 ? 2 : (byte < 0xf0 ? 3 : 4)
            }
            unicodeBytes.append(byte)
            if unicodeBytes.count == unicodeExpected {
                let string = String(decoding: unicodeBytes, as: UTF8.self)
                for scalar in string.unicodeScalars { write(String(scalar)) }
                unicodeBytes = []; unicodeExpected = 0
            }
        }
    }

    private func write(_ text: String) {
        guard let scalar = text.unicodeScalars.first else { return }
        // PTY reads can split a grapheme between bytes, scalars, or color escapes.
        // Extend its leading cell before considering wrapping or advancing the cursor.
        // Keeping the original scalars here also preserves filesystem paths on copy.
        if let last = lastWrittenCell {
            let combined = screen[last.y][last.x].text + text
            if combined.count == 1 {
                screen[last.y][last.x].text = combined
                return
            }
        }
        if scalar.properties.generalCategory == .nonspacingMark { return }
        let v = scalar.value
        let wide = (v >= 0x1100 && v <= 0x115f) || (v >= 0x2e80 && v <= 0xa4cf)
            || (v >= 0xac00 && v <= 0xd7a3) || (v >= 0xf900 && v <= 0xfaff)
            || (v >= 0xfe10 && v <= 0xfe6f) || (v >= 0xff01 && v <= 0xff60)
            || (v >= 0x1f300 && v <= 0x1faff) || (v >= 0x20000 && v <= 0x3ffff)
        let width = wide ? 2 : 1
        if wrapPending || cursorX + width > columns { cursorX = 0; lineFeed(); wrapPending = false }
        var cell = style; cell.text = text; cell.continuation = false
        screen[cursorY][cursorX] = cell
        if width == 2 {
            var trailing = style; trailing.continuation = true
            screen[cursorY][cursorX + 1] = trailing
        }
        lastWrittenCell = (cursorX, cursorY)
        cursorX += width
        if cursorX >= columns { cursorX = columns - 1; wrapPending = true }
    }

    private func lineFeed() {
        lastWrittenCell = nil
        wrapPending = false
        if cursorY == scrollBottom { scrollUp() }
        else { cursorY = min(rows - 1, cursorY + 1) }
    }

    private func blankLine() -> [TerminalCell] { Array(repeating: style, count: columns) }

    private func scrollUp() {
        let removed = screen.remove(at: scrollTop)
        screen.insert(blankLine(), at: scrollBottom)
        if scrollTop == 0 && scrollBottom == rows - 1 && !alternateScreen { scrollback.append(removed); capScrollback() }
    }

    private func capScrollback() {
        if scrollback.count > 5000 { scrollback.removeFirst(scrollback.count - 5000) }
    }

    private func escape(_ byte: UInt8) {
        state = 0
        if byte != 91 && byte != 93 { lastWrittenCell = nil }
        switch byte {
        case 91: state = 2; sequence = ""
        case 93: state = 3; sequence = ""
        case 40, 41, 42, 43: state = 5
        case 55: savedCursor = (cursorX, cursorY)
        case 56: cursorX = min(savedCursor.x, columns - 1); cursorY = min(savedCursor.y, rows - 1); wrapPending = false
        case 68: lineFeed()
        case 69: cursorX = 0; lineFeed()
        case 77:
            if cursorY == scrollTop { screen.remove(at: scrollBottom); screen.insert(blankLine(), at: scrollTop) }
            else { cursorY = max(0, cursorY - 1) }
        case 99:
            style = TerminalCell(); screen = Array(repeating: blankLine(), count: rows)
            cursorX = 0; cursorY = 0; wrapPending = false
            mouseTrackingMode = 0; sgrMouse = false; alternateScroll = false
        default: break
        }
    }

    private func executeCSI(final: UInt8) {
        if final != 109 { lastWrittenCell = nil }
        let isPrivate = sequence.hasPrefix("?")
        let cleaned = sequence.trimmingCharacters(in: CharacterSet(charactersIn: "?>!"))
        let params = cleaned.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        let first = params.first ?? 0
        let count = min(max(1, first), max(rows, columns))
        let value = min(1_000_000, max(1, first))
        switch final {
        case 65: cursorY = max(0, cursorY - count)
        case 66: cursorY = min(rows - 1, cursorY + count)
        case 67: cursorX = min(columns - 1, cursorX + count)
        case 68: cursorX = max(0, cursorX - count)
        case 69: cursorX = 0; cursorY = min(rows - 1, cursorY + count)
        case 70: cursorX = 0; cursorY = max(0, cursorY - count)
        case 71, 96: cursorX = min(columns - 1, value - 1)
        case 100: cursorY = min(rows - 1, value - 1)
        case 72, 102:
            cursorY = min(rows - 1, value - 1)
            cursorX = min(columns - 1, max(1, params.count > 1 ? params[1] : 1) - 1)
        case 74:
            if first == 2 { screen = Array(repeating: blankLine(), count: rows) }
            else if first == 3 { scrollback = [] }
            else if first == 0 {
                clear(row: cursorY, from: cursorX, through: columns - 1)
                if cursorY + 1 < rows { for row in (cursorY + 1)..<rows { screen[row] = blankLine() } }
            } else if first == 1 {
                if cursorY > 0 { for row in 0..<cursorY { screen[row] = blankLine() } }
                clear(row: cursorY, from: 0, through: cursorX)
            }
        case 75:
            clear(row: cursorY, from: first == 0 ? cursorX : 0, through: first == 1 ? cursorX : columns - 1)
        case 109: setStyle(params)
        case 114:
            scrollTop = min(rows - 1, value - 1)
            scrollBottom = min(rows - 1, max(1, params.count > 1 && params[1] > 0 ? params[1] : rows) - 1)
            if scrollBottom <= scrollTop { scrollTop = 0; scrollBottom = rows - 1 }
            cursorX = 0; cursorY = 0
        case 115: savedCursor = (cursorX, cursorY)
        case 117: cursorX = min(columns - 1, savedCursor.x); cursorY = min(rows - 1, savedCursor.y)
        case 104, 108:
            if isPrivate {
                for mode in params {
                    if mode == 25 { cursorVisible = final == 104 }
                    if mode == 1 { applicationCursor = final == 104 }
                    if mode == 2004 { bracketedPaste = final == 104 }
                    if mode == 1000 || mode == 1002 || mode == 1003 {
                        if final == 104 { mouseTrackingMode = mode }
                        else if mouseTrackingMode == mode { mouseTrackingMode = 0 }
                    }
                    if mode == 1006 { sgrMouse = final == 104 }
                    if mode == 1007 { alternateScroll = final == 104 }
                    if mode == 1049 || mode == 47 || mode == 1047 { switchScreen(final == 104) }
                }
            }
        case 80:
            let amount = min(count, columns - cursorX)
            screen[cursorY].removeSubrange(cursorX..<(cursorX + amount))
            screen[cursorY] += Array(repeating: style, count: amount)
        case 64:
            let amount = min(count, columns - cursorX)
            screen[cursorY].insert(contentsOf: Array(repeating: style, count: amount), at: cursorX)
            screen[cursorY] = Array(screen[cursorY].prefix(columns))
        case 88: clear(row: cursorY, from: cursorX, through: min(columns - 1, cursorX + count - 1))
        case 76:
            if cursorY >= scrollTop && cursorY <= scrollBottom {
                for _ in 0..<min(count, scrollBottom - cursorY + 1) { screen.remove(at: scrollBottom); screen.insert(blankLine(), at: cursorY) }
            }
        case 77:
            if cursorY >= scrollTop && cursorY <= scrollBottom {
                for _ in 0..<min(count, scrollBottom - cursorY + 1) { screen.remove(at: cursorY); screen.insert(blankLine(), at: scrollBottom) }
            }
        case 83: for _ in 0..<count { scrollUp() }
        case 84: for _ in 0..<count { screen.remove(at: scrollBottom); screen.insert(blankLine(), at: scrollTop) }
        case 110:
            if first == 6 { respond?(Array("\u{1b}[\(cursorY + 1);\(cursorX + 1)R".utf8)) }
            if first == 5 { respond?(Array("\u{1b}[0n".utf8)) }
        case 99: respond?(Array("\u{1b}[?1;2c".utf8))
        default: break
        }
        if final != 109 { wrapPending = false }
    }

    private func clear(row: Int, from: Int, through: Int) {
        guard from <= through else { return }
        for column in from...through { screen[row][column] = style }
    }

    private func setStyle(_ params: [Int]) {
        var index = 0
        while index < params.count {
            let value = params[index]
            switch value {
            case 0: style = TerminalCell()
            case 1: style.bold = true
            case 22: style.bold = false
            case 7: style.inverse = true
            case 27: style.inverse = false
            case 30...37: style.foreground = value - 30
            case 90...97: style.foreground = value - 90 + 8
            case 40...47: style.background = value - 40
            case 100...107: style.background = value - 100 + 8
            case 39: style.foreground = -1
            case 49: style.background = -1
            case 38, 48:
                if index + 2 < params.count && params[index + 1] == 5 {
                    let color = min(255, max(0, params[index + 2]))
                    if value == 38 { style.foreground = color } else { style.background = color }
                    index += 2
                } else if index + 4 < params.count && params[index + 1] == 2 {
                    let rgb = params[(index + 2)...(index + 4)].map { min(255, max(0, $0)) }
                    let color = 0x1000000 | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]
                    if value == 38 { style.foreground = color } else { style.background = color }
                    index += 4
                }
            default: break
            }
            index += 1
        }
    }

    private func switchScreen(_ enabled: Bool) {
        guard enabled != alternateScreen else { return }
        if enabled {
            savedScreen = screen; normalCursor = (cursorX, cursorY)
            screen = Array(repeating: blankLine(), count: rows)
            cursorX = 0; cursorY = 0
        } else if let savedScreen {
            screen = savedScreen.map { Array(($0 + Array(repeating: TerminalCell(), count: columns)).prefix(columns)) }
            if screen.count < rows { screen += Array(repeating: blankLine(), count: rows - screen.count) }
            if screen.count > rows { screen = Array(screen.suffix(rows)) }
            cursorX = min(normalCursor.x, columns - 1); cursorY = min(normalCursor.y, rows - 1)
            self.savedScreen = nil
        }
        alternateScreen = enabled; scrollTop = 0; scrollBottom = rows - 1
    }

    private func executeOSC() {
        // OSC is accumulated byte-by-byte. Decode the original UTF-8 bytes here.
        let value = String(decoding: sequence.unicodeScalars.map { UInt8(truncatingIfNeeded: $0.value) }, as: UTF8.self)
        if value.hasPrefix("0;") || value.hasPrefix("2;") { titleChanged?(String(value.dropFirst(2))) }
        if value.hasPrefix("7;") { directoryChanged?(String(value.dropFirst(2))) }
        sequence = ""
    }
}
