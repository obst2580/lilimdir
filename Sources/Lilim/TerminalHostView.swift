import AppKit
import SwiftUI

@MainActor
final class TerminalHostView: NSView {
    let canvas: TerminalCanvasView
    private let scrollView = TerminalScrollView()
    private weak var session: TerminalSession?

    init(session: TerminalSession) {
        self.session = session
        canvas = TerminalCanvasView(session: session)
        super.init(frame: .zero)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = canvas
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
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
