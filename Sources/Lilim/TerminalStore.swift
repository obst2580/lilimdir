import Foundation
import Observation

@MainActor @Observable
final class TerminalStore {
    var sessions: [TerminalSession] = []
    var selectedID: UUID?
    var pendingClose: UUID?
    var active: TerminalSession? { sessions.first { $0.id == selectedID } }

    func navigate(directory: URL) {
        if let active { active.changeDirectory(to: directory) }
        else { newSession(directory: directory) }
    }

    func newSession(directory: URL) {
        let session = TerminalSession(directory: directory)
        sessions.append(session)
        selectedID = session.id
    }

    func close(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].terminate()
        sessions.remove(at: index)
        if selectedID == id { selectedID = sessions.isEmpty ? nil : sessions[min(index, sessions.count - 1)].id }
        pendingClose = nil
    }

    func terminateAll() { sessions.forEach { $0.terminate() } }
}
