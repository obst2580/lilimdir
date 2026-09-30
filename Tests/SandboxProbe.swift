import AppKit
import SwiftUI
import PTYBridge

// Standalone executable: scripts/check.sh excludes this separate entry point.
@MainActor @main
struct SandboxProbe {
    static func main() throws {
        if argument("--choose-folder") != nil {
            SandboxProbeApp.main()
            return
        }
        let result = try run()
        print(result.output)
        if !result.passed { exit(1) }
    }

    static func argument(_ name: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }

    static func run(selectedFolder: URL? = nil) throws -> (output: String, passed: Bool) {
        var outcomes: [String] = []
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lilim-sandbox-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        if selectedFolder == nil, let path = argument("--outside") {
            let outside = URL(fileURLWithPath: path)
            let denied = (try? Data(contentsOf: outside.appendingPathComponent("outside-marker.txt"))) == nil
            outcomes.append("\(denied ? "PASS" : "FAIL") · sandbox denies unselected external fixture")
            guard denied else { return (outcomes.joined(separator: "\n"), false) }
        }
        if let folder = selectedFolder {
            try Data("parent granted access\n".utf8).write(to: folder.appendingPathComponent("parent-output.txt"))
            outcomes.append("PASS · parent writes in user-selected folder")
        }
        var master: Int32 = -1
        let child = lilim_pty_spawn("/bin/zsh", root.path, 24, 80, &master)
        guard child > 0 else {
            outcomes.append("FAIL · sandbox PTY spawn: errno=\(errno) (\(String(cString: strerror(errno))))")
            return (outcomes.joined(separator: "\n"), false)
        }
        defer {
            _ = kill(-child, SIGHUP); _ = kill(child, SIGHUP)
            close(master)
            var status: Int32 = 0; _ = waitpid(child, &status, 0)
        }
        _ = fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK)
        var command = "printf '\\nLILIM_SANDBOX_BUILTIN_OK\\n'; /usr/bin/true && printf 'LILIM_SANDBOX_SYSTEM_OK\\n'; "
        if let folder = selectedFolder {
            let quoted = "'" + folder.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
            command += "builtin cd -- \(quoted) && printf 'child granted access\\n' > child-output.txt && printf 'LILIM_SANDBOX_FOLDER_OK\\n'; "
            command += "\(quoted)/external-tool && printf 'LILIM_SANDBOX_EXTERNAL_OK\\n'; "
        }
        command += "printf 'LILIM_SANDBOX_DONE\\n'\r"
        let bytes = Array(command.utf8)
        _ = bytes.withUnsafeBytes { write(master, $0.baseAddress, $0.count) }
        var output = Data()
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            var buffer = [UInt8](repeating: 0, count: 4096)
            let count = read(master, &buffer, buffer.count)
            if count > 0 { output.append(contentsOf: buffer.prefix(count)) }
            if String(decoding: output, as: UTF8.self).contains("\r\nLILIM_SANDBOX_DONE\r\n") { break }
            usleep(20_000)
        }
        let text = String(decoding: output, as: UTF8.self)
        let builtinOK = text.contains("\r\nLILIM_SANDBOX_BUILTIN_OK\r\n")
        let systemOK = text.contains("\r\nLILIM_SANDBOX_SYSTEM_OK\r\n")
        let foregroundOK = tcgetpgrp(master) == child
        var cwd = [CChar](repeating: 0, count: Int(PATH_MAX))
        let directoryOK = lilim_pty_directory(child, &cwd, Int32(cwd.count)) == 1
        outcomes.append("\(builtinOK ? "PASS" : "FAIL") · sandbox login shell and builtin")
        outcomes.append("\(systemOK ? "PASS" : "FAIL") · sandbox system command")
        outcomes.append("\(foregroundOK ? "PASS" : "FAIL") · controlling terminal and foreground shell tracking")
        outcomes.append("\(directoryOK ? "PASS" : "FAIL") · shell working directory tracking")
        var externalOK = true
        if selectedFolder != nil {
            let folderOK = text.contains("\r\nLILIM_SANDBOX_FOLDER_OK\r\n")
            let toolOK = text.contains("\r\nLILIM_SANDBOX_EXTERNAL_OK\r\n")
            outcomes.append("\(folderOK ? "PASS" : "FAIL") · child uses user-selected folder")
            outcomes.append("\(toolOK ? "PASS" : "FAIL") · child executes user-selected external tool")
            externalOK = folderOK && toolOK
        }
        return (outcomes.joined(separator: "\n"), builtinOK && systemOK && foregroundOK && directoryOK && externalOK)
    }
}

struct SandboxProbeApp: App {
    @State private var report = "검증용 임시 폴더를 선택하세요."
    var body: some Scene {
        Window("Lilim Sandbox Probe", id: "probe") {
            VStack(alignment: .leading, spacing: 20) {
                Text(report).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                Button("검증 폴더 허용") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false; panel.canChooseDirectories = true
                    panel.directoryURL = SandboxProbe.argument("--choose-folder").map { URL(fileURLWithPath: $0) }
                    panel.prompt = "검증 폴더 허용"
                    guard panel.runModal() == .OK, let folder = panel.url else { return }
                    do {
                        let result = try SandboxProbe.run(selectedFolder: folder)
                        report = result.output
                        try Data(report.utf8).write(to: folder.appendingPathComponent("sandbox-results.txt"))
                    } catch { report = "FAIL · \(error.localizedDescription)" }
                }
            }.padding(28).frame(minWidth: 580, minHeight: 300)
        }
    }
}
