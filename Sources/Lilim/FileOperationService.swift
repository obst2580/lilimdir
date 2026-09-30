import Foundation

// Disk work is serialized off the UI actor. Every destructive step uses the
// system Trash and records its returned URL, including replaced destinations.
actor FileOperationService {
    private let manager = FileManager()

    func collisions(_ sources: [URL], in directory: URL, mode: FileTransferMode) -> [URL] {
        topLevel(sources).compactMap { source in
            let target = directory.appendingPathComponent(source.lastPathComponent)
            return exists(target) && !sameLocation(source, target) ? target : nil
        }
    }

    func transfer(_ sources: [URL], to directory: URL, mode: FileTransferMode,
                  policy: FileConflictPolicy = .keepBoth) -> FileOperationResult {
        var result = FileOperationResult()
        for source in topLevel(sources) {
            if Task.isCancelled { result.issues.append("작업을 중단했습니다. 완료된 항목은 실행 취소할 수 있습니다."); break }
            var backup: (original: URL, trash: URL)?
            do {
                try validate(source: source, destination: directory)
                var target = directory.appendingPathComponent(source.lastPathComponent)
                if sameLocation(source, target) {
                    if mode == .move { continue }
                    target = uniqueURL(target, suffix: " 복사본")
                } else if exists(target) {
                    switch policy {
                    case .skip: continue
                    case .abort: throw FileOperationError.collision(target)
                    case .keepBoth: target = uniqueURL(target)
                    case .replace: backup = (target, try trash(target))
                    }
                }
                if mode == .copy { try copyAtomically(source, to: target) }
                else { try manager.moveItem(at: source, to: target) }
                var undo: [FileStep] = [mode == .copy ? .trash(target) : .move(target, source)]
                if let backup { undo.append(.move(backup.trash, backup.original)) }
                result.inverse.insert(contentsOf: undo, at: 0)
                result.affected.append(target)
                if mode == .move { result.relocations.append((source, target)) }
            } catch {
                if let backup {
                    let target = backup.original
                    do {
                        guard !exists(target) else { throw FileOperationError.collision(target) }
                        try manager.moveItem(at: backup.trash, to: target)
                    } catch {
                        result.inverse.insert(.move(backup.trash, target), at: 0)
                        result.issues.append("대치 전 항목은 휴지통에 보관되어 있습니다: \(backup.trash.path)")
                    }
                }
                result.issues.append("\(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return result
    }

    func duplicate(_ sources: [URL]) -> FileOperationResult {
        var result = FileOperationResult()
        for source in topLevel(sources) {
            if Task.isCancelled { result.issues.append("작업을 중단했습니다. 완료된 항목은 실행 취소할 수 있습니다."); break }
            do {
                let target = uniqueURL(source, suffix: " 복사본")
                try copyAtomically(source, to: target)
                result.affected.append(target)
                result.inverse.insert(.trash(target), at: 0)
            } catch { result.issues.append("\(source.lastPathComponent): \(error.localizedDescription)") }
        }
        return result
    }

    func moveToTrash(_ sources: [URL]) -> FileOperationResult {
        var result = FileOperationResult()
        for source in topLevel(sources) {
            if Task.isCancelled { result.issues.append("작업을 중단했습니다. 완료된 항목은 실행 취소할 수 있습니다."); break }
            do {
                guard source.standardizedFileURL.path != "/" else { throw FileOperationError.selfTransfer }
                let trashed = try trash(source)
                result.affected.append(trashed)
                result.inverse.insert(.move(trashed, source), at: 0)
            } catch { result.issues.append("\(source.lastPathComponent): \(error.localizedDescription)") }
        }
        return result
    }

    func create(in directory: URL, name: String, folder: Bool) -> FileOperationResult {
        var result = FileOperationResult()
        do {
            try validateName(name)
            let target = directory.appendingPathComponent(name, isDirectory: folder)
            guard !exists(target) else { throw FileOperationError.collision(target) }
            if folder { try manager.createDirectory(at: target, withIntermediateDirectories: false) }
            else { try Data().write(to: target, options: .withoutOverwriting) }
            result.affected = [target]; result.inverse = [.trash(target)]
        } catch { result.issues = [error.localizedDescription] }
        return result
    }

    func rename(_ source: URL, name: String) -> FileOperationResult {
        var result = FileOperationResult()
        do {
            guard source.standardizedFileURL.path != "/" else { throw FileOperationError.selfTransfer }
            try validateName(name)
            let target = source.deletingLastPathComponent().appendingPathComponent(name)
            if source.path == target.path { return result }
            if exists(target) && !isCaseOnlyRename(source, target) { throw FileOperationError.collision(target) }
            try manager.moveItem(at: source, to: target)
            result.affected = [target]; result.inverse = [.move(target, source)]
            result.relocations = [(source, target)]
        } catch { result.issues = [error.localizedDescription] }
        return result
    }

    func renameBatch(_ plan: [(URL, String)]) -> FileOperationResult {
        var result = FileOperationResult()
        let allowed = Set(topLevel(plan.map { $0.0 }))
        let items = plan.filter { allowed.contains($0.0.standardizedFileURL) }
        do {
            var targets = Set<String>()
            for (source, name) in items {
                try validateName(name)
                guard exists(source) else { throw FileOperationError.missing(source) }
                let target = source.deletingLastPathComponent().appendingPathComponent(name)
                let key = target.path.precomposedStringWithCanonicalMapping.lowercased()
                guard targets.insert(key).inserted else { throw FileOperationError.collision(target) }
                if exists(target) && !sameLocation(source, target) { throw FileOperationError.collision(target) }
            }
        } catch { result.issues = [error.localizedDescription]; return result }
        for (source, name) in items {
            if Task.isCancelled { result.issues.append("이름 변경을 중단했습니다."); break }
            let changed = rename(source, name: name)
            result.affected += changed.affected
            result.inverse.insert(contentsOf: changed.inverse, at: 0)
            result.issues += changed.issues
            result.relocations += changed.relocations
            if !changed.issues.isEmpty { break }
        }
        return result
    }

    func makeAliases(_ sources: [URL], in directory: URL) -> FileOperationResult {
        var result = FileOperationResult()
        for source in Array(Set(sources.map(\.standardizedFileURL))).sorted(by: { $0.path < $1.path }) {
            if Task.isCancelled { result.issues.append("작업을 중단했습니다."); break }
            do {
                let target = uniqueURL(directory.appendingPathComponent(source.lastPathComponent + " 가상본"))
                let data = try source.bookmarkData(options: .suitableForBookmarkFile)
                try URL.writeBookmarkData(data, to: target)
                result.affected.append(target); result.inverse.insert(.trash(target), at: 0)
            } catch { result.issues.append("\(source.lastPathComponent): \(error.localizedDescription)") }
        }
        return result
    }

    func setTags(_ sources: [URL], names: [String], label: Int, append: Bool = false) -> FileOperationResult {
        var result = FileOperationResult()
        for source in Array(Set(sources.map(\.standardizedFileURL))).sorted(by: { $0.path < $1.path }) {
            if Task.isCancelled { result.issues.append("작업을 중단했습니다."); break }
            do {
                let previous = try FileTagSnapshot.read(source)
                let oldNames = previous.names, oldLabel = previous.label
                let newNames = append ? Array(Set(oldNames + names)).sorted() : names
                let newLabel = append && label == 0 ? oldLabel : label
                do {
                    try (source as NSURL).setResourceValue(newNames, forKey: .tagNamesKey)
                    try (source as NSURL).setResourceValue(newLabel, forKey: .labelNumberKey)
                } catch {
                    do { try previous.restore(source) }
                    catch { result.inverse.insert(.tags(source, previous), at: 0) }
                    throw error
                }
                result.affected.append(source)
                result.inverse.insert(.tags(source, previous), at: 0)
            } catch { result.issues.append("\(source.lastPathComponent): \(error.localizedDescription)") }
        }
        return result
    }

    func compress(_ sources: [URL], in directory: URL) -> FileOperationResult {
        var result = FileOperationResult()
        let items = topLevel(sources)
        guard !items.isEmpty else { return result }
        let staging = manager.temporaryDirectory.appendingPathComponent("Lilim-Archive-\(UUID())")
        do {
            try manager.createDirectory(at: staging, withIntermediateDirectories: false)
            defer { try? manager.removeItem(at: staging) }
            for source in items {
                try Task.checkCancellation()
                let target = uniqueURL(staging.appendingPathComponent(source.lastPathComponent))
                try manager.copyItem(at: source, to: target)
            }
            let name = items.count == 1 ? items[0].lastPathComponent : "아카이브"
            let archive = uniqueURL(directory.appendingPathComponent(name + ".zip"))
            let temporaryArchive = staging.appendingPathComponent(UUID().uuidString + ".zip")
            let names = try manager.contentsOfDirectory(atPath: staging.path)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.arguments = ["-q", "-r", "-y", temporaryArchive.path, "--"] + names
            process.currentDirectoryURL = staging
            process.standardOutput = FileHandle.nullDevice
            let errors = Pipe(); process.standardError = errors
            try process.run()
            let errorData = errors.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "LilimArchive", code: Int(process.terminationStatus),
                              userInfo: [NSLocalizedDescriptionKey: String(decoding: errorData, as: UTF8.self)])
            }
            try manager.moveItem(at: temporaryArchive, to: archive)
            result.affected = [archive]; result.inverse = [.trash(archive)]
        } catch { result.issues = [error.localizedDescription] }
        return result
    }

    func setPermissions(_ url: URL, value: Int) -> FileOperationResult {
        var result = FileOperationResult()
        do {
            guard (0...0o777).contains(value), url.standardizedFileURL.path != "/" else { throw FileOperationError.selfTransfer }
            let old = (try manager.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue ?? 0
            try manager.setAttributes([.posixPermissions: (old & ~0o777) | value], ofItemAtPath: url.path)
            result.affected = [url]; result.inverse = [.permissions(url, old & 0o777)]
        } catch { result.issues = [error.localizedDescription] }
        return result
    }

    func setLocked(_ url: URL, value: Bool) -> FileOperationResult {
        var result = FileOperationResult()
        do {
            guard url.standardizedFileURL.path != "/" else { throw FileOperationError.selfTransfer }
            let old = (try manager.attributesOfItem(atPath: url.path)[.immutable] as? NSNumber)?.boolValue ?? false
            try manager.setAttributes([.immutable: value], ofItemAtPath: url.path)
            result.affected = [url]; result.inverse = [.locked(url, old)]
        } catch { result.issues = [error.localizedDescription] }
        return result
    }

    func apply(_ steps: [FileStep]) -> FileOperationResult {
        var result = FileOperationResult()
        for (index, step) in steps.enumerated() {
            if Task.isCancelled {
                result.remaining = Array(steps[index...]); result.issues.append("작업을 중단했습니다."); break
            }
            do {
                switch step {
                case .move(let from, let to):
                    guard exists(from) else { throw FileOperationError.missing(from) }
                    guard !exists(to) || isCaseOnlyRename(from, to) else { throw FileOperationError.collision(to) }
                    try manager.moveItem(at: from, to: to)
                    result.inverse.insert(.move(to, from), at: 0); result.affected.append(to)
                    result.relocations.append((from, to))
                case .trash(let url):
                    let location = try trash(url)
                    result.inverse.insert(.move(location, url), at: 0); result.affected.append(location)
                case .tags(let url, let snapshot):
                    let previous = try FileTagSnapshot.read(url)
                    do { try snapshot.restore(url) }
                    catch {
                        do { try previous.restore(url) }
                        catch { result.inverse.insert(.tags(url, previous), at: 0) }
                        throw error
                    }
                    result.inverse.insert(.tags(url, previous), at: 0); result.affected.append(url)
                case .permissions(let url, let value):
                    let changes = setPermissions(url, value: value)
                    if let issue = changes.issues.first { throw NSError(domain: "LilimPermissions", code: 1, userInfo: [NSLocalizedDescriptionKey: issue]) }
                    result.inverse.insert(contentsOf: changes.inverse, at: 0); result.affected.append(url)
                case .locked(let url, let value):
                    let changes = setLocked(url, value: value)
                    if let issue = changes.issues.first { throw NSError(domain: "LilimLocked", code: 1, userInfo: [NSLocalizedDescriptionKey: issue]) }
                    result.inverse.insert(contentsOf: changes.inverse, at: 0); result.affected.append(url)
                }
            } catch {
                result.issues.append(error.localizedDescription)
                result.remaining = Array(steps[index...])
                break
            }
        }
        return result
    }

    func topLevel(_ urls: [URL]) -> [URL] {
        let unique = Array(Set(urls.map(\.standardizedFileURL))).sorted { $0.path < $1.path }
        return unique.filter { item in
            !unique.contains { parent in
                parent != item && (try? manager.attributesOfItem(atPath: parent.path)[.type] as? FileAttributeType) == .typeDirectory
                    && item.path.hasPrefix(parent.path + "/")
            }
        }
    }

    private func validateName(_ name: String) throws {
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"),
              !name.contains("\0"), !name.contains("\n"), !name.contains("\r") else { throw FileOperationError.invalidName }
    }

    private func validate(source: URL, destination: URL) throws {
        guard exists(source) else { throw FileOperationError.missing(source) }
        guard source.standardizedFileURL.path != "/" else { throw FileOperationError.selfTransfer }
        if (try manager.attributesOfItem(atPath: source.path)[.type] as? FileAttributeType) == .typeDirectory {
            let a = source.resolvingSymlinksInPath().standardizedFileURL.path
            let b = destination.resolvingSymlinksInPath().standardizedFileURL.path
            guard a != b && !b.hasPrefix(a + "/") else { throw FileOperationError.selfTransfer }
        }
    }

    private func exists(_ url: URL) -> Bool { (try? manager.attributesOfItem(atPath: url.path)) != nil }

    private func sameLocation(_ a: URL, _ b: URL) -> Bool {
        if a.standardizedFileURL.path == b.standardizedFileURL.path { return true }
        guard let x = try? manager.attributesOfItem(atPath: a.path), let y = try? manager.attributesOfItem(atPath: b.path) else { return false }
        return (x[.systemNumber] as? NSNumber) == (y[.systemNumber] as? NSNumber)
            && (x[.systemFileNumber] as? NSNumber) == (y[.systemFileNumber] as? NSNumber)
    }

    private func isCaseOnlyRename(_ from: URL, _ to: URL) -> Bool {
        from.path != to.path && from.path.lowercased() == to.path.lowercased() && sameLocation(from, to)
    }

    private func uniqueURL(_ proposed: URL, suffix: String = "") -> URL {
        let values = try? proposed.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        let directory = values?.isDirectory == true && values?.isPackage != true
        let ext = directory ? "" : proposed.pathExtension
        let stem = ext.isEmpty ? proposed.lastPathComponent : proposed.deletingPathExtension().lastPathComponent
        let tail = ext.isEmpty ? "" : "." + ext
        var index = suffix.isEmpty ? 2 : 1
        var candidate = suffix.isEmpty ? proposed : proposed.deletingLastPathComponent().appendingPathComponent(stem + suffix + tail)
        while exists(candidate) {
            candidate = proposed.deletingLastPathComponent().appendingPathComponent(stem + suffix + " \(index)" + tail)
            index += 1
        }
        return candidate
    }

    private func trash(_ url: URL) throws -> URL {
        var result: NSURL?
        try manager.trashItem(at: url, resultingItemURL: &result)
        guard let result else { throw FileOperationError.missing(url) }
        return result as URL
    }

    private func copyAtomically(_ source: URL, to target: URL) throws {
        let staging = target.deletingLastPathComponent().appendingPathComponent(".Lilim-Copy-\(UUID())")
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: staging) }
        let item = staging.appendingPathComponent(source.lastPathComponent)
        try manager.copyItem(at: source, to: item)
        try manager.moveItem(at: item, to: target)
    }
}
