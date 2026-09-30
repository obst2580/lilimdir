import Foundation
import Observation

@MainActor @Observable
final class FileOperations {
    let service = FileOperationService()
    var isBusy = false
    var activity = ""
    var undoStack: [FileOperationRecord] = []
    var redoStack: [FileOperationRecord] = []
    @ObservationIgnored private var task: Task<Void, Never>?
    var canUndo: Bool { !isBusy && !undoStack.isEmpty }
    var canRedo: Bool { !isBusy && !redoStack.isEmpty }

    func perform(_ title: String, action: @escaping @Sendable (FileOperationService) async -> FileOperationResult,
                 completion: @escaping @MainActor (FileOperationResult) -> Void) {
        guard !isBusy else { return }
        isBusy = true; activity = title
        task = Task {
            let result = await action(service)
            if !result.inverse.isEmpty {
                undoStack.append(FileOperationRecord(title: title, steps: result.inverse))
                redoStack = []
            }
            isBusy = false; activity = ""; task = nil
            completion(result)
        }
    }

    func undo(completion: @escaping @MainActor (FileOperationResult) -> Void) {
        guard canUndo, let record = undoStack.popLast() else { return }
        replay(record, undo: true, completion: completion)
    }

    func redo(completion: @escaping @MainActor (FileOperationResult) -> Void) {
        guard canRedo, let record = redoStack.popLast() else { return }
        replay(record, undo: false, completion: completion)
    }

    private func replay(_ record: FileOperationRecord, undo: Bool, completion: @escaping @MainActor (FileOperationResult) -> Void) {
        isBusy = true; activity = record.title + (undo ? " 실행 취소" : " 다시 실행")
        task = Task {
            let result = await service.apply(record.steps)
            if !result.remaining.isEmpty {
                let remaining = FileOperationRecord(title: record.title, steps: result.remaining)
                if undo { undoStack.append(remaining) } else { redoStack.append(remaining) }
            }
            if !result.inverse.isEmpty {
                let inverse = FileOperationRecord(title: record.title, steps: result.inverse)
                if undo { redoStack.append(inverse) } else { undoStack.append(inverse) }
            }
            isBusy = false; activity = ""; task = nil
            completion(result)
        }
    }

    func cancel() { task?.cancel() }
}
