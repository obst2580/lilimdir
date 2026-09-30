import Foundation

@MainActor
final class DirectoryWatcher {
    private var source: (any DispatchSourceFileSystemObject)?

    init(directory: URL, onChange: @escaping @MainActor @Sendable () -> Void) {
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main
        )
        source.setEventHandler { MainActor.assumeIsolated { onChange() } }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    func stop() { source?.cancel(); source = nil }

    isolated deinit { source?.cancel() }
}
