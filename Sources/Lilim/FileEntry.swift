import Foundation

struct FileEntry: Identifiable, Hashable, Sendable {
    let url: URL
    let isDirectory: Bool
    let isPackage: Bool
    let isSymbolicLink: Bool
    let size: Int64
    let modifiedAt: Date?
    var createdAt: Date? = nil
    var kind = ""
    var tags: [String] = []
    var labelNumber = 0
    var isAlias = false
    var aliasTarget: URL? = nil
    var aliasTargetIsDirectory = false

    var id: String { url.path }
    var name: String { url.lastPathComponent }
    var isNavigable: Bool { (isDirectory || aliasTargetIsDirectory) && !isPackage }
    var navigationURL: URL { aliasTarget ?? url }
    var symbol: String {
        if isNavigable { return "folder.fill" }
        if isPackage { return "app.fill" }
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg": return "photo"
        case "swift", "js", "ts", "tsx", "jsx", "py", "rs", "go", "html", "css", "sh": return "chevron.left.forwardslash.chevron.right"
        case "pdf": return "doc.richtext"
        case "zip", "gz", "tar", "dmg": return "archivebox"
        case "mp4", "mov": return "film"
        case "mp3", "wav", "m4a": return "music.note"
        default: return "doc.text"
        }
    }
    var sizeLabel: String {
        isNavigable ? "폴더" : ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
