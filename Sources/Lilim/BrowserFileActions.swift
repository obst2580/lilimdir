import AppKit

extension BrowserState {
    var hasFileFocus: Bool { filesFocused && NSApp.keyWindow?.firstResponder is ExplorerKeyboardView }
    var isWorking: Bool { operations.isBusy || isChoosingTransfer }
    var selectedURLs: [URL] { selectedEntries.map(\.url) }
    var keyboardEntries: [FileEntry] {
        if !query.isEmpty { return sorted(searchResults) }
        if let index = keyboardColumn, columns.indices.contains(index) { return sorted(columns[index].entries) }
        return currentEntries
    }

    func focusFiles() { keyboardView?.window?.makeFirstResponder(keyboardView) }

    func select(_ entry: FileEntry, column index: Int?, modifiers: NSEvent.ModifierFlags = [], navigateFolder: Bool = true) {
        let entries = index.flatMap { columns.indices.contains($0) ? sorted(columns[$0].entries) : nil } ?? sorted(searchResults)
        if modifiers.contains(.shift), let anchor = selectionAnchor,
           let start = entries.firstIndex(where: { $0.id == anchor }), let end = entries.firstIndex(where: { $0.id == entry.id }) {
            selectedEntries = Array(entries[min(start, end)...max(start, end)])
        } else if modifiers.contains(.command) {
            if selectedEntries.contains(where: { $0.id == entry.id }) { selectedEntries.removeAll { $0.id == entry.id } }
            else { selectedEntries.append(entry) }
            selectionAnchor = entry.id
        } else {
            if entry.isNavigable && navigateFolder {
                navigate(to: entry.navigationURL, fromColumn: index)
                if viewMode != .columns {
                    keyboardColumn = columns.count - 1
                    focusFiles(); previews.update([]); return
                }
            }
            selectedEntries = [entry]; selectionAnchor = entry.id
        }
        selectionLead = entry.id
        keyboardColumn = index
        focusFiles()
        previews.update(selectedURLs)
    }

    func selectAllFiles() { selectedEntries = keyboardEntries; selectionAnchor = selectedEntries.first?.id; selectionLead = selectedEntries.last?.id; previews.update(selectedURLs) }

    func selectRelative(_ delta: Int, extend: Bool) {
        let entries = keyboardEntries
        guard !entries.isEmpty else { return }
        let previous = selection.flatMap { item in entries.firstIndex { $0.id == item.id } } ?? (delta > 0 ? -1 : entries.count)
        let next = entries[min(max(previous + delta, 0), entries.count - 1)]
        select(next, column: keyboardColumn ?? (query.isEmpty ? columns.count - 1 : nil), modifiers: extend ? .shift : [], navigateFolder: false)
    }

    func contextItems(_ entry: FileEntry) -> [FileEntry] {
        selectedEntries.contains(where: { $0.id == entry.id }) ? selectedEntries : [entry]
    }

    func copyItems(_ items: [FileEntry]? = nil, cut: Bool = false) {
        let urls = (items ?? selectedEntries).map(\.url)
        guard !urls.isEmpty else { return }
        FileClipboard.write(urls)
        cutChangeCount = cut ? NSPasteboard.general.changeCount : nil
        focusFiles()
    }

    func pasteFiles(move: Bool = false, into directory: URL? = nil) {
        let sources = FileClipboard.read()
        let cut = cutChangeCount == NSPasteboard.general.changeCount
        transfer(sources, to: directory ?? currentDirectory, move: move || cut)
    }

    func transfer(_ urls: [URL], to directory: URL, move: Bool) {
        guard !urls.isEmpty, !isWorking else { return }
        isChoosingTransfer = true
        let mode: FileTransferMode = move ? .move : .copy
        Task {
            let collisions = await operations.service.collisions(urls, in: directory, mode: mode)
            let policy = collisions.isEmpty ? FileConflictPolicy.keepBoth : conflictPolicy(collisions)
            isChoosingTransfer = false
            guard let policy else { return }
            operations.perform(move ? "이동" : "복사", action: { await $0.transfer(urls, to: directory, mode: mode, policy: policy) }) { [weak self] result in
                self?.didComplete(result)
                if move && self?.cutChangeCount == NSPasteboard.general.changeCount {
                    let remaining = urls.filter { (try? FileManager.default.attributesOfItem(atPath: $0.path)) != nil }
                    FileClipboard.write(remaining)
                    self?.cutChangeCount = remaining.isEmpty ? nil : NSPasteboard.general.changeCount
                }
            }
        }
    }

    private func conflictPolicy(_ urls: [URL]) -> FileConflictPolicy? {
        let alert = NSAlert()
        alert.messageText = "같은 이름의 항목이 \(urls.count)개 있습니다"
        alert.informativeText = urls.prefix(5).map(\.lastPathComponent).joined(separator: "\n")
            + "\n\n대치는 기존 항목을 휴지통에 보관하며 실행 취소할 수 있습니다."
        ["둘 다 유지", "대치", "건너뛰기", "취소"].forEach { alert.addButton(withTitle: $0) }
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .keepBoth
        case .alertSecondButtonReturn: return .replace
        case .alertThirdButtonReturn: return .skip
        default: return nil
        }
    }

    func chooseDestination(_ items: [FileEntry]? = nil, move: Bool) {
        let urls = (items ?? selectedEntries).map(\.url)
        guard !urls.isEmpty, !isWorking else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.directoryURL = currentDirectory; panel.prompt = move ? "여기로 이동" : "여기로 복사"
        if panel.runModal() == .OK, let destination = panel.url {
            do {
                try folderAccess.remember(destination)
                transfer(urls, to: destination, move: move)
            } catch { errorMessage = "대상 폴더 접근 권한을 저장할 수 없습니다.\n\(error.localizedDescription)" }
        }
    }

    func duplicateItems(_ items: [FileEntry]? = nil) {
        let urls = (items ?? selectedEntries).map(\.url)
        guard !urls.isEmpty else { return }
        operations.perform("복제", action: { await $0.duplicate(urls) }, completion: didComplete)
    }

    func trashItems(_ items: [FileEntry]? = nil) {
        let urls = (items ?? selectedEntries).map(\.url)
        guard !urls.isEmpty else { return }
        operations.perform("휴지통으로 이동", action: { await $0.moveToTrash(urls) }, completion: didComplete)
    }

    func beginNewFolder(withSelection: Bool = false) {
        guard !isWorking else { return }
        let parents = Set(selectedURLs.map { $0.deletingLastPathComponent().standardizedFileURL })
        let directory = withSelection && parents.count == 1 ? parents.first! : currentDirectory
        nameInput = availableNewName("새 폴더", in: directory)
        namePrompt = FileNamePrompt(title: withSelection ? "선택 항목으로 새 폴더" : "새 폴더", kind: withSelection ? .folderWithItems(selectedURLs) : .folder, directory: directory)
    }

    func beginNewTextFile() {
        guard !isWorking else { return }
        nameInput = availableNewName("새 파일", extension: ".txt")
        namePrompt = FileNamePrompt(title: "새 텍스트 파일", kind: .text, directory: currentDirectory)
    }

    private func availableNewName(_ stem: String, extension tail: String = "", in directory: URL? = nil) -> String {
        var name = stem + tail, index = 2
        while (try? FileManager.default.attributesOfItem(atPath: (directory ?? currentDirectory).appendingPathComponent(name).path)) != nil {
            name = stem + " \(index)" + tail; index += 1
        }
        return name
    }

    func beginRename(_ entry: FileEntry? = nil) {
        guard !isWorking else { return }
        if selectedEntries.count > 1, entry == nil {
            batchRenameSelection = FileInfoSelection(entries: selectedEntries); return
        }
        guard !isWorking, let item = entry ?? selection else { return }
        nameInput = item.name
        namePrompt = FileNamePrompt(title: "이름 변경", kind: .rename(item.url), directory: item.url.deletingLastPathComponent())
    }

    func submitBatchRename(_ plan: [(URL, String)]) {
        batchRenameSelection = nil
        operations.perform("이름 일괄 변경", action: { await $0.renameBatch(plan) }, completion: didComplete)
        focusFiles()
    }

    func submitNamePrompt() {
        guard let prompt = namePrompt else { return }
        let name = nameInput
        namePrompt = nil
        switch prompt.kind {
        case .folder, .text:
            let folder: Bool = if case .folder = prompt.kind { true } else { false }
            operations.perform(prompt.title, action: { await $0.create(in: prompt.directory, name: name, folder: folder) }, completion: didComplete)
        case .rename(let source):
            operations.perform(prompt.title, action: { await $0.rename(source, name: name) }, completion: didComplete)
        case .folderWithItems(let urls):
            operations.perform(prompt.title, action: { service in
                var result = await service.create(in: prompt.directory, name: name, folder: true)
                guard let folder = result.affected.first else { return result }
                let moved = await service.transfer(urls, to: folder, mode: .move, policy: .keepBoth)
                result.inverse = moved.inverse + result.inverse
                result.issues += moved.issues
                result.relocations += moved.relocations
                return result
            }, completion: didComplete)
        }
        focusFiles()
    }

    func aliasItems(_ items: [FileEntry]? = nil) {
        let urls = (items ?? selectedEntries).map(\.url), directory = currentDirectory
        operations.perform("가상본 만들기", action: { await $0.makeAliases(urls, in: directory) }, completion: didComplete)
    }

    func compressItems(_ items: [FileEntry]? = nil) {
        let urls = (items ?? selectedEntries).map(\.url), directory = currentDirectory
        operations.perform("압축", action: { await $0.compress(urls, in: directory) }, completion: didComplete)
    }

    func undoFiles() { operations.undo(completion: didComplete) }
    func redoFiles() { operations.redo(completion: didComplete) }
    func setPermissions(_ url: URL, value: Int) {
        guard !isWorking else { return }
        infoSelection = nil
        operations.perform("접근 권한 변경", action: { await $0.setPermissions(url, value: value) }, completion: didComplete)
    }
    func setLocked(_ url: URL, value: Bool) {
        guard !isWorking else { return }
        infoSelection = nil
        operations.perform(value ? "파일 잠금" : "파일 잠금 해제", action: { await $0.setLocked(url, value: value) }, completion: didComplete)
    }

    private func didComplete(_ result: FileOperationResult) {
        for (from, to) in result.relocations {
            let oldPath = PathUtilities.relocationPath(from)
            let logicalPath = PathUtilities.relocationPath(currentDirectory)
            let physicalPath = physicalDirectory?.path ?? logicalPath
            let currentPath = physicalPath == oldPath || physicalPath.hasPrefix(oldPath + "/") ? physicalPath : logicalPath
            if currentPath == oldPath || currentPath.hasPrefix(oldPath + "/") {
                let suffix = String(currentPath.dropFirst(oldPath.count))
                navigate(to: URL(fileURLWithPath: PathUtilities.relocationPath(to) + suffix, isDirectory: true))
            }
        }
        pendingSelectionURLs = result.affected.filter { $0.deletingLastPathComponent().standardizedFileURL.path == currentDirectory.standardizedFileURL.path }
        if !FileManager.default.fileExists(atPath: currentDirectory.path) {
            var directory = currentDirectory
            while directory.path != "/" && !FileManager.default.fileExists(atPath: directory.path) { directory.deleteLastPathComponent() }
            navigate(to: directory)
        } else { refresh() }
        if !result.issues.isEmpty { errorMessage = result.issues.joined(separator: "\n") }
    }

    func openSelection() { for item in selectedEntries { open(item, fromColumn: keyboardColumn) } }
    func previewItems(_ items: [FileEntry]? = nil) {
        focusFiles(); previews.toggle((items ?? selectedEntries).map(\.url))
    }
    func showInfo(_ items: [FileEntry]? = nil) {
        let entries = items ?? selectedEntries
        if !entries.isEmpty { infoSelection = FileInfoSelection(entries: entries) }
    }
    func beginTags(_ items: [FileEntry]? = nil) {
        let entries = items ?? selectedEntries
        guard !entries.isEmpty else { return }
        tagInput = entries.count == 1 ? entries[0].tags.joined(separator: ", ") : ""
        tagLabel = entries.count == 1 ? entries[0].labelNumber : 0
        appendTags = entries.count > 1
        tagSelection = FileInfoSelection(entries: entries)
    }
    func submitTags() {
        guard let selected = tagSelection else { return }
        let urls = selected.entries.map(\.url), label = tagLabel, append = appendTags
        let names = Array(Set(tagInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        tagSelection = nil
        operations.perform("태그 변경", action: { await $0.setTags(urls, names: names, label: label, append: append) }, completion: didComplete)
    }
    func applications(for entry: FileEntry) -> [URL] {
        let key = entry.url.pathExtension
        if let cached = applicationCache[key] { return cached }
        let apps = Array(NSWorkspace.shared.urlsForApplications(toOpen: entry.url).prefix(12))
        applicationCache[key] = apps
        return apps
    }
    func open(_ urls: [URL], with application: URL) {
        NSWorkspace.shared.open(urls, withApplicationAt: application, configuration: .init()) { [weak self] _, error in
            if let message = error?.localizedDescription { Task { @MainActor in self?.errorMessage = message } }
        }
    }
    func chooseApplication(for items: [FileEntry]) {
        let panel = NSOpenPanel(); panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        if panel.runModal() == .OK, let app = panel.url { open(items.map(\.url), with: app) }
    }
    func shareItems(_ items: [FileEntry]? = nil) {
        let urls = (items ?? selectedEntries).map(\.url)
        guard !urls.isEmpty, let view = NSApp.keyWindow?.contentView else { return }
        sharingPicker = NSSharingServicePicker(items: urls)
        sharingPicker?.show(relativeTo: NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1), of: view, preferredEdge: .maxY)
    }
    func copySelectedPaths(_ items: [FileEntry]? = nil) {
        let urls = (items ?? selectedEntries).map(\.url)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
    }
}
