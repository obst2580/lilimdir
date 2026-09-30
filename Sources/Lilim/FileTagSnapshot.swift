import Foundation
import Darwin

struct FileTagSnapshot: Sendable {
    let names: [String]
    let label: Int
    let metadata: Data?
    let supportsMetadata: Bool
    private static let attribute = "com.apple.metadata:_kMDItemUserTags"

    static func read(_ url: URL) throws -> FileTagSnapshot {
        let values = try url.resourceValues(forKeys: [.tagNamesKey, .labelNumberKey])
        let size = getxattr(url.path, attribute, nil, 0, 0, XATTR_NOFOLLOW)
        if size < 0 {
            guard errno == ENOATTR || errno == ENOTSUP else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
            return FileTagSnapshot(names: values.tagNames ?? [], label: values.labelNumber ?? 0, metadata: nil, supportsMetadata: errno != ENOTSUP)
        }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(url.path, attribute, $0.baseAddress, size, 0, XATTR_NOFOLLOW) }
        guard read >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        data.count = read
        return FileTagSnapshot(names: values.tagNames ?? [], label: values.labelNumber ?? 0, metadata: data, supportsMetadata: true)
    }

    func restore(_ url: URL) throws {
        try (url as NSURL).setResourceValue(names, forKey: .tagNamesKey)
        try (url as NSURL).setResourceValue(label, forKey: .labelNumberKey)
        guard supportsMetadata else { return }
        let status: Int32
        if let metadata {
            status = metadata.withUnsafeBytes { setxattr(url.path, Self.attribute, $0.baseAddress, metadata.count, 0, XATTR_NOFOLLOW) }
        } else {
            status = removexattr(url.path, Self.attribute, XATTR_NOFOLLOW)
            if status < 0 && errno == ENOATTR { return }
        }
        guard status == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
    }
}
