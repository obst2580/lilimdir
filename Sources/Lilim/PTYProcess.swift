import Foundation
import PTYBridge

@MainActor
final class PTYProcess {
    private(set) var pid: pid_t = -1
    private var descriptor: Int32 = -1
    private var reader: (any DispatchSourceRead)?
    private var exitSource: (any DispatchSourceProcess)?
    private var pendingInput = Data()
    private var writeScheduled = false
    var onData: (([UInt8]) -> Void)?
    var onExit: ((Int32) -> Void)?

    func start(directory: URL, columns: Int, rows: Int) throws {
        let configured = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shell = FileManager.default.isExecutableFile(atPath: configured) ? configured : "/bin/zsh"
        var master: Int32 = -1
        pid = lilim_pty_spawn(shell, directory.path, UInt16(clamping: rows), UInt16(clamping: columns), &master)
        guard pid > 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        descriptor = master
        _ = fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK)
        let reader = DispatchSource.makeReadSource(fileDescriptor: master, queue: .main)
        reader.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.readOutput() } }
        let masterDescriptor = master
        reader.setCancelHandler { close(masterDescriptor) }
        reader.resume()
        self.reader = reader
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.readOutput()
                var status: Int32 = 0
                _ = waitpid(self.pid, &status, 0)
                reader.cancel(); self.reader = nil; self.descriptor = -1
                self.exitSource?.cancel(); self.exitSource = nil; self.pid = -1
                self.onExit?(status)
            }
        }
        source.resume()
        exitSource = source
    }

    func send(_ data: [UInt8]) {
        guard descriptor >= 0 else { return }
        pendingInput.append(contentsOf: data)
        flushInput()
    }

    func resize(columns: Int, rows: Int) {
        guard descriptor >= 0 else { return }
        _ = lilim_pty_resize(descriptor, UInt16(clamping: rows), UInt16(clamping: columns))
    }

    func workingDirectory() -> URL? {
        guard pid > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard lilim_pty_directory(pid, &buffer, Int32(buffer.count)) == 1 else { return nil }
        let value = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return value.isEmpty ? nil : URL(fileURLWithPath: value, isDirectory: true)
    }

    var isShellForeground: Bool { descriptor >= 0 && pid > 0 && tcgetpgrp(descriptor) == pid }

    @discardableResult
    func changeDirectory(to directory: URL) -> Bool {
        guard isShellForeground else { return false }
        // Clear an unfinished readline command before inserting a safely quoted directory change.
        // Only send this to the shell, never to a foreground editor or another running command.
        send(Array(("\u{1}\u{b}builtin cd -- " + PathUtilities.shellQuote(directory.path) + "\r").utf8))
        return true
    }

    func terminate() {
        guard pid > 0 else { return }
        _ = kill(-pid, SIGHUP)
        _ = kill(pid, SIGHUP)
        reader?.cancel(); reader = nil; descriptor = -1
        pendingInput = Data()
        // The exit source remains alive to reap the child without blocking the UI.
    }

    private func readOutput() {
        guard descriptor >= 0 else { return }
        var bytes = [UInt8](repeating: 0, count: 16_384)
        for _ in 0..<16 {
            let count = read(descriptor, &bytes, bytes.count)
            if count > 0 { onData?(Array(bytes.prefix(count))) }
            else if count < 0 && errno == EINTR { continue }
            else { break }
        }
    }

    private func flushInput() {
        guard descriptor >= 0 else { return }
        while !pendingInput.isEmpty {
            let count = pendingInput.withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
            if count > 0 { pendingInput.removeFirst(count) }
            else if count < 0 && errno == EINTR { continue }
            else { break }
        }
        if !pendingInput.isEmpty && !writeScheduled {
            writeScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.writeScheduled = false
                self?.flushInput()
            }
        }
    }

    isolated deinit {
        if pid > 0 { _ = kill(-pid, SIGHUP); _ = kill(pid, SIGHUP) }
        reader?.cancel(); exitSource?.cancel()
        if pid > 0 {
            let child = pid
            DispatchQueue.global().async { var status: Int32 = 0; _ = waitpid(child, &status, 0) }
        }
    }
}
