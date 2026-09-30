import AppKit
import Observation

@MainActor @Observable
final class BrowserState {
    var currentDirectory: URL
    var columns: [BrowserColumn] = []
    var selectedEntries: [FileEntry] = []
    var selection: FileEntry? {
        get { selectedEntries.first { $0.id == selectionLead } ?? selectedEntries.last }
        set { selectedEntries = newValue.map { [$0] } ?? []; selectionLead = newValue?.id }
    }
    var query = ""
    var searchResults: [FileEntry] = []
    var isSearching = false
    var searchTruncated = false
    var showHidden = false
    var viewMode = BrowserViewMode.columns
    var columnMode: Bool {
        get { viewMode == .columns }
        set { viewMode = newValue ? .columns : .list }
    }
    var sortBy = FileSort.name
    var sortAscending = true
    var foldersFirst = true
    var namePrompt: FileNamePrompt?
    var nameInput = ""
    var infoSelection: FileInfoSelection?
    var batchRenameSelection: FileInfoSelection?
    var tagSelection: FileInfoSelection?
    var tagInput = ""
    var tagLabel = 0
    var appendTags = false
    var isChoosingTransfer = false
    var selectionAnchor: String?
    var selectionLead: String?
    var keyboardColumn: Int?
    var filesFocused = false
    var pendingSelectionURLs: [URL] = []
    let operations = FileOperations()
    var sidebarVisible = true
    var showGoToFolder = false
    var goToPath = ""
    var errorMessage: String?
    var favorites: [SavedLocation]
    var mountedVolumes: [MountedVolume] = []
    var recents: [SavedLocation]
    var history: [[URL]] = []
    var historyIndex = -1
    var focusSearchToken = 0

    @ObservationIgnored private let service = DirectoryService()
    @ObservationIgnored private var loadingTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var watcher: DirectoryWatcher?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored let folderAccess: FolderAccess
    @ObservationIgnored var initialDirectoryNeedingAccess: URL?
    @ObservationIgnored weak var keyboardView: ExplorerKeyboardView?
    @ObservationIgnored var physicalDirectory: URL?
    @ObservationIgnored var cutChangeCount: Int?
    @ObservationIgnored var applicationCache: [String: [URL]] = [:]
    @ObservationIgnored var sharingPicker: NSSharingServicePicker?
    @ObservationIgnored lazy var previews = FilePreviewController()

    init(defaults: UserDefaults = .standard, initialDirectory: URL? = nil) {
        self.defaults = defaults
        let access = FolderAccess(defaults: defaults)
        folderAccess = access
        let home = FileManager.default.homeDirectoryForCurrentUser
        let remembered = defaults.string(forKey: "lastDirectory").map { access.resolve(URL(fileURLWithPath: $0, isDirectory: true)) }
        let restored = remembered.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        let requested = URL(fileURLWithPath: (initialDirectory ?? restored ?? home).standardizedFileURL.path, isDirectory: true)
        currentDirectory = access.canNavigate(requested) ? requested : home
        initialDirectoryNeedingAccess = access.canNavigate(requested) ? nil : requested
        var savedPaths = Set<String>()
        favorites = (defaults.stringArray(forKey: "favoritePaths") ?? []).compactMap {
            let path = access.resolve(URL(fileURLWithPath: $0).standardizedFileURL).path
            return savedPaths.insert(path).inserted ? SavedLocation(path: path) : nil
        }
        recents = (defaults.stringArray(forKey: "recentPaths") ?? []).map { SavedLocation(path: access.resolve(URL(fileURLWithPath: $0)).path) }
        viewMode = defaults.string(forKey: "browserViewMode").flatMap(BrowserViewMode.init(rawValue:))
            ?? ((defaults.object(forKey: "columnMode") as? Bool ?? true) ? .columns : .list)
        sortBy = defaults.string(forKey: "sortBy").flatMap(FileSort.init(rawValue:)) ?? .name
        sortAscending = defaults.object(forKey: "sortAscending") as? Bool ?? true
        foldersFirst = defaults.object(forKey: "foldersFirst") as? Bool ?? true
        navigate(to: currentDirectory)
    }

    var canGoBack: Bool { historyIndex > 0 }
    var canGoForward: Bool { historyIndex >= 0 && historyIndex < history.count - 1 }
    var currentEntries: [FileEntry] { sorted(columns.last?.entries ?? []) }
    var isFavorite: Bool { isFavorite(currentDirectory) }
    func isFavorite(_ url: URL) -> Bool { favorites.contains { $0.path == favoritePath(url) } }
    var currentError: String? { columns.last?.error }

    func navigate(to url: URL, fromColumn index: Int? = nil, recordHistory: Bool = true) {
        let target = folderAccess.resolve(URL(fileURLWithPath: url.standardizedFileURL.path, isDirectory: true))
        guard folderAccess.canNavigate(target) else {
            chooseFolder(startingAt: target)
            return
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            errorMessage = "폴더를 찾을 수 없습니다.\n\(target.path)"
            return
        }
        let directories: [URL]
        if let index, columns.indices.contains(index) {
            directories = Array(columns.prefix(index + 1).map(\.directory)) + [target]
        } else if let existing = columns.firstIndex(where: { $0.directory == target }) {
            directories = Array(columns.prefix(existing + 1).map(\.directory))
        } else {
            directories = [target]
        }
        apply(directories: directories, recordHistory: recordHistory)
    }

    private func apply(directories: [URL], recordHistory: Bool) {
        guard let target = directories.last else { return }
        currentDirectory = target
        physicalDirectory = target.resolvingSymlinksInPath()
        selectedEntries = []; selectionAnchor = nil; selectionLead = nil; keyboardColumn = nil
        clearSearch()
        if recordHistory && (historyIndex < 0 || history[historyIndex] != directories) {
            history = Array(history.prefix(historyIndex + 1))
            history.append(directories)
            historyIndex = history.count - 1
        }
        columns = directories.map { directory in
            columns.first(where: { $0.directory == directory }) ?? BrowserColumn(directory: directory)
        }
        remember(target)
        loadColumns()
        watcher?.stop()
        watcher = DirectoryWatcher(directory: target) { [weak self] in self?.refresh() }
    }

    func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        apply(directories: history[historyIndex], recordHistory: false)
    }

    func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        apply(directories: history[historyIndex], recordHistory: false)
    }

    func goUp() {
        guard currentDirectory.path != "/" else { return }
        navigate(to: currentDirectory.deletingLastPathComponent())
    }

    func refresh() {
        loadColumns()
        if !query.isEmpty { updateSearch(preserveSelection: true) }
    }

    func toggleHidden() {
        showHidden.toggle()
        refresh()
    }

    func toggleFavorite() {
        toggleFavorite(at: currentDirectory)
    }

    func toggleFavorite(at url: URL) {
        if isFavorite(url) { removeFavorite(SavedLocation(path: favoritePath(url))) }
        else { addFavorite(url) }
    }

    func addFavorite(_ url: URL) {
        let path = favoritePath(url)
        guard !favorites.contains(where: { $0.path == path }) else { return }
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &directory), directory.boolValue else {
            errorMessage = "즐겨찾기에 추가할 폴더를 찾을 수 없습니다.\n\(path)"
            return
        }
        favorites.append(SavedLocation(path: path))
        saveFavorites()
    }

    func removeFavorite(_ location: SavedLocation) {
        let path = favoritePath(location.url)
        favorites.removeAll { $0.path == path }
        saveFavorites()
    }

    private func favoritePath(_ url: URL) -> String { folderAccess.resolve(url.standardizedFileURL).path }

    private func saveFavorites() {
        defaults.set(favorites.map(\.path), forKey: "favoritePaths")
    }

    func chooseFavorites() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = currentDirectory
        panel.prompt = "즐겨찾기에 추가"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            do {
                try folderAccess.remember(url)
                addFavorite(url)
            } catch {
                errorMessage = "폴더 접근 권한을 저장할 수 없습니다.\n\(error.localizedDescription)"
            }
        }
    }

    func chooseFolder() { chooseFolder(startingAt: currentDirectory) }

    func chooseFolder(startingAt directory: URL) {
        if let url = selectAuthorizedFolder(startingAt: directory) { navigate(to: url) }
    }

    func openNewTerminal(in directory: URL, using terminals: TerminalStore) {
        let requested = folderAccess.resolve(directory)
        let authorized = folderAccess.canNavigate(requested) ? requested : selectAuthorizedFolder(startingAt: requested)
        guard let authorized else { return }
        terminals.newSession(directory: authorized)
        navigate(to: authorized)
    }

    private func selectAuthorizedFolder(startingAt directory: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        panel.prompt = "폴더 열기"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try folderAccess.remember(url)
                return url
            } catch {
                errorMessage = "폴더 접근 권한을 저장할 수 없습니다. 다른 폴더를 선택해 주세요.\n\(error.localizedDescription)"
            }
        }
        return nil
    }

    func open(_ entry: FileEntry, fromColumn index: Int? = nil) {
        if entry.isNavigable { navigate(to: entry.navigationURL, fromColumn: index) }
        else if !NSWorkspace.shared.open(entry.url) { errorMessage = "항목을 열 수 없습니다.\n\(entry.url.path)" }
    }

    func reveal(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }

    func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    func beginGoToFolder() {
        goToPath = currentDirectory.path
        showGoToFolder = true
    }

    func submitGoToFolder() {
        let url = PathUtilities.resolve(goToPath, relativeTo: currentDirectory)
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &directory), directory.boolValue else {
            errorMessage = "폴더를 찾을 수 없습니다.\n\(url.path)"
            return
        }
        showGoToFolder = false
        navigate(to: url)
    }

    func updateSearch(preserveSelection: Bool = false) {
        searchTask?.cancel()
        if !preserveSelection { selectedEntries = []; selectionAnchor = nil; selectionLead = nil; keyboardColumn = nil; previews.update([]) }
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchResults = []
        searchTruncated = false
        guard !searchQuery.isEmpty else { isSearching = false; return }
        isSearching = true
        let directory = currentDirectory
        let hidden = showHidden
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(220))
                let result = try await service.search(in: directory, query: searchQuery, showHidden: hidden)
                try Task.checkCancellation()
                searchResults = result.entries
                if preserveSelection { selectedEntries = selectedEntries.filter { selected in result.entries.contains { $0.id == selected.id } } }
                searchTruncated = result.truncated
                isSearching = false
            } catch is CancellationError { }
            catch { isSearching = false; errorMessage = error.localizedDescription }
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        query = ""
        searchResults = []
        isSearching = false
        searchTruncated = false
    }

    private func loadColumns() {
        loadingTask?.cancel()
        let directories = columns.map(\.directory)
        let hidden = showHidden
        loadingTask = Task {
            for directory in directories {
                do {
                    let entries = try await service.contents(of: directory, showHidden: hidden)
                    try Task.checkCancellation()
                    guard let index = columns.firstIndex(where: { $0.directory == directory }) else { continue }
                    columns[index].entries = entries
                    columns[index].isLoading = false
                    columns[index].error = nil
                    selectedEntries = selectedEntries.compactMap { selected in
                        guard selected.url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else { return selected }
                        return entries.first { $0.id == selected.id }
                    }
                    if !pendingSelectionURLs.isEmpty {
                        let matching = entries.filter { item in pendingSelectionURLs.contains { $0.standardizedFileURL == item.url.standardizedFileURL } }
                        if !matching.isEmpty { selectedEntries = matching; selectionLead = matching.last?.id; pendingSelectionURLs = [] }
                    }
                } catch is CancellationError { return }
                catch {
                    guard let index = columns.firstIndex(where: { $0.directory == directory }) else { continue }
                    columns[index].isLoading = false
                    columns[index].error = error.localizedDescription
                }
            }
        }
    }

    private func remember(_ url: URL) {
        recents.removeAll { $0.path == url.path }
        recents.insert(SavedLocation(path: url.path), at: 0)
        recents = Array(recents.prefix(12))
        defaults.set(recents.map(\.path), forKey: "recentPaths")
        defaults.set(url.path, forKey: "lastDirectory")
    }

    func saveViewMode() {
        defaults.set(columnMode, forKey: "columnMode")
        defaults.set(viewMode.rawValue, forKey: "browserViewMode")
    }

    func saveSort() {
        defaults.set(sortBy.rawValue, forKey: "sortBy")
        defaults.set(sortAscending, forKey: "sortAscending")
        defaults.set(foldersFirst, forKey: "foldersFirst")
    }

    func sorted(_ entries: [FileEntry]) -> [FileEntry] {
        entries.sorted { a, b in
            if foldersFirst && a.isNavigable != b.isNavigable { return a.isNavigable }
            let order = sortBy.compare(a, b)
            if order == .orderedSame { return a.name.localizedStandardCompare(b.name) == .orderedAscending }
            return order == (sortAscending ? .orderedAscending : .orderedDescending)
        }
    }

    isolated deinit {
        loadingTask?.cancel()
        searchTask?.cancel()
        watcher?.stop()
    }
}
