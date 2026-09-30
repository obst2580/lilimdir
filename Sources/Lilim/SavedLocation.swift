import Foundation

struct SavedLocation: Identifiable, Codable, Hashable {
    let path: String
    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent.isEmpty ? "Macintosh HD" : url.lastPathComponent }
}
