import AppKit
import QuickLookUI
import SwiftUI

@MainActor
final class FilePreviewController: NSObject, @preconcurrency QLPreviewPanelDataSource {
    private var urls: [URL] = []
    func toggle(_ urls: [URL]) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible { panel.orderOut(nil); return }
        self.urls = urls
        panel.updateController()
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }
    func update(_ urls: [URL]) {
        guard QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
        self.urls = urls; panel.reloadData()
    }
    func takeControl(_ panel: QLPreviewPanel) { panel.dataSource = self }
    func endControl(_ panel: QLPreviewPanel) { panel.dataSource = nil }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { urls.count }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        urls.indices.contains(index) ? urls[index] as NSURL : nil
    }
}

struct FilePreviewView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .compact)!
        view.shouldCloseWithWindow = false
        view.previewItem = url as NSURL
        return view
    }
    func updateNSView(_ view: QLPreviewView, context: Context) {
        if view.previewItem?.previewItemURL != url { view.previewItem = url as NSURL }
    }
    static func dismantleNSView(_ view: QLPreviewView, coordinator: ()) { view.close() }
}
