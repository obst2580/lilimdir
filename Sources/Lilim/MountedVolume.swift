import Foundation

struct MountedVolume: Identifiable, Sendable {
    let url: URL
    let name: String
    let ejectable: Bool
    let local: Bool
    var id: String { url.path }
}
