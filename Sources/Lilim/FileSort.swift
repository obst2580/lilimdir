import Foundation

enum FileSort: String, CaseIterable, Identifiable {
    case name, kind, modified, created, size
    var id: String { rawValue }
    var title: String {
        switch self {
        case .name: "이름"
        case .kind: "종류"
        case .modified: "수정일"
        case .created: "생성일"
        case .size: "크기"
        }
    }

    func compare(_ a: FileEntry, _ b: FileEntry) -> ComparisonResult {
        switch self {
        case .name: return a.name.localizedStandardCompare(b.name)
        case .kind: return a.kind.localizedStandardCompare(b.kind)
        case .modified: return compareValues(a.modifiedAt ?? .distantPast, b.modifiedAt ?? .distantPast)
        case .created: return compareValues(a.createdAt ?? .distantPast, b.createdAt ?? .distantPast)
        case .size: return compareValues(a.size, b.size)
        }
    }
    private func compareValues<T: Comparable>(_ a: T, _ b: T) -> ComparisonResult {
        a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
    }
}
