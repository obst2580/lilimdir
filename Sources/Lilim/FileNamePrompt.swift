import Foundation

struct FileNamePrompt: Identifiable, Sendable {
    enum Kind: Sendable { case folder, text, rename(URL), folderWithItems([URL]) }
    let id = UUID()
    let title: String
    let kind: Kind
    let directory: URL
}

struct FileInfoSelection: Identifiable {
    let id = UUID()
    let entries: [FileEntry]
}
