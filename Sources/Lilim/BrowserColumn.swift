import Foundation

struct BrowserColumn: Identifiable, Sendable {
    let directory: URL
    var entries: [FileEntry] = []
    var isLoading = true
    var error: String?
    var id: String { directory.path }
}
