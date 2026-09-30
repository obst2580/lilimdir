import Foundation

enum FileConflictPolicy: String, Sendable {
    case keepBoth, replace, skip, abort
}

enum FileTransferMode: Sendable { case copy, move }

enum FileStep: Sendable {
    case move(URL, URL)
    case trash(URL)
    case tags(URL, FileTagSnapshot)
    case permissions(URL, Int)
    case locked(URL, Bool)
}

struct FileOperationRecord: Sendable {
    let title: String
    var steps: [FileStep]
}

struct FileOperationResult: Sendable {
    var affected: [URL] = []
    var inverse: [FileStep] = []
    var remaining: [FileStep] = []
    var issues: [String] = []
    var relocations: [(from: URL, to: URL)] = []
}

enum FileOperationError: LocalizedError {
    case invalidName, selfTransfer, missing(URL), collision(URL)
    var errorDescription: String? {
        switch self {
        case .invalidName: "이름은 비워 둘 수 없으며 /, 줄바꿈, . 또는 ..을 사용할 수 없습니다."
        case .selfTransfer: "폴더를 자기 자신이나 그 하위 폴더로 복사·이동할 수 없습니다."
        case .missing(let url): "항목을 찾을 수 없습니다: \(url.path)"
        case .collision(let url): "같은 이름의 항목이 있습니다: \(url.path)"
        }
    }
}
