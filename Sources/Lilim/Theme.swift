import SwiftUI

@MainActor
enum Theme {
    // Jade palette derived from OKLCH, hue 184°: readable teal in light UI,
    // softer mint in dark UI. Native appearance also covers increased contrast.
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            return NSColor(srgbRed: 109 / 255, green: 211 / 255, blue: 192 / 255, alpha: 1)
        }
        return NSColor(srgbRed: 17 / 255, green: 124 / 255, blue: 114 / 255, alpha: 1)
    })
    static let terminalAccentColor = NSColor(srgbRed: 109 / 255, green: 211 / 255, blue: 192 / 255, alpha: 1)
    static let terminalBackgroundColor = NSColor(srgbRed: 19 / 255, green: 27 / 255, blue: 26 / 255, alpha: 1)
    static let terminalTextColor = NSColor(srgbRed: 219 / 255, green: 236 / 255, blue: 233 / 255, alpha: 1)
    static let terminalAccent = Color(nsColor: terminalAccentColor)
    static let terminal = Color(nsColor: terminalBackgroundColor)
    static let terminalSecondary = Color(red: 27 / 255, green: 37 / 255, blue: 36 / 255)
    static let terminalText = Color(nsColor: terminalTextColor)
}
