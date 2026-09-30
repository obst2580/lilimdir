import Foundation

enum BatchRenameMode: String, CaseIterable, Identifiable {
    case replace, prefix, suffix, numbered
    var id: String { rawValue }
    var title: String {
        switch self {
        case .replace: "텍스트 대치"
        case .prefix: "이름 앞에 추가"
        case .suffix: "이름 뒤에 추가"
        case .numbered: "이름과 번호"
        }
    }
    func name(for entry: FileEntry, index: Int, text: String, replacement: String, start: Int) -> String {
        let ext = entry.isDirectory && !entry.isPackage ? "" : entry.url.pathExtension
        let stem = ext.isEmpty ? entry.name : entry.url.deletingPathExtension().lastPathComponent
        let tail = ext.isEmpty ? "" : "." + ext
        switch self {
        case .replace: return text.isEmpty ? entry.name : entry.name.replacingOccurrences(of: text, with: replacement)
        case .prefix: return text + entry.name
        case .suffix: return stem + text + tail
        case .numbered: return text + " \(max(0, start) + index)" + tail
        }
    }
}
