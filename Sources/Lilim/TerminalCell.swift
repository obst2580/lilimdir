import Foundation

struct TerminalCell: Equatable {
    var text = " "
    var foreground = -1
    var background = -1
    var bold = false
    var inverse = false
    var continuation = false

    // Draw one composed glyph while retaining the received text for selection/copy.
    var displayText: String { text.precomposedStringWithCanonicalMapping }
}
