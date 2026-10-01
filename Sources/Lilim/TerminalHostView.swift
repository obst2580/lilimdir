import AppKit
import SwiftUI

@MainActor
final class TerminalHostView: NSView {
    let canvas: TerminalCanvasView
    private let scrollView = TerminalScrollView()
    private let applicationScrollControls = TerminalApplicationScrollControls()
    private weak var session: TerminalSession?
    private var applicationScrolling = false

    init(session: TerminalSession) {
        self.session = session
        canvas = TerminalCanvasView(session: session)
        super.init(frame: .zero)
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .legacy
        scrollView.verticalScroller = TerminalHistoryScroller()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.documentView = canvas
        addSubview(scrollView)
        applicationScrollControls.isHidden = true
        applicationScrollControls.scroll = { [weak self] up in
            guard let self, let session = self.session else { return }
            canvas.scrollApplication(up: up, steps: 3, column: session.buffer.columns / 2, row: session.buffer.rows / 2)
            session.focus()
        }
        addSubview(applicationScrollControls)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        updateScrollMode()
        layoutScrollViews()
        guard bounds.width > 30, bounds.height > 30, let session else { return }
        canvas.updateFont(size: session.fontSize)
        let viewport = scrollView.contentView.bounds.size
        let columns = max(10, Int((viewport.width - 20) / canvas.cellWidth))
        let rows = max(3, Int((viewport.height - 16) / canvas.cellHeight))
        session.resize(columns: columns, rows: rows)
        refresh()
        session.startIfNeeded()
    }

    func refresh() {
        guard let session else { return }
        updateScrollMode()
        let visible = scrollView.contentView.bounds
        let followOutput = session.buffer.alternateScreen || visible.maxY >= canvas.bounds.height - canvas.cellHeight * 2
        let height = max(scrollView.contentView.bounds.height, CGFloat(session.buffer.allLines.count) * canvas.cellHeight + 16)
        canvas.frame = NSRect(x: 0, y: 0, width: scrollView.contentView.bounds.width, height: height)
        canvas.needsDisplay = true
        canvas.setAccessibilityLabel("터미널. \(session.currentDirectory.path)")
        canvas.setAccessibilityValue(session.buffer.text(from: (max(0, session.buffer.allLines.count - 40), 0),
                                                        to: (session.buffer.allLines.count - 1, session.buffer.columns - 1)))
        if followOutput { canvas.scroll(NSPoint(x: 0, y: max(0, height - visible.height))) }
    }

    private func updateScrollMode() {
        guard let session else { return }
        let active = session.buffer.handlesScrollInput
        guard active != applicationScrolling else { return }
        applicationScrolling = active
        session.applicationScrollActive = active
        // Both rails take the same width, so entering a TUI does not resize its PTY.
        scrollView.hasVerticalScroller = !active
        applicationScrollControls.isHidden = !active
        layoutScrollViews()
    }

    private func layoutScrollViews() {
        let width = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
        scrollView.frame = NSRect(x: 0, y: 0, width: max(0, bounds.width - (applicationScrolling ? width : 0)), height: bounds.height)
        applicationScrollControls.frame = NSRect(x: max(0, bounds.width - width), y: 0, width: width, height: bounds.height)
    }
}

@MainActor
final class TerminalHistoryScroller: NSScroller {
    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        Theme.terminalBackgroundColor.blended(withFraction: 0.12, of: Theme.terminalAccentColor)?.setFill()
        slotRect.fill()
    }

    override func drawKnob() {
        Theme.terminalAccentColor.withAlphaComponent(isEnabled ? 0.75 : 0.2).setFill()
        let knob = rect(for: .knob)
        let visibleKnob = NSRect(x: 4, y: knob.minY + 1, width: max(0, bounds.width - 8), height: max(0, knob.height - 2))
        NSBezierPath(roundedRect: visibleKnob, xRadius: 4, yRadius: 4).fill()
    }
}

// Mouse protocols transmit scrolling, but do not report the application's history
// length or offset. Show directional controls here, never a fabricated position.
@MainActor
final class TerminalApplicationScrollControls: NSView {
    var scroll: ((Bool) -> Void)?
    private let up = NSButton()
    private let down = NSButton()
    private let indicator = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        clipsToBounds = true
        for (button, symbol, title, action) in [
            (up, "chevron.up", "프로그램 기록 위로 스크롤", #selector(scrollUp)),
            (down, "chevron.down", "프로그램 기록 아래로 스크롤", #selector(scrollDown))
        ] {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            button.imagePosition = .imageOnly
            button.isBordered = false
            button.contentTintColor = Theme.terminalAccentColor
            button.target = self
            button.action = action
            button.isContinuous = true
            button.setPeriodicDelay(0.35, interval: 0.08)
            button.setAccessibilityLabel(title)
            button.toolTip = title + " · 길게 누르면 계속 이동"
            addSubview(button)
        }
        indicator.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "프로그램 내부 스크롤")
        indicator.contentTintColor = Theme.terminalAccentColor
        indicator.toolTip = "프로그램 내부 스크롤입니다. 전체 기록 길이와 현재 위치를 제공하지 않아 위치 막대를 표시할 수 없습니다."
        addSubview(indicator)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let height = min(28, bounds.height / 2)
        up.frame = NSRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
        down.frame = NSRect(x: 0, y: 0, width: bounds.width, height: height)
        indicator.frame = NSRect(x: 2, y: max(0, (bounds.height - 20) / 2), width: max(0, bounds.width - 4), height: 20)
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.terminalBackgroundColor.blended(withFraction: 0.12, of: Theme.terminalAccentColor)?.setFill()
        bounds.intersection(dirtyRect).fill()
    }

    @objc private func scrollUp() { scroll?(true) }
    @objc private func scrollDown() { scroll?(false) }
}

@MainActor
final class TerminalScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        if let canvas = documentView as? TerminalCanvasView, canvas.handleScrollWheel(event) { return }
        super.scrollWheel(with: event)
    }
}

struct TerminalSurface: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> TerminalHostView { session.hostView }
    func updateNSView(_ nsView: TerminalHostView, context: Context) {
        nsView.needsLayout = true
    }
}
