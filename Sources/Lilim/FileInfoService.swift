import Foundation

struct FileInfoDetails: Sendable {
    var bytes: Int64 = 0
    var files = 0
    var owner = ""
    var permissions = ""
    var locked = false
    var error: String?
}

actor FileInfoService {
    func details(_ urls: [URL]) -> FileInfoDetails {
        var result = FileInfoDetails()
        let manager = FileManager()
        do {
            for url in urls {
                try Task.checkCancellation()
                let attributes = try manager.attributesOfItem(atPath: url.path)
                result.owner = attributes[.ownerAccountName] as? String ?? ""
                result.permissions = String(format: "%03o", (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0)
                result.locked = (attributes[.immutable] as? NSNumber)?.boolValue ?? false
                if attributes[.type] as? FileAttributeType == .typeDirectory {
                    if let enumerator = manager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey]) {
                        for case let child as URL in enumerator {
                            try Task.checkCancellation()
                            let values = try child.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .isSymbolicLinkKey])
                            if values.isSymbolicLink == true { enumerator.skipDescendants() }
                            if values.isDirectory != true { result.bytes += Int64(values.fileSize ?? 0); result.files += 1 }
                        }
                    }
                } else { result.bytes += (attributes[.size] as? NSNumber)?.int64Value ?? 0; result.files += 1 }
            }
        } catch is CancellationError { }
        catch { result.error = error.localizedDescription }
        return result
    }
}
