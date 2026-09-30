import AppKit
import SwiftUI

@MainActor
final class FileRowHostView: NSView, NSDraggingSource {
    var entry: FileEntry
    var column: Int?
    weak var browser: BrowserState?
    weak var terminals: TerminalStore?
    private var downPoint = NSPoint.zero
    private var dragging = false
    private var downModifiers: NSEvent.ModifierFlags = []
    private let content: NSHostingView<FileRowView>
    var rootView: FileRowView {
        get { content.rootView }
        set { content.rootView = newValue }
    }
    override var isFlipped: Bool { true }

    init(entry: FileEntry, column: Int?, browser: BrowserState, terminals: TerminalStore, content: FileRowView) {
        self.entry = entry; self.column = column; self.browser = browser; self.terminals = terminals
        self.content = NSHostingView(rootView: content)
        super.init(frame: .zero)
        addSubview(self.content)
        registerForDraggedTypes([.fileURL])
        setAccessibilityElement(true); setAccessibilityRole(.button)
        setAccessibilityLabel(entry.name); setAccessibilityHelp(entry.url.path)
    }
    @MainActor required init?(coder: NSCoder) { nil }
    override func layout() { super.layout(); content.frame = bounds }
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(convert(point, from: superview)) ? self : nil }
    override func mouseDown(with event: NSEvent) {
        downPoint = event.locationInWindow; dragging = false
        downModifiers = event.modifierFlags
        if event.modifierFlags.intersection([.command, .shift]).isEmpty,
           browser?.selectedEntries.contains(where: { $0.id == entry.id }) == true { browser?.focusFiles() }
        else { browser?.select(entry, column: column, modifiers: event.modifierFlags, navigateFolder: false) }
        if event.clickCount == 2 { browser?.open(entry, fromColumn: column) }
    }
    override func mouseUp(with event: NSEvent) {
        if !dragging && downModifiers.intersection([.command, .shift]).isEmpty {
            browser?.select(entry, column: column)
        }
    }
    override func mouseDragged(with event: NSEvent) {
        guard !dragging, let browser,
              hypot(event.locationInWindow.x - downPoint.x, event.locationInWindow.y - downPoint.y) > 4 else { return }
        dragging = true
        let items = browser.contextItems(entry).enumerated().map { index, item in
            let dragged = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: item.url.path)
            let point = convert(event.locationInWindow, from: nil)
            dragged.setDraggingFrame(NSRect(x: point.x + CGFloat(index * 4), y: point.y - 16, width: 32, height: 32), contents: icon)
            return dragged
        }
        beginDraggingSession(with: items, event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { [.copy, .move] }
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let browser, let terminals else { return nil }
        if !browser.selectedEntries.contains(where: { $0.id == entry.id }) { browser.select(entry, column: column, navigateFolder: false) }
        else { browser.focusFiles() }
        return FileContextMenu.make(entry: entry, browser: browser, terminals: terminals)
    }
    override func accessibilityPerformPress() -> Bool {
        browser?.select(entry, column: column); return true
    }
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard entry.isNavigable, browser?.isWorking == false else { return [] }
        let urls = FileClipboard.read(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return [] }
        if !sender.draggingSourceOperationMask.contains(.move) || NSEvent.modifierFlags.contains(.option) { return .copy }
        return browser?.wantsMoveForDrop(urls, into: entry.navigationURL, modifiers: NSEvent.modifierFlags) == true ? .move : .copy
    }
    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard entry.isNavigable, let browser else { return false }
        let urls = FileClipboard.read(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        let modifiers = sender.draggingSourceOperationMask.contains(.move) ? NSEvent.modifierFlags : NSEvent.modifierFlags.union(.option)
        browser.receiveURLs(urls, into: entry.navigationURL, modifiers: modifiers)
        return true
    }
}

struct FileRowSurface: NSViewRepresentable {
    let entry: FileEntry
    let column: Int?
    let browser: BrowserState
    let terminals: TerminalStore
    let selected: Bool
    var details = false
    var detail: String?
    var iconMode = false
    func makeNSView(context: Context) -> FileRowHostView {
        FileRowHostView(entry: entry, column: column, browser: browser, terminals: terminals,
                        content: FileRowView(entry: entry, selected: selected, showDetails: details, detail: detail, iconMode: iconMode))
    }
    func updateNSView(_ view: FileRowHostView, context: Context) {
        view.entry = entry; view.column = column
        view.rootView = FileRowView(entry: entry, selected: selected, showDetails: details, detail: detail, iconMode: iconMode)
        view.setAccessibilityLabel(entry.name)
        view.setAccessibilityHelp(entry.url.path)
        view.setAccessibilitySelected(selected)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: FileRowHostView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 220, height: iconMode ? 100 : (detail == nil ? 30 : 46))
    }
}
