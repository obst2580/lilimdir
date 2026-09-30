import AppKit
import SwiftUI
import QuickLookUI

@MainActor
final class ExplorerKeyboardView: NSView, NSUserInterfaceValidations {
    private weak var browser: BrowserState?
    private var typedPrefix = ""
    private var lastTyped = Date.distantPast
    init(browser: BrowserState) {
        self.browser = browser
        super.init(frame: .zero)
        setAccessibilityElement(false)
    }
    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { browser?.filesFocused = true; return true }
    override func resignFirstResponder() -> Bool { browser?.filesFocused = false; return true }

    override func keyDown(with event: NSEvent) {
        guard let browser else { return }
        let shift = event.modifierFlags.contains(.shift)
        if event.modifierFlags.contains(.command) { super.keyDown(with: event); return }
        switch event.keyCode {
        case 125: browser.selectRelative(1, extend: shift)
        case 126: browser.selectRelative(-1, extend: shift)
        case 124:
            if let entry = browser.selection, entry.isNavigable {
                browser.open(entry, fromColumn: browser.keyboardColumn); browser.focusFiles()
            }
        case 123: browser.goUp(); browser.focusFiles()
        case 36, 76: browser.beginRename()
        case 49: browser.previewItems()
        case 53: browser.selectedEntries = []; browser.clearSearch()
        case 115, 119:
            if let entry = event.keyCode == 115 ? browser.keyboardEntries.first : browser.keyboardEntries.last {
                browser.select(entry, column: browser.keyboardColumn, navigateFolder: false)
            }
        default:
            guard let text = event.characters, !text.isEmpty,
                  text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return }
            if Date().timeIntervalSince(lastTyped) > 1 { typedPrefix = "" }
            typedPrefix += text; lastTyped = Date()
            if let entry = browser.keyboardEntries.first(where: { $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .hasPrefix(typedPrefix.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)) }) {
                browser.select(entry, column: browser.keyboardColumn, navigateFolder: false)
            }
        }
    }

    @objc func copy(_ sender: Any?) { browser?.copyItems() }
    @objc func cut(_ sender: Any?) { browser?.copyItems(cut: true) }
    @objc func paste(_ sender: Any?) { browser?.pasteFiles() }
    override func selectAll(_ sender: Any?) { browser?.selectAllFiles() }
    @objc func undo(_ sender: Any?) { browser?.undoFiles() }
    @objc func redo(_ sender: Any?) { browser?.redoFiles() }

    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        guard let browser else { return false }
        switch item.action {
        case #selector(copy(_:)), #selector(cut(_:)): return !browser.selectedEntries.isEmpty && !browser.isWorking
        case #selector(paste(_:)): return !browser.isWorking && !FileClipboard.read().isEmpty
        case #selector(undo(_:)): return browser.operations.canUndo
        case #selector(redo(_:)): return browser.operations.canRedo
        default: return true
        }
    }

    nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { browser?.previews.takeControl(panel) }
    }
    nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated { browser?.previews.endControl(panel) }
    }
}

struct ExplorerKeyboardBridge: NSViewRepresentable {
    let browser: BrowserState
    func makeNSView(context: Context) -> ExplorerKeyboardView {
        let view = ExplorerKeyboardView(browser: browser)
        browser.keyboardView = view
        return view
    }
    func updateNSView(_ view: ExplorerKeyboardView, context: Context) { }
}
