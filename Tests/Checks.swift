import AppKit

struct CheckFailure: Error { let message: String }

@main
struct Checks {
    @MainActor static func main() async {
        do {
        try paths()
        try terminalScreen()
        try terminalKoreanGraphemes()
        try terminalResize()
        try TerminalScrollChecks.run()
        try await directories()
        try await FileOperationChecks.run()
        try await actualPTY()
        try await resizePTY()
        try history()
        try await favorites()
        try terminalTabs()
        print("PASS · 탐색·방문 기록·즐겨찾기 추가/제거/저장/이동·터미널 화면·분해형 한글·창 크기 변경 시 프롬프트 보존·PTY·현재 탭 경로 이동·명시적인 새 탭")
        } catch {
            print("FAIL · \(error)")
            exit(1)
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw CheckFailure(message: message) }
    }

    private static func paths() throws {
        let folder = URL(fileURLWithPath: "/tmp/a folder")
        try expect(PathUtilities.resolve("../b", relativeTo: folder).path == "/tmp/b", "relative path")
        try expect(PathUtilities.resolve("~", relativeTo: folder) == PathUtilities.userHome, "tilde refers to the account home")
        try expect(PathUtilities.resolve("~/한글 폴더", relativeTo: folder).path == PathUtilities.userHome.appendingPathComponent("한글 폴더").path, "home-relative Korean path")
        try expect(PathUtilities.displayPath(PathUtilities.userHome.appendingPathComponent("문서")) == "~/문서", "home path display")
        try expect(PathUtilities.breadcrumbs(for: folder).map(\.path) == ["/", "/tmp", "/tmp/a folder"], "breadcrumbs")
        try expect(PathUtilities.shellQuote("a'b") == "'a'\\''b'", "apostrophe quoting")
        try expect(PathUtilities.shellQuote("$(touch /tmp/oops)") == "'$(touch /tmp/oops)'", "shell quoting")
    }

    private static func terminalScreen() throws {
        let buffer = TerminalBuffer(columns: 20, rows: 4)
        let bytes = Array("한글".utf8)
        buffer.feed(Array(bytes.prefix(2))); buffer.feed(Array(bytes.dropFirst(2)))
        try expect(buffer.screen[0][0].text == "한" && buffer.screen[0][2].text == "글", "split Korean UTF-8")
        try expect(buffer.cursorX == 4, "wide character cursor")
        buffer.feed(Array("\r\u{1b}[2Kprompt> ".utf8))
        try expect(buffer.screen[0].prefix(8).map(\.text).joined() == "prompt> ", "shell prompt redraw")
        buffer.feed(Array("\u{1b}[31mred\u{1b}[0m\u{1b}[2;4HX".utf8))
        try expect(buffer.screen[0][8].foreground == 1 && buffer.screen[1][3].text == "X", "ANSI cursor/color")
        buffer.feed(Array("\u{1b}[?1049hother screen\u{1b}[?2004h".utf8))
        try expect(buffer.alternateScreen && buffer.bracketedPaste, "terminal private modes")
        buffer.resize(columns: 25, rows: 5)
        buffer.feed(Array("\u{1b}[?1049l".utf8))
        try expect(!buffer.alternateScreen && buffer.screen[1][3].text == "X", "alternate screen restore")
        try expect(buffer.screen.count == 5 && buffer.screen.allSatisfy { $0.count == 25 }, "screen resize")
        let scrolling = TerminalBuffer(columns: 20, rows: 3)
        scrolling.feed(Array("first\r\nsecond\r\nthird\r\nfourth".utf8))
        try expect(scrolling.scrollback.count == 1, "scrollback")
        try expect(scrolling.text(from: (0, 0), to: (1, 5)) == "first\nsecond", "selection across lines")
        try expect(scrolling.text(from: (999, 0), to: (1000, 1)).isEmpty, "selection bounds")
        scrolling.feed(Array("\u{1b}[999999999999999999999999;99999999Hsafe".utf8))
        try expect(scrolling.cursorX < scrolling.columns && scrolling.cursorY < scrolling.rows, "malformed CSI bounds")
    }

    private static func terminalKoreanGraphemes() throws {
        let composed = "/tmp/개인프로젝트/흔적X"
        for original in [composed, composed.decomposedStringWithCanonicalMapping] {
            let bytes = Array(original.utf8)
            for chunkSize in [1, 2, 5, bytes.count] {
                let buffer = TerminalBuffer(columns: 40, rows: 4)
                for offset in stride(from: 0, to: bytes.count, by: chunkSize) {
                    buffer.feed(Array(bytes[offset..<min(bytes.count, offset + chunkSize)]))
                }
                for (column, syllable) in zip([5, 7, 9, 11, 13, 15, 18, 20], "개인프로젝트흔적") {
                    try expect(buffer.screen[0][column].text == String(syllable), "Korean syllable stays in one cell (chunk \(chunkSize))")
                    try expect(buffer.screen[0][column].displayText.unicodeScalars.map(\.value) == String(syllable).unicodeScalars.map(\.value), "renderer receives composed Hangul glyph")
                    try expect(buffer.screen[0][column + 1].continuation, "Korean syllable occupies two terminal columns")
                }
                try expect(buffer.cursorX == 23 && buffer.screen[0][22].text == "X", "decomposed Korean cursor width")
                let copied = buffer.text(from: (0, 0), to: (0, 22))
                try expect(Array(copied.utf8) == bytes, "copy preserves original Korean normalization")
            }
        }

        let styled = TerminalBuffer(columns: 10, rows: 3)
        styled.feed(Array("\u{1b}[32mᄒ\u{1b}[33mᅳ".utf8))
        styled.feed(Array("ᆫX".utf8))
        try expect(styled.screen[0][0].text == "흔" && styled.screen[0][0].foreground == 2, "Hangul composition across output chunks and color changes")
        try expect(styled.cursorX == 3 && styled.screen[0][2].text == "X", "styled Hangul cursor width")

        let edge = TerminalBuffer(columns: 10, rows: 3)
        for byte in "12345678흔X".decomposedStringWithCanonicalMapping.utf8 { edge.feed([byte]) }
        try expect(edge.screen[0][8].text == "흔" && edge.screen[0][9].continuation, "decomposed Hangul at right edge")
        try expect(edge.screen[1][0].text == "X" && edge.cursorY == 1 && edge.cursorX == 1, "wrap happens after whole syllable")

        let wrapping = TerminalBuffer(columns: 10, rows: 3)
        wrapping.feed(Array("123456789흔X".decomposedStringWithCanonicalMapping.utf8))
        try expect(wrapping.screen[1][0].text == "흔" && wrapping.screen[1][2].text == "X", "wide syllable wraps before insufficient space")

        let accents = TerminalBuffer(columns: 10, rows: 3)
        accents.feed(Array("한\u{301}e\u{301}".utf8))
        try expect(Array(accents.screen[0][0].text.unicodeScalars.map(\.value)) == [0xd55c, 0x301], "combining accent attaches to leading wide cell")
        try expect(accents.screen[0][1].continuation && accents.screen[0][2].text == "é" && accents.cursorX == 3, "combining accents do not advance cursor")

        let moving = TerminalBuffer(columns: 10, rows: 3)
        moving.feed(Array("ᄒ\r\nᅳ".utf8))
        try expect(moving.screen[0][0].text == "ᄒ" && moving.screen[1][0].text == "ᅳ", "cursor movement ends grapheme composition")
    }

    private static func terminalResize() throws {
        let prompt = TerminalBuffer(columns: 80, rows: 30)
        prompt.feed(Array("prompt> ".utf8))
        for _ in 0..<10 {
            prompt.resize(columns: 80, rows: 8)
            prompt.feed(Array("\r\u{1b}[Jprompt> ".utf8))
            prompt.resize(columns: 80, rows: 30)
            prompt.feed(Array("\r\u{1b}[Jprompt> ".utf8))
        }
        try expect(prompt.scrollback.isEmpty, "idle prompt resize creates no fake scrollback")
        try expect(prompt.cursorY == 0 && prompt.cursorX == 8, "resizing an idle prompt preserves its cursor")
        try expect(prompt.allLines.filter { $0.contains { $0.text != " " && !$0.continuation } }.count == 1, "shell redraw stays on the same line after repeated resize")

        let partial = TerminalBuffer(columns: 20, rows: 6)
        partial.feed(Array("one\r\ntwo\r\nthree\r\nprompt> ".utf8))
        partial.resize(columns: 20, rows: 3)
        try expect(partial.scrollback.count == 1, "shrink discards blank rows before scrolling real output")
        try expect(partial.text(from: (0, 0), to: (3, 19)) == "one\ntwo\nthree\nprompt>", "actual output remains in order after shrink")
        try expect(partial.cursorY == 2 && partial.cursorX == 8, "cursor stays on the prompt when output must scroll")

        let full = TerminalBuffer(columns: 20, rows: 6)
        full.feed(Array("one\r\ntwo\r\nthree\r\nfour\r\nfive\r\nprompt> ".utf8))
        full.resize(columns: 20, rows: 3)
        try expect(full.scrollback.count == 3 && full.screen[2][0].text == "p", "full terminal preserves displaced output in scrollback")
        try expect(full.text(from: (0, 0), to: (5, 19)) == "one\ntwo\nthree\nfour\nfive\nprompt>", "resize keeps real command history")

        let empty = TerminalBuffer(columns: 20, rows: 30)
        empty.resize(columns: 20, rows: 3)
        try expect(empty.scrollback.isEmpty && empty.cursorY == 0, "empty screen shrink does not create history")
    }

    @MainActor private static func directories() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("프로젝트/소스"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("hello".utf8).write(to: root.appendingPathComponent("readme.txt"))
        try Data().write(to: root.appendingPathComponent(".hidden"))
        try Data().write(to: root.appendingPathComponent("프로젝트/소스/검색.swift"))
        try FileManager.default.createDirectory(at: root.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent("node_modules/검색.js"))
        let folderLink = root.appendingPathComponent("폴더 바로가기")
        try FileManager.default.createSymbolicLink(at: folderLink, withDestinationURL: root.appendingPathComponent("프로젝트"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("file-link"), withDestinationURL: root.appendingPathComponent("readme.txt"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("broken-link"), withDestinationURL: root.appendingPathComponent("missing"))
        let package = root.appendingPathComponent("Fixture.app")
        try FileManager.default.createDirectory(at: package.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: ["CFBundlePackageType": "APPL"], format: .xml, options: 0)
            .write(to: package.appendingPathComponent("Contents/Info.plist"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("app-link"), withDestinationURL: package)
        let service = DirectoryService()
        let entries = try await service.contents(of: root, showHidden: false)
        try expect(entries.first?.isNavigable == true, "folders first")
        try expect(entries.contains { $0.name == "readme.txt" && $0.size == 5 }, "files and metadata")
        try expect(!entries.contains { $0.name == ".hidden" }, "hidden files excluded")
        let linkedFolder = entries.first { $0.name == "폴더 바로가기" }
        try expect(linkedFolder?.isSymbolicLink == true && linkedFolder?.isNavigable == true, "folder symlink is navigable inside the app")
        try expect(entries.first { $0.name == "file-link" }?.isNavigable == false, "file symlink stays a file")
        try expect(entries.first { $0.name == "broken-link" }?.isNavigable == false, "broken symlink is not a folder")
        try expect(entries.first { $0.name == "app-link" }?.isPackage == true && entries.first { $0.name == "app-link" }?.isNavigable == false, "app symlink retains package behavior")
        let suite = "dev.lilim.folder-link-check.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let browser = BrowserState(defaults: defaults, initialDirectory: root)
        if let linkedFolder {
            browser.select(linkedFolder, column: 0)
            try expect(browser.currentDirectory.resolvingSymlinksInPath().path == folderLink.resolvingSymlinksInPath().path, "folder link click navigates inside the app: \(browser.currentDirectory.path)")
            browser.navigate(to: root)
            browser.open(linkedFolder, fromColumn: 0)
            try expect(browser.currentDirectory.resolvingSymlinksInPath().path == folderLink.resolvingSymlinksInPath().path, "folder link open navigates inside the app: \(browser.currentDirectory.path)")
        }
        let hidden = try await service.contents(of: root, showHidden: true)
        try expect(hidden.contains { $0.name == ".hidden" }, "hidden files included")
        let result = try await service.search(in: root, query: "검색", showHidden: false)
        try expect(result.entries.map(\.name) == ["검색.swift"] && !result.truncated, "recursive Korean search and ignored folders")
    }

    @MainActor private static func favorites() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let first = root.appendingPathComponent("한글 폴더")
        let second = root.appendingPathComponent("다른 폴더")
        let file = root.appendingPathComponent("readme.txt")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        try Data().write(to: file)
        let suite = "LilimFavoriteChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        let browser = BrowserState(defaults: defaults, initialDirectory: root)
        let entries = try await DirectoryService().contents(of: root, showHidden: false)
        browser.selectedEntries = entries
        let folder = entries.first { $0.name == first.lastPathComponent }!
        let terminals = TerminalStore()
        terminals.newSession(directory: root)
        let activeID = terminals.selectedID
        let addMenu = FileContextMenu.make(entry: folder, browser: browser, terminals: terminals)
        guard let addIndex = addMenu.items.firstIndex(where: { $0.title == "즐겨찾기에 추가" }) else {
            throw CheckFailure(message: "selected folders offer a favorite context action")
        }
        // This check executable has no NSApplication to dispatch menu actions.
        guard let addAction = addMenu.items[addIndex].target as? FileMenuAction else {
            throw CheckFailure(message: "favorite menu retains its action target")
        }
        addAction.invoke(addMenu.items[addIndex])
        try expect(browser.favorites.count == 2, "context action saves selected folders only (count \(browser.favorites.count), error \(browser.errorMessage ?? "none"))")
        try expect(browser.isFavorite(first) && browser.isFavorite(second), "both selected folders saved")
        try expect(browser.currentDirectory.resolvingSymlinksInPath() == root.resolvingSymlinksInPath(), "adding favorites does not navigate")
        try expect(terminals.sessions.count == 1 && terminals.selectedID == activeID, "adding favorites creates no terminal tabs")
        browser.addFavorite(first.appendingPathComponent("../한글 폴더"))
        try expect(browser.favorites.count == 2, "equivalent paths do not duplicate favorites")
        browser.addFavorite(file)
        try expect(browser.favorites.count == 2 && browser.errorMessage != nil, "files cannot be saved as favorite folders")

        // Restore from an independently opened preferences object, as on app launch.
        let restored = BrowserState(defaults: UserDefaults(suiteName: suite)!, initialDirectory: root)
        try expect(restored.favorites == browser.favorites, "favorite order and Korean paths survive restoration")
        restored.navigate(to: restored.favorites.first!.url)
        try expect(restored.isFavorite && restored.currentDirectory.path == restored.favorites.first!.path, "saved location uses internal folder navigation")
        restored.toggleFavorite()
        try expect(!restored.isFavorite && restored.favorites.count == 1, "current-folder star removes its favorite only")
        restored.toggleFavorite()
        restored.selectedEntries = entries
        let removeMenu = FileContextMenu.make(entry: folder, browser: restored, terminals: terminals)
        guard let removeIndex = removeMenu.items.firstIndex(where: { $0.title == "즐겨찾기에서 제거" }) else {
            throw CheckFailure(message: "saved folders offer a remove context action")
        }
        guard let removeAction = removeMenu.items[removeIndex].target as? FileMenuAction else {
            throw CheckFailure(message: "remove favorite menu retains its action target")
        }
        removeAction.invoke(removeMenu.items[removeIndex])
        let empty = BrowserState(defaults: UserDefaults(suiteName: suite)!, initialDirectory: root)
        try expect(empty.favorites.isEmpty, "context removal persists across app launches")

        defaults.set([first.path, first.appendingPathComponent("../한글 폴더").path], forKey: "favoritePaths")
        let migrated = BrowserState(defaults: defaults, initialDirectory: root)
        try expect(migrated.favorites.count == 1, "previous duplicate preferences restore without duplicate sidebar rows")
    }

    @MainActor private static func actualPTY() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lilim test '\(UUID().uuidString)")
        let koreanPath = "한글 폴더/개인프로젝트/흔적"
        let child = root.appendingPathComponent(koreanPath.decomposedStringWithCanonicalMapping)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let process = PTYProcess()
        var output = ""
        let screen = TerminalBuffer(columns: 400, rows: 40)
        process.onData = {
            output += String(decoding: $0, as: UTF8.self)
            screen.feed($0)
        }
        try process.start(directory: root, columns: 80, rows: 24)
        let originalPID = process.pid
        defer { process.terminate() }
        process.resize(columns: 93, rows: 31)
        process.send(Array("LILIM_TAB_TEST=kept; printf '\\nLILIM_CWD='; /bin/pwd; stty size; printf '\\nLILIM_DONE\\n'\r".utf8))
        for _ in 0..<400 {
            if output.contains("\r\nLILIM_DONE\r\n") { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        try expect(output.contains(root.path), "PTY working directory with spaces and apostrophe")
        try expect(output.contains("31 93"), "PTY window size")
        try expect(output.contains("\r\nLILIM_DONE\r\n"), "PTY interactive shell input")
        process.send(Array("echo LILIM_MUST_NOT_RUN\u{1b}[D\u{1b}[D".utf8))
        try expect(process.changeDirectory(to: child), "idle shell accepts same-tab directory change")
        for _ in 0..<200 {
            if process.workingDirectory()?.resolvingSymlinksInPath().path == child.resolvingSymlinksInPath().path { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        try expect(process.workingDirectory()?.resolvingSymlinksInPath().path == child.resolvingSymlinksInPath().path, "shell cd tracking")
        try expect(process.pid == originalPID, "folder change keeps the same shell process")
        try expect(!output.contains("\r\nLILIM_MUST_NOT_RUN\r\n"), "folder change clears unfinished input without executing it")
        process.send(Array("printf '\\nLILIM_STATE=%s\\n' \"$LILIM_TAB_TEST\"; /bin/pwd; printf '\\nLILIM_KOREAN_DONE\\n'\r".utf8))
        for _ in 0..<200 {
            if output.contains("\r\nLILIM_KOREAN_DONE\r\n") { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        try expect(output.contains("\r\nLILIM_STATE=kept\r\n"), "directory change preserves shell variables")
        try expect(output.contains("\r\nLILIM_KOREAN_DONE\r\n"), "PTY pwd in decomposed Korean directory")
        let rendered = screen.allLines.map { $0.filter { !$0.continuation }.map(\.displayText).joined() }.joined(separator: "\n")
        try expect(rendered.contains(koreanPath), "actual shell output renders decomposed Korean folder names together")
        process.send(Array("sleep 30\r".utf8))
        for _ in 0..<100 {
            if !process.isShellForeground { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        try expect(!process.isShellForeground, "foreground job detected")
        try expect(!process.changeDirectory(to: root), "directory change is not sent into a running job")
        try expect(process.workingDirectory()?.resolvingSymlinksInPath().path == child.resolvingSymlinksInPath().path, "busy shell keeps its directory")
        process.send([3])
        process.send(Array("printf '\\nLILIM_INTERRUPT_OK\\n'\r".utf8))
        for _ in 0..<200 {
            if output.contains("\r\nLILIM_INTERRUPT_OK\r\n") { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        try expect(output.contains("\r\nLILIM_INTERRUPT_OK\r\n"), "Ctrl-C interrupts foreground job and shell stays alive")
        try expect(process.changeDirectory(to: root), "directory change resumes after foreground job")
        for _ in 0..<200 {
            if process.workingDirectory()?.resolvingSymlinksInPath().path == root.resolvingSymlinksInPath().path { break }
            try await Task.sleep(for: .milliseconds(25))
        }
        try expect(process.workingDirectory()?.resolvingSymlinksInPath().path == root.resolvingSymlinksInPath().path, "post-job directory change")
        try expect(process.pid == originalPID, "post-job navigation preserves the shell")
    }

    @MainActor private static func resizePTY() async throws {
        let process = PTYProcess()
        let buffer = TerminalBuffer(columns: 80, rows: 30)
        var outputBytes = 0
        process.onData = { bytes in outputBytes += bytes.count; buffer.feed(bytes) }
        try process.start(directory: FileManager.default.temporaryDirectory, columns: 80, rows: 30)
        defer { process.terminate() }
        try await Task.sleep(for: .seconds(2))
        let initialLines = buffer.allLines.filter { $0.contains { !$0.continuation && $0.text != " " } }.count
        let initialScrollback = buffer.scrollback.count
        let initialBytes = outputBytes
        try expect(initialLines > 0, "idle shell prompt ready for resize regression")
        // No keyboard input is sent: only the terminal dimensions change.
        for _ in 0..<4 {
            buffer.resize(columns: 80, rows: 8); process.resize(columns: 80, rows: 8)
            try await Task.sleep(for: .milliseconds(150))
            buffer.resize(columns: 80, rows: 30); process.resize(columns: 80, rows: 30)
            try await Task.sleep(for: .milliseconds(150))
        }
        let finalLines = buffer.allLines.filter { $0.contains { !$0.continuation && $0.text != " " } }.count
        try expect(outputBytes > initialBytes, "real shell redraws after terminal resize")
        try expect(finalLines == initialLines && buffer.scrollback.count == initialScrollback, "actual shell resize does not duplicate prompts without Enter")
    }

    @MainActor private static func history() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("a/b"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let browser = BrowserState(defaults: defaults, initialDirectory: root)
        let a = root.appendingPathComponent("a"), b = a.appendingPathComponent("b")
        browser.navigate(to: a, fromColumn: 0); browser.navigate(to: b, fromColumn: 1)
        try expect(browser.columns.map { $0.directory.path } == [root, a, b].map { $0.standardizedFileURL.path }, "three folder columns: \(browser.columns.map { $0.directory.path })")
        browser.goBack()
        try expect(browser.currentDirectory.path == a.standardizedFileURL.path && browser.canGoForward, "back navigation")
        browser.navigate(to: b, fromColumn: 1)
        try expect(browser.historyIndex == 2 && !browser.canGoForward, "history branching")
        browser.goBack()
        try expect(browser.currentDirectory.path == a.standardizedFileURL.path, "branched back navigation")
    }

    @MainActor private static func terminalTabs() throws {
        let root = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let child = root.appendingPathComponent("first", isDirectory: true)
        let other = root.appendingPathComponent("second", isDirectory: true)
        let terminals = TerminalStore()
        terminals.navigate(directory: root)
        let firstID = terminals.selectedID
        terminals.navigate(directory: child)
        terminals.navigate(directory: other)
        try expect(terminals.sessions.count == 1 && terminals.selectedID == firstID, "folder clicks reuse current tab")
        try expect(terminals.active?.currentDirectory.path == other.path, "unstarted tab starts in last selected folder")
        terminals.newSession(directory: child)
        let secondID = terminals.selectedID
        try expect(terminals.sessions.count == 2 && secondID != firstID, "explicit action creates new tab")
        terminals.navigate(directory: root)
        try expect(terminals.sessions.count == 2 && terminals.selectedID == secondID, "navigation stays in explicitly selected tab")
        try expect(terminals.sessions[0].currentDirectory.path == other.path, "inactive tab keeps its directory")
        terminals.selectedID = firstID
        terminals.navigate(directory: root)
        try expect(terminals.sessions.count == 2 && terminals.selectedID == firstID, "same directory in another tab does not switch tabs")
        try expect(terminals.active?.currentDirectory.path == root.path, "active tab moves to a directory already open elsewhere")
        if let secondID { terminals.close(secondID) }
        try expect(terminals.sessions.count == 1 && terminals.selectedID == firstID, "closing inactive tab preserves active tab")
    }
}
