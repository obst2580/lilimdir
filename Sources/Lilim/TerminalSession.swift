import AppKit
import Observation

@MainActor @Observable
final class TerminalSession: Identifiable {
    let id = UUID()
    let initialDirectory: URL
    var currentDirectory: URL
    var title: String
    var isRunning = false
    var exitMessage: String?
    var pendingDirectory: URL?
    var navigationError: String?
    var fontSize: CGFloat = 13
    var applicationScrollActive = false
    @ObservationIgnored let buffer = TerminalBuffer()
    @ObservationIgnored private let process = PTYProcess()
    @ObservationIgnored private var didStart = false
    @ObservationIgnored private var refreshScheduled = false
    @ObservationIgnored private var directoryChangeSentAt: Date?
    @ObservationIgnored lazy var hostView = TerminalHostView(session: self)

    init(directory: URL) {
        initialDirectory = directory
        currentDirectory = directory
        title = directory.lastPathComponent
        buffer.titleChanged = { [weak self] title in self?.title = title }
        buffer.directoryChanged = { [weak self] value in
            if let url = URL(string: value), url.isFileURL { self?.currentDirectory = url }
        }
        buffer.respond = { [weak self] bytes in self?.process.send(bytes) }
        process.onData = { [weak self] bytes in
            guard let self else { return }
            buffer.feed(bytes)
            scheduleRefresh()
        }
        process.onExit = { [weak self] status in
            guard let self else { return }
            isRunning = false
            pendingDirectory = nil
            directoryChangeSentAt = nil
            let code = (status >> 8) & 0xff
            exitMessage = code == 126 ? "폴더에 접근할 수 없습니다." : (code == 127 ? "셸을 실행할 수 없습니다." : "세션 종료 · \(code)")
            buffer.feed(Array("\r\n\u{1b}[90m[\(exitMessage ?? "세션 종료")]\u{1b}[0m\r\n".utf8))
            hostView.refresh()
        }
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        do {
            try process.start(directory: currentDirectory, columns: buffer.columns, rows: buffer.rows)
            isRunning = true
        } catch {
            exitMessage = "셸을 실행할 수 없습니다: \(error.localizedDescription)"
            buffer.feed(Array((exitMessage ?? "").utf8))
            hostView.refresh()
        }
    }

    func send(_ text: String) { process.send(Array(text.utf8)) }
    func send(_ bytes: [UInt8]) { process.send(bytes) }
    func terminate() { process.terminate(); isRunning = false }
    func focus() { hostView.window?.makeFirstResponder(hostView.canvas) }

    func changeDirectory(to directory: URL) {
        let target = URL(fileURLWithPath: directory.standardizedFileURL.path, isDirectory: true)
        navigationError = nil
        if !didStart {
            currentDirectory = target
            return
        }
        if !isRunning {
            currentDirectory = target
            pendingDirectory = nil
            directoryChangeSentAt = nil
            exitMessage = nil
            didStart = false
            startIfNeeded()
            return
        }
        if let actual = process.workingDirectory() { currentDirectory = actual }
        if directoryChangeSentAt == nil && sameDirectory(currentDirectory, target) {
            pendingDirectory = nil
            return
        }
        if pendingDirectory.map({ sameDirectory($0, target) }) == true { return }
        pendingDirectory = target
        directoryChangeSentAt = nil
        attemptDirectoryChange()
    }

    func resize(columns: Int, rows: Int) {
        let width = max(10, columns), height = max(3, rows)
        guard buffer.columns != width || buffer.rows != height else { return }
        buffer.resize(columns: width, rows: height)
        process.resize(columns: width, rows: height)
    }

    func updateDirectory() {
        if let url = process.workingDirectory(), url != currentDirectory { currentDirectory = url }
        guard let target = pendingDirectory else { return }
        if sameDirectory(currentDirectory, target) {
            pendingDirectory = nil
            directoryChangeSentAt = nil
        } else if let sentAt = directoryChangeSentAt {
            if Date().timeIntervalSince(sentAt) > 3 && process.isShellForeground {
                navigationError = "폴더로 이동하지 못했습니다: \(target.path)"
                pendingDirectory = nil
                directoryChangeSentAt = nil
            }
        } else { attemptDirectoryChange() }
    }

    private func attemptDirectoryChange() {
        guard let target = pendingDirectory, directoryChangeSentAt == nil else { return }
        if process.changeDirectory(to: target) { directoryChangeSentAt = Date() }
    }

    private func sameDirectory(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.resolvingSymlinksInPath().path == rhs.resolvingSymlinksInPath().path
    }

    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            self?.refreshScheduled = false
            if self?.pendingDirectory != nil { self?.updateDirectory() }
            self?.hostView.refresh()
        }
    }
}
