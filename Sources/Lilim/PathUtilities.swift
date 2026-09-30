import Foundation
import Darwin

enum PathUtilities {
    static var userHome: URL {
        // Foundation can return the app container in a sandbox. Resolve the
        // actual account home for path entry and system folder-picker hints.
        var account = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: 16_384)
        return buffer.withUnsafeMutableBufferPointer { bytes in
            let status = getpwuid_r(getuid(), &account, bytes.baseAddress, bytes.count, &result)
            guard status == 0, result != nil, let path = account.pw_dir else {
                return FileManager.default.homeDirectoryForCurrentUser
            }
            return URL(fileURLWithPath: String(cString: path), isDirectory: true)
        }
    }
    // A moved path no longer exists, so realpath cannot resolve it as a whole.
    // Resolve its nearest existing parent and keep the missing suffix intact.
    static func relocationPath(_ url: URL) -> String {
        guard url.path != "/" else { return "/" }
        var ancestor = url.deletingLastPathComponent()
        var suffix = [url.lastPathComponent]
        while ancestor.path != "/" && !FileManager.default.fileExists(atPath: ancestor.path) {
            suffix.insert(ancestor.lastPathComponent, at: 0)
            ancestor.deleteLastPathComponent()
        }
        return suffix.reduce(ancestor.resolvingSymlinksInPath()) { $0.appendingPathComponent($1) }.path
    }
    static func displayPath(_ url: URL) -> String {
        let home = userHome.path
        let value = url.standardizedFileURL.path
        if value == home { return "~" }
        if value.hasPrefix(home + "/") { return "~" + value.dropFirst(home.count) }
        return value
    }

    static func resolve(_ input: String, relativeTo directory: URL) -> URL {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value == "~" { return userHome }
        if value.hasPrefix("~/") { return userHome.appendingPathComponent(String(value.dropFirst(2))).standardizedFileURL }
        let expanded = NSString(string: value).expandingTildeInPath
        if expanded.hasPrefix("/") { return URL(fileURLWithPath: expanded).standardizedFileURL }
        return directory.appendingPathComponent(expanded).standardizedFileURL
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func breadcrumbs(for url: URL) -> [URL] {
        var result = [url.standardizedFileURL]
        while let first = result.first, first.path != "/" {
            result.insert(first.deletingLastPathComponent(), at: 0)
        }
        return result
    }
}
