import AppKit

@MainActor
final class TerminalCanvasView: NSView, @MainActor NSTextInputClient {
    private weak var session: TerminalSession?
    private var font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    private var boldFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
    private(set) var cellWidth: CGFloat = 8
    private(set) var cellHeight: CGFloat = 19
    private var selectionStart: (line: Int, column: Int)?
    private var selectionEnd: (line: Int, column: Int)?
    private var markedText = ""
    private var wheelRemainder: CGFloat = 0
    private var wheelMode = -1
    private let background = Theme.terminalBackgroundColor
    private let foreground = Theme.terminalTextColor
    private let palette: [NSColor] = [
        NSColor(srgbRed: 0.16, green: 0.17, blue: 0.20, alpha: 1), .systemRed, .systemGreen, .systemYellow,
        .systemBlue, .systemPurple, .systemTeal, .lightGray,
        .darkGray, .systemPink, .systemMint, .systemOrange,
        .systemIndigo, .systemPurple, .systemCyan, .white
    ]

    init(session: TerminalSession) {
        self.session = session
        super.init(frame: .zero)
        updateFont(size: session.fontSize)
        setAccessibilityElement(true)
        setAccessibilityRole(.textArea)
        setAccessibilityLabel("터미널. \(session.currentDirectory.path)")
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    func updateFont(size: CGFloat) {
        font = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        boldFont = NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
        cellWidth = ("M" as NSString).size(withAttributes: [.font: font]).width
        cellHeight = ceil(font.ascender - font.descender + font.leading) + 4
    }

    override func draw(_ dirtyRect: NSRect) {
        background.setFill(); dirtyRect.fill()
        guard let buffer = session?.buffer else { return }
        let lines = buffer.allLines
        let first = max(0, Int((dirtyRect.minY - 8) / cellHeight))
        let last = min(lines.count, Int(dirtyRect.maxY / cellHeight) + 1)
        if first < last {
            for line in first..<last {
                for (column, cell) in lines[line].enumerated() {
                    let rect = NSRect(x: 10 + CGFloat(column) * cellWidth, y: 8 + CGFloat(line) * cellHeight,
                                      width: cellWidth, height: cellHeight)
                    guard dirtyRect.intersects(rect) else { continue }
                    let selected = isSelected(line: line, column: column)
                    let fg = color(cell.inverse ? cell.background : cell.foreground, fallback: cell.inverse ? background : foreground)
                    let bg = color(cell.inverse ? cell.foreground : cell.background, fallback: cell.inverse ? foreground : background)
                    if selected { Theme.terminalAccentColor.withAlphaComponent(0.25).setFill(); rect.fill() }
                    else if cell.background != -1 || cell.inverse { bg.setFill(); rect.fill() }
                    if !cell.continuation && cell.text != " " {
                        (cell.displayText as NSString).draw(at: NSPoint(x: rect.minX, y: rect.minY + 2),
                            withAttributes: [.font: cell.bold ? boldFont : font, .foregroundColor: fg])
                    }
                }
            }
        }
        if buffer.cursorVisible && window?.firstResponder === self {
            let rect = cursorRect()
            Theme.terminalAccentColor.withAlphaComponent(0.75).setFill(); rect.fill()
        }
        if !markedText.isEmpty {
            let rect = cursorRect()
            (markedText as NSString).draw(at: NSPoint(x: rect.minX, y: rect.minY + 2),
                withAttributes: [.font: font, .foregroundColor: foreground, .backgroundColor: background, .underlineStyle: NSUnderlineStyle.single.rawValue])
        }
    }

    override func becomeFirstResponder() -> Bool { needsDisplay = true; return true }
    override func resignFirstResponder() -> Bool { unmarkText(); needsDisplay = true; return true }

    // NSScrollView owns wheel dispatch. It calls this before scrolling local history.
    func handleScrollWheel(_ event: NSEvent) -> Bool {
        guard let session else { return false }
        let buffer = session.buffer
        let mode = buffer.mouseTrackingMode + (buffer.alternateScreen ? 10_000 : 0)
            + (buffer.sgrMouse ? 20_000 : 0) + (buffer.alternateScroll ? 40_000 : 0)
        if mode != wheelMode || event.phase.contains(.began) {
            wheelRemainder = 0; wheelMode = mode
        }
        // Shift keeps the ordinary terminal-history gesture available to the user.
        guard buffer.handlesScrollInput, !event.modifierFlags.contains(.shift) else {
            wheelRemainder = 0
            return false
        }
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / cellHeight : event.scrollingDeltaY
        guard delta.isFinite else { wheelRemainder = 0; return true }
        if delta == 0 { return true }
        if delta * wheelRemainder < 0 { wheelRemainder = 0 }
        wheelRemainder = min(30, max(-30, wheelRemainder + delta))
        let steps = Int(abs(wheelRemainder))
        guard steps > 0 else { return true }
        let up = wheelRemainder > 0
        wheelRemainder -= CGFloat(steps) * (up ? 1 : -1)
        let point = position(for: event)
        let row = point.line - (buffer.alternateScreen ? 0 : buffer.scrollback.count)
        var modifiers = 0
        if event.modifierFlags.contains(.option) { modifiers |= 8 }
        if event.modifierFlags.contains(.control) { modifiers |= 16 }
        if let input = buffer.scrollInput(up: up, column: point.column, row: row, modifiers: modifiers) {
            session.send(Array(repeating: input, count: steps).flatMap { $0 })
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard let session else { return }
        selectionStart = nil; selectionEnd = nil
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command) { super.keyDown(with: event); return }
        if modifiers.contains(.control), let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first {
            if scalar.value >= 64 && scalar.value <= 127 { session.send([UInt8(scalar.value & 0x1f)]); return }
            if scalar.value == 32 { session.send([0]); return }
        }
        let prefix = session.buffer.applicationCursor ? "\u{1b}O" : "\u{1b}["
        let sequence: String?
        switch event.keyCode {
        case 123: sequence = prefix + "D"
        case 124: sequence = prefix + "C"
        case 125: sequence = prefix + "B"
        case 126: sequence = prefix + "A"
        case 115: sequence = "\u{1b}[H"
        case 119: sequence = "\u{1b}[F"
        case 116: sequence = "\u{1b}[5~"
        case 121: sequence = "\u{1b}[6~"
        case 117: sequence = "\u{1b}[3~"
        case 53: sequence = "\u{1b}"
        case 48: sequence = modifiers.contains(.shift) ? "\u{1b}[Z" : "\t"
        case 36, 76: sequence = hasMarkedText() ? nil : "\r"
        case 51: sequence = hasMarkedText() ? nil : "\u{7f}"
        default: sequence = nil
        }
        if let sequence { session.send(sequence) }
        else { interpretKeyEvents([event]) }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        selectionStart = position(for: event); selectionEnd = selectionStart
        if event.clickCount == 2, let point = selectionStart, let lines = session?.buffer.allLines,
           lines.indices.contains(point.line) {
            let line = lines[point.line]
            var lower = min(point.column, line.count - 1), upper = lower
            while lower > 0 && line[lower - 1].text != " " { lower -= 1 }
            while upper + 1 < line.count && line[upper + 1].text != " " { upper += 1 }
            selectionStart = (point.line, lower); selectionEnd = (point.line, upper)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        selectionEnd = position(for: event)
        autoscroll(with: event)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 1, let start = selectionStart, let end = selectionEnd,
           start.line == end.line && start.column == end.column { selectionStart = nil; selectionEnd = nil }
        needsDisplay = true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let copy = NSMenuItem(title: "복사", action: #selector(copy(_:)), keyEquivalent: "")
        copy.target = self; menu.addItem(copy)
        let paste = NSMenuItem(title: "붙여넣기", action: #selector(paste(_:)), keyEquivalent: "")
        paste.target = self; menu.addItem(paste)
        return menu
    }

    @objc func copy(_ sender: Any?) {
        guard let start = selectionStart, let end = selectionEnd, let buffer = session?.buffer else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(buffer.text(from: start, to: end), forType: .string)
    }

    @objc func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string), let session else { return }
        if session.buffer.bracketedPaste { session.send("\u{1b}[200~" + text + "\u{1b}[201~") }
        else { session.send(text) }
    }

    override func selectAll(_ sender: Any?) {
        guard let buffer = session?.buffer else { return }
        selectionStart = (0, 0); selectionEnd = (buffer.allLines.count - 1, buffer.columns - 1)
        needsDisplay = true
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        let text = (string as? NSAttributedString)?.string ?? (string as? String ?? "")
        session?.send(text); unmarkText()
    }
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        markedText = (string as? NSAttributedString)?.string ?? (string as? String ?? "")
        needsDisplay = true
    }
    func unmarkText() { markedText = ""; needsDisplay = true }
    func hasMarkedText() -> Bool { !markedText.isEmpty }
    func markedRange() -> NSRange { hasMarkedText() ? NSRange(location: 0, length: markedText.utf16.count) : NSRange(location: NSNotFound, length: 0) }
    func selectedRange() -> NSRange { NSRange(location: 0, length: 0) }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [.underlineStyle, .foregroundColor] }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? { nil }
    func characterIndex(for point: NSPoint) -> Int { NSNotFound }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let window else { return .zero }
        return window.convertToScreen(convert(cursorRect(), to: nil))
    }
    override func doCommand(by selector: Selector) {
        if selector == #selector(NSResponder.insertNewline(_:)) { session?.send("\r") }
        else if selector == #selector(NSResponder.deleteBackward(_:)) { session?.send([127]) }
        else if selector == #selector(NSResponder.insertTab(_:)) { session?.send("\t") }
    }

    private func cursorRect() -> NSRect {
        guard let buffer = session?.buffer else { return .zero }
        return NSRect(x: 10 + CGFloat(buffer.cursorX) * cellWidth, y: 8 + CGFloat(buffer.cursorLine) * cellHeight,
                      width: cellWidth, height: cellHeight)
    }

    private func position(for event: NSEvent) -> (line: Int, column: Int) {
        let point = convert(event.locationInWindow, from: nil)
        let buffer = session?.buffer
        return (min(max(0, Int((point.y - 8) / cellHeight)), max(0, (buffer?.allLines.count ?? 1) - 1)),
                min(max(0, Int((point.x - 10) / cellWidth)), (buffer?.columns ?? 80) - 1))
    }

    private func isSelected(line: Int, column: Int) -> Bool {
        guard let start = selectionStart, let end = selectionEnd else { return false }
        let a = (start.line, start.column), b = (end.line, end.column), point = (line, column)
        return point >= (a <= b ? a : b) && point <= (a <= b ? b : a)
    }

    private func color(_ index: Int, fallback: NSColor) -> NSColor {
        if index < 0 { return fallback }
        if index & 0x1000000 != 0 {
            return NSColor(srgbRed: CGFloat((index >> 16) & 255) / 255,
                green: CGFloat((index >> 8) & 255) / 255, blue: CGFloat(index & 255) / 255, alpha: 1)
        }
        if index < 16 { return palette[index] }
        if index < 232 {
            let value = index - 16
            let levels: [CGFloat] = [0, 95, 135, 175, 215, 255]
            return NSColor(srgbRed: levels[value / 36] / 255, green: levels[(value / 6) % 6] / 255,
                           blue: levels[value % 6] / 255, alpha: 1)
        }
        return NSColor(white: CGFloat(min(255, 8 + (index - 232) * 10)) / 255, alpha: 1)
    }
}
