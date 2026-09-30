import Foundation

/// Keeps user-selected folder access alive for sessions, asynchronous file work,
/// and undo records. All access is released when the app exits.
@MainActor
final class FolderAccess {
    static var isSandboxBuild: Bool {
        #if LILIM_APP_STORE
        true
        #else
        false
        #endif
    }

    static var userHome: URL {
        PathUtilities.userHome
    }

    private let defaults: UserDefaults
    private let enabled: Bool
    private let key = "authorizedFolderBookmarks"
    private var bookmarks: [String: Data] = [:]
    private var restored: [String: URL] = [:]
    private var active: [URL] = []
    var hasRestoredFolders: Bool { !restored.isEmpty }

    init(defaults: UserDefaults, enabled: Bool = FolderAccess.isSandboxBuild) {
        self.defaults = defaults
        self.enabled = enabled
        guard enabled else { return }
        bookmarks = defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
        for (path, data) in bookmarks {
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                  bookmarkDataIsStale: &stale)
                guard url.startAccessingSecurityScopedResource() else { continue }
                active.append(url)
                restored[path] = url
                if stale { bookmarks[path] = try url.bookmarkData(options: .withSecurityScope) }
            } catch {
                // Keep the saved reference so a disconnected volume can return.
                // Navigation will request access again when restoration fails.
            }
        }
        defaults.set(bookmarks, forKey: key)
    }

    func remember(_ url: URL) throws {
        guard enabled else { return }
        let started = url.startAccessingSecurityScopedResource()
        do {
            let data = try url.bookmarkData(options: .withSecurityScope)
            if started { active.append(url) }
            bookmarks[url.standardizedFileURL.path] = data
            restored[url.standardizedFileURL.path] = url
            defaults.set(bookmarks, forKey: key)
        } catch {
            if started { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    func resolve(_ url: URL) -> URL {
        let path = url.standardizedFileURL.path
        for (oldPath, current) in restored.sorted(by: { $0.key.count > $1.key.count }) {
            if path == oldPath { return current }
            if path.hasPrefix(oldPath + "/") {
                return current.appendingPathComponent(String(path.dropFirst(oldPath.count + 1)))
            }
        }
        return url
    }

    func canNavigate(_ url: URL) -> Bool {
        guard enabled else { return true }
        let target = url.standardizedFileURL.path
        let container = NSHomeDirectory()
        if target == container || target.hasPrefix(container + "/") { return true }
        if target == "/" || target == "/Applications" { return true }
        return restored.values.contains {
            let root = $0.standardizedFileURL.path
            return target == root || target.hasPrefix(root == "/" ? "/" : root + "/")
        }
    }

    isolated deinit { active.forEach { $0.stopAccessingSecurityScopedResource() } }
}
