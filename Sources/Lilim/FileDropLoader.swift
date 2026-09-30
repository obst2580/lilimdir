import AppKit
import UniformTypeIdentifiers

@MainActor
final class FileDropLoader {
    let browser: BrowserState
    let destination: URL
    let modifiers: NSEvent.ModifierFlags
    private var pending = 0
    private var urls: [URL] = []
    init(browser: BrowserState, destination: URL, modifiers: NSEvent.ModifierFlags) {
        self.browser = browser; self.destination = destination; self.modifiers = modifiers
    }
    func load(_ providers: [NSItemProvider]) {
        let readable = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        pending = readable.count
        for provider in readable {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                let url = data.flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                Task { @MainActor in
                    if let url, url.isFileURL { self.urls.append(url) }
                    self.pending -= 1
                    if self.pending == 0 { self.browser.receiveURLs(self.urls, into: self.destination, modifiers: self.modifiers) }
                }
            }
        }
    }
}

extension BrowserState {
    func receiveDrop(_ providers: [NSItemProvider], into directory: URL) -> Bool {
        guard !isWorking else { return false }
        FileDropLoader(browser: self, destination: directory, modifiers: NSEvent.modifierFlags).load(providers)
        return true
    }
    func receiveURLs(_ urls: [URL], into directory: URL, modifiers: NSEvent.ModifierFlags) {
        guard !urls.isEmpty else { return }
        transfer(urls, to: directory, move: wantsMoveForDrop(urls, into: directory, modifiers: modifiers))
    }
    func wantsMoveForDrop(_ urls: [URL], into directory: URL, modifiers: NSEvent.ModifierFlags) -> Bool {
        let targetVolume = (try? directory.resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier as? NSObject
        let sameVolume = urls.allSatisfy { url in
            let volume = (try? url.resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier as? NSObject
            return volume != nil && volume == targetVolume
        }
        return modifiers.contains(.option) ? false : (modifiers.contains(.command) || sameVolume)
    }
}
