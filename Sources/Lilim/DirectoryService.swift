import Foundation

actor DirectoryService {
    private let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
        .fileSizeKey, .contentModificationDateKey, .creationDateKey,
        .localizedTypeDescriptionKey, .tagNamesKey, .labelNumberKey, .isAliasFileKey
    ]

    func contents(of directory: URL, showHidden: Bool) throws -> [FileEntry] {
        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys), options: options
        )
        return try urls.compactMap { url in
            try Task.checkCancellation()
            return try? entry(at: url)
        }.sorted(by: Self.precedes)
    }

    func search(in directory: URL, query: String, showHidden: Bool) throws -> (entries: [FileEntry], truncated: Bool) {
        let options: FileManager.DirectoryEnumerationOptions = showHidden
            ? [.skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants]
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: Array(keys), options: options
        ) else { return ([], false) }
        let skipped = Set(["node_modules", ".git", ".build", "Library", "Pods", "DerivedData", ".cache"])
        var results: [FileEntry] = []
        var scanned = 0
        var truncated = false
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            scanned += 1
            if scanned > 25_000 || results.count >= 200 {
                truncated = true
                break
            }
            guard let item = try? entry(at: url) else { continue }
            if item.isDirectory && (skipped.contains(item.name) || item.isSymbolicLink) {
                enumerator.skipDescendants()
            }
            if item.name.localizedStandardContains(query) { results.append(item) }
        }
        return (results.sorted(by: Self.precedes), truncated)
    }

    private func entry(at url: URL) throws -> FileEntry {
        let values = try url.resourceValues(forKeys: keys)
        // Resource values describe the link itself. Classify its destination
        // so a folder link stays in the explorer instead of opening in Finder.
        let linkValues = values.isSymbolicLink == true
            ? try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) : nil
        let target = values.isAliasFile == true ? try? URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting]) : nil
        let targetDirectory = (try? target?.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]))
        return FileEntry(
            url: url, isDirectory: values.isDirectory == true || linkValues?.isDirectory == true,
            isPackage: values.isPackage == true || linkValues?.isPackage == true,
            isSymbolicLink: values.isSymbolicLink ?? false,
            size: Int64(values.fileSize ?? 0), modifiedAt: values.contentModificationDate,
            createdAt: values.creationDate, kind: values.localizedTypeDescription ?? "파일",
            tags: values.tagNames ?? [], labelNumber: values.labelNumber ?? 0,
            isAlias: values.isAliasFile ?? false, aliasTarget: target,
            aliasTargetIsDirectory: targetDirectory?.isDirectory == true && targetDirectory?.isPackage != true
        )
    }

    private static func precedes(_ lhs: FileEntry, _ rhs: FileEntry) -> Bool {
        if lhs.isNavigable != rhs.isNavigable { return lhs.isNavigable }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
