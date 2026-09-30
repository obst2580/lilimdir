import AppKit

@MainActor
enum FileOperationChecks {
    private static func expect(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !value() { throw CheckFailure(message: message) }
    }
    static func run() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("Lilim-Files-Check-\(UUID())")
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        var ownedTrash = Set<URL>()
        defer {
            try? manager.removeItem(at: root)
            for url in ownedTrash { try? manager.removeItem(at: url) }
        }
        func track(_ result: FileOperationResult) {
            for url in result.affected where !url.path.hasPrefix(root.path + "/") { ownedTrash.insert(url) }
            for step in result.inverse {
                if case .move(let from, _) = step, !from.path.hasPrefix(root.path + "/") { ownedTrash.insert(from) }
            }
        }
        func file(_ name: String, in directory: URL, content: String) throws -> URL {
            let url = directory.appendingPathComponent(name)
            try Data(content.utf8).write(to: url)
            return url
        }
        func contents(_ url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }
        let engine = FileOperationService()
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("destination")
        try manager.createDirectory(at: source, withIntermediateDirectories: true)
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        let name = "한글 ' 파일.txt".decomposedStringWithCanonicalMapping
        let original = try file(name, in: source, content: "original 한글")
        let copied = await engine.transfer([original], to: destination, mode: .copy)
        track(copied)
        try expect(copied.issues.isEmpty && copied.affected.count == 1, "copy Unicode/quote name")
        let target = copied.affected[0]
        try expect(try contents(target) == contents(original), "copy exact bytes and preserve original")
        let old = try file(name, in: destination, content: "old destination")
        let replaced = await engine.transfer([original], to: destination, mode: .copy, policy: .replace)
        track(replaced)
        try expect(replaced.issues.isEmpty && replaced.inverse.count == 2, "replace journals original destination")
        try expect(try contents(old) == "original 한글", "replace commits new content")
        let undone = await engine.apply(replaced.inverse); track(undone)
        try expect(undone.issues.isEmpty && (try contents(old)) == "old destination", "undo replace restores old destination")
        let redone = await engine.apply(undone.inverse); track(redone)
        try expect(redone.issues.isEmpty && (try contents(old)) == "original 한글", "redo replace")
        let kept = await engine.transfer([original], to: destination, mode: .copy, policy: .keepBoth); track(kept)
        try expect(kept.issues.isEmpty && kept.affected.first != target && manager.fileExists(atPath: target.path), "keep both collision")
        let skipped = await engine.transfer([original], to: destination, mode: .move, policy: .skip)
        try expect(skipped.affected.isEmpty && skipped.inverse.isEmpty && manager.fileExists(atPath: original.path), "skip move preserves source")
        let aborted = await engine.transfer([original], to: destination, mode: .copy, policy: .abort)
        try expect(!aborted.issues.isEmpty && aborted.inverse.isEmpty, "abort collision does not mutate")
        let duplicates = await engine.duplicate([original, original]); track(duplicates)
        try expect(duplicates.issues.isEmpty && duplicates.affected.count == 1 && duplicates.affected[0].pathExtension == "txt", "duplicate deduplicates and preserves extension")
        let moved = await engine.transfer(duplicates.affected, to: destination, mode: .move); track(moved)
        try expect(moved.issues.isEmpty && !manager.fileExists(atPath: duplicates.affected[0].path), "move removes source only on success")
        let restoredMove = await engine.apply(moved.inverse); track(restoredMove)
        try expect(restoredMove.issues.isEmpty && manager.fileExists(atPath: duplicates.affected[0].path), "undo move")

        let folder = source.appendingPathComponent("Folder.with.dot")
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let child = try file("nested.txt", in: folder, content: "nested")
        let dangling = folder.appendingPathComponent("dangling")
        try manager.createSymbolicLink(atPath: dangling.path, withDestinationPath: "missing-target")
        let topLevel = await engine.transfer([folder, child], to: destination, mode: .copy); track(topLevel)
        try expect(topLevel.issues.isEmpty && topLevel.affected.count == 1, "selected ancestor includes descendant once")
        let copiedLink = destination.appendingPathComponent("Folder.with.dot/dangling")
        try expect(try manager.destinationOfSymbolicLink(atPath: copiedLink.path) == "missing-target", "copy preserves dangling symlink")
        let invalid = await engine.transfer([folder], to: folder, mode: .copy)
        try expect(!invalid.issues.isEmpty && invalid.inverse.isEmpty, "reject folder into itself")
        let linkToChild = root.appendingPathComponent("link-to-folder")
        try manager.createSymbolicLink(atPath: linkToChild.path, withDestinationPath: folder.path)
        let invalidLink = await engine.transfer([folder], to: linkToChild, mode: .move)
        try expect(!invalidLink.issues.isEmpty && manager.fileExists(atPath: child.path), "reject descendant destination through symlink")
        let sameMove = await engine.transfer([original], to: source, mode: .move)
        try expect(sameMove.affected.isEmpty && sameMove.issues.isEmpty, "move within same folder no-op")
        let missing = source.appendingPathComponent("missing")
        let partial = await engine.transfer([original, missing], to: destination, mode: .copy); track(partial)
        try expect(partial.affected.count == 1 && partial.issues.count == 1 && !partial.inverse.isEmpty, "partial batch retains undo for completed item")
        let noSpace = root.appendingPathComponent("missing-directory")
        let failedMove = await engine.transfer([original], to: noSpace, mode: .move)
        try expect(!failedMove.issues.isEmpty && manager.fileExists(atPath: original.path), "failed move preserves source")

        let newFolder = await engine.create(in: destination, name: "새 폴더", folder: true); track(newFolder)
        try expect(newFolder.issues.isEmpty && newFolder.affected.count == 1, "create folder")
        let created = await engine.create(in: destination, name: "new.txt", folder: false); track(created)
        try expect(created.issues.isEmpty && (try Data(contentsOf: created.affected[0])).isEmpty, "create empty file")
        for name in ["", ".", "..", "a/b", "a\0b", "a\nb"] {
            let result = await engine.create(in: destination, name: name, folder: true)
            try expect(!result.issues.isEmpty && result.affected.isEmpty, "reject invalid name")
        }
        let renameCollision = await engine.rename(created.affected[0], name: target.lastPathComponent)
        try expect(!renameCollision.issues.isEmpty && manager.fileExists(atPath: created.affected[0].path), "rename collision does not overwrite")
        let renamed = await engine.rename(created.affected[0], name: "renamed.txt"); track(renamed)
        try expect(renamed.issues.isEmpty && renamed.affected[0].lastPathComponent == "renamed.txt", "rename")
        let restoredName = await engine.apply(renamed.inverse); track(restoredName)
        try expect(restoredName.issues.isEmpty && manager.fileExists(atPath: created.affected[0].path), "undo rename")
        let a = try file("batch-a.txt", in: source, content: "a")
        let b = try file("batch-b.txt", in: source, content: "b")
        let caseRename = await engine.rename(b, name: "BATCH-B.txt"); track(caseRename)
        try expect(caseRename.issues.isEmpty && caseRename.affected.first?.lastPathComponent == "BATCH-B.txt", "case-only rename")
        let caseUndo = await engine.apply(caseRename.inverse); track(caseUndo)
        try expect(caseUndo.issues.isEmpty && manager.fileExists(atPath: b.path), "undo case-only rename")
        let batchCollision = await engine.renameBatch([(a, "same.txt"), (b, "same.txt")])
        try expect(!batchCollision.issues.isEmpty && manager.fileExists(atPath: a.path) && manager.fileExists(atPath: b.path), "batch rename preflights collisions")
        let batch = await engine.renameBatch([(a, "자료 1.txt"), (b, "자료 2.txt")]); track(batch)
        try expect(batch.issues.isEmpty && batch.affected.count == 2, "batch rename")
        let batchUndo = await engine.apply(batch.inverse); track(batchUndo)
        try expect(batchUndo.issues.isEmpty && (try contents(a)) == "a" && (try contents(b)) == "b", "undo batch rename")
        let trashed = await engine.moveToTrash([a, a]); track(trashed)
        try expect(trashed.issues.isEmpty && trashed.affected.count == 1 && !manager.fileExists(atPath: a.path), "native Trash")
        _ = try file("batch-a.txt", in: source, content: "foreign file")
        let refusedUndo = await engine.apply(trashed.inverse); track(refusedUndo)
        try expect(!refusedUndo.issues.isEmpty && refusedUndo.remaining.count == 1 && (try contents(a)) == "foreign file", "undo refuses to overwrite a new file")
        try manager.removeItem(at: a)
        let trashUndo = await engine.apply(refusedUndo.remaining); track(trashUndo)
        try expect(trashUndo.issues.isEmpty && (try contents(a)) == "a", "retry undo restores trashed file")
        let alias = await engine.makeAliases([folder], in: destination); track(alias)
        try expect(alias.issues.isEmpty && alias.affected.count == 1, "Finder alias creation")
        let resolved = try URL(resolvingAliasFileAt: alias.affected[0], options: [.withoutUI, .withoutMounting])
        try expect(resolved.standardizedFileURL.path == folder.standardizedFileURL.path, "Finder alias resolves original folder")
        let minus = try file("-strange.txt", in: source, content: "no option injection")
        let compressed = await engine.compress([original, folder, minus], in: destination); track(compressed)
        try expect(compressed.issues.isEmpty && compressed.affected.count == 1, "ZIP archive creation")
        let list = Process(); list.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        list.arguments = ["-Z1", compressed.affected[0].path]
        let pipe = Pipe(); list.standardOutput = pipe; list.standardError = FileHandle.nullDevice
        try list.run(); let names = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self); list.waitUntilExit()
        try expect(list.terminationStatus == 0 && names.contains("-strange.txt") && names.contains("nested.txt"), "ZIP includes option-like names and nested files")
        let tagged = await engine.setTags([a], names: ["검증", "Lilim"], label: 2); track(tagged)
        try expect(tagged.issues.isEmpty, "Finder tags write")
        let tagValues = try URL(fileURLWithPath: a.path).resourceValues(forKeys: [.tagNamesKey, .labelNumberKey])
        try expect(Set(tagValues.tagNames ?? []).isSuperset(of: ["검증", "Lilim"]) && tagValues.labelNumber == 2, "Finder tags and color round trip: \(tagValues.tagNames ?? []) / \(tagValues.labelNumber ?? -1)")
        let appended = await engine.setTags([a], names: ["추가"], label: 0, append: true); track(appended)
        let appendValues = try URL(fileURLWithPath: a.path).resourceValues(forKeys: [.tagNamesKey, .labelNumberKey])
        try expect(appendValues.tagNames?.contains("검증") == true && appendValues.tagNames?.contains("추가") == true && appendValues.labelNumber == 2, "append tags preserves existing tags and label")
        let tagUndo = await engine.apply(appended.inverse); track(tagUndo)
        try expect(tagUndo.issues.isEmpty, "undo tags")
        let tagSnapshot = try FileTagSnapshot.read(a)
        let colorChanged = await engine.setTags([a], names: ["변경"], label: 6); track(colorChanged)
        let colorsRestored = await engine.apply(colorChanged.inverse); track(colorsRestored)
        try expect(colorsRestored.issues.isEmpty && (try FileTagSnapshot.read(a)).metadata == tagSnapshot.metadata, "tag undo preserves exact native tag metadata")
        let removedTags = await engine.apply(tagged.inverse); track(removedTags)
        try expect(removedTags.issues.isEmpty && (try URL(fileURLWithPath: a.path).resourceValues(forKeys: [.labelNumberKey])).labelNumber == 0, "undo original tag change")

        let pasteboard = NSPasteboard(name: .init("dev.lilim.checks.\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        FileClipboard.write([original, a], to: pasteboard)
        try expect(Set(FileClipboard.read(from: pasteboard)) == Set([original, a]), "multi-file Finder pasteboard interop")
        pasteboard.clearContents(); pasteboard.setString("ordinary text", forType: .string)
        try expect(FileClipboard.read(from: pasteboard).isEmpty, "ordinary clipboard text is not a file operation")
        let perms = await engine.setPermissions(a, value: 0o600); track(perms)
        try expect(perms.issues.isEmpty && (try manager.attributesOfItem(atPath: a.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600, "permission editing")
        let permsUndo = await engine.apply(perms.inverse); track(permsUndo)
        try expect(permsUndo.issues.isEmpty, "undo permission editing")
        let lock = await engine.setLocked(a, value: true); track(lock)
        try expect(lock.issues.isEmpty && (try manager.attributesOfItem(atPath: a.path)[.immutable] as? NSNumber)?.boolValue == true, "file lock")
        let lockUndo = await engine.apply(lock.inverse); track(lockUndo)
        try expect(lockUndo.issues.isEmpty && (try manager.attributesOfItem(atPath: a.path)[.immutable] as? NSNumber)?.boolValue == false, "undo file lock")
        try await selection(in: source)
        let staged = try manager.contentsOfDirectory(atPath: destination.path).filter { $0.hasPrefix(".Lilim-Copy-") }
        try expect(staged.isEmpty, "copy staging cleaned up")
        print("PASS · 파일 복사·이동·이름 충돌·대치/취소/재실행·폴더/파일 생성·다중 이름 변경·휴지통 복원·가상본·ZIP·태그·파일 클립보드")
    }

    private static func selection(in directory: URL) async throws {
        let suite = "dev.lilim.file-selection-check.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let browser = BrowserState(defaults: defaults, initialDirectory: directory)
        for _ in 0..<100 {
            if browser.columns.last?.isLoading == false { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let entries = browser.currentEntries
        try expect(entries.count >= 3, "selection fixture loaded")
        browser.select(entries[0], column: 0, navigateFolder: false)
        browser.select(entries[2], column: 0, modifiers: .shift, navigateFolder: false)
        try expect(browser.selectedEntries.count == 3, "Shift selects contiguous range")
        browser.select(entries[1], column: 0, modifiers: .command, navigateFolder: false)
        try expect(browser.selectedEntries.count == 2 && !browser.selectedEntries.contains(entries[1]), "Command toggles selection")
        browser.select(entries[2], column: 0, navigateFolder: false)
        browser.selectRelative(-1, extend: true)
        browser.selectRelative(-1, extend: true)
        try expect(browser.selectedEntries.count == 3 && browser.selection?.id == entries[0].id, "Shift-Up continues extending toward earlier rows")
        browser.selectRelative(1, extend: true)
        try expect(browser.selectedEntries.count == 2 && browser.selection?.id == entries[1].id, "range selection can shrink toward anchor")
        browser.selectAllFiles()
        try expect(browser.selectedEntries.count == entries.count, "select all current column")
        browser.viewMode = .list
        if let folder = entries.first(where: \.isNavigable) {
            browser.select(folder, column: 0)
            try expect(browser.currentDirectory.resolvingSymlinksInPath().path == folder.navigationURL.resolvingSymlinksInPath().path && browser.selectedEntries.isEmpty && browser.keyboardColumn == 1, "list folder navigation resets selection to visible column")
            browser.nameInput = "renamed-current-folder"
            browser.namePrompt = FileNamePrompt(title: "이름 변경", kind: .rename(folder.url), directory: directory)
            browser.submitNamePrompt()
            for _ in 0..<100 { if !browser.operations.isBusy { break }; try await Task.sleep(for: .milliseconds(10)) }
            try expect(browser.currentDirectory.lastPathComponent == "renamed-current-folder", "browser follows renamed current folder: \(browser.currentDirectory.path) / \(browser.errorMessage ?? "no error")")
            browser.undoFiles()
            for _ in 0..<100 { if !browser.operations.isBusy { break }; try await Task.sleep(for: .milliseconds(10)) }
            try expect(browser.currentDirectory.lastPathComponent == folder.name && managerExists(folder.url), "browser follows undo of current folder rename")
        }
        let entry = FileEntry(url: directory.appendingPathComponent("sample.txt"), isDirectory: false, isPackage: false, isSymbolicLink: false, size: 1, modifiedAt: nil)
        try expect(BatchRenameMode.suffix.name(for: entry, index: 0, text: "-new", replacement: "", start: 1) == "sample-new.txt", "batch suffix preserves extension")
        try expect(BatchRenameMode.numbered.name(for: entry, index: 2, text: "자료", replacement: "", start: 10) == "자료 12.txt", "batch numbered naming")
        var invoked = false
        let action = FileMenuAction { invoked = true }
        try expect(NSStringFromSelector(#selector(FileMenuAction.invoke(_:))) == "invoke:", "context menu uses its own Objective-C selector")
        _ = action.perform(#selector(FileMenuAction.invoke(_:)), with: nil)
        try expect(invoked, "context menu target dispatch invokes closure")
    }
    private static func managerExists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
}
