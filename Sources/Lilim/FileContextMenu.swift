import AppKit

@MainActor
enum FileContextMenu {
    static func make(entry: FileEntry, browser: BrowserState, terminals: TerminalStore) -> NSMenu {
        let menu = NSMenu(); menu.autoenablesItems = false
        let items = browser.contextItems(entry)
        let available = !browser.isWorking
        func add(_ title: String, enabled: Bool = true, to parent: NSMenu? = nil, action: @escaping () -> Void) {
            let target = FileMenuAction(action)
            let item = NSMenuItem(title: title, action: #selector(FileMenuAction.invoke(_:)), keyEquivalent: "")
            item.target = target; item.representedObject = target; item.isEnabled = enabled
            (parent ?? menu).addItem(item)
        }
        add("열기") { items.forEach { browser.open($0, fromColumn: browser.keyboardColumn) } }
        if items.count == 1 && !entry.isNavigable {
            let openWith = NSMenu(title: "다음으로 열기")
            for app in browser.applications(for: entry) {
                add(app.deletingPathExtension().lastPathComponent, to: openWith) { browser.open([entry.url], with: app) }
            }
            openWith.addItem(.separator())
            add("다른 앱 선택…", to: openWith) { browser.chooseApplication(for: items) }
            let item = NSMenuItem(title: "다음으로 열기", action: nil, keyEquivalent: ""); item.submenu = openWith
            menu.addItem(item)
        }
        if entry.isPackage {
            add("패키지 내용 보기") { browser.navigate(to: entry.url) }
        }
        if entry.isAlias || entry.isSymbolicLink {
            add("원본 보기") { browser.reveal(entry.aliasTarget ?? entry.url.resolvingSymlinksInPath()) }
        }
        add("훑어보기 · Space") { browser.previewItems(items) }
        add("정보 가져오기 · ⌘I") { browser.showInfo(items) }
        add("공유…") { browser.shareItems(items) }
        menu.addItem(.separator())
        add("복사 · ⌘C", enabled: available) { browser.copyItems(items) }
        add("잘라내기 · ⌘X", enabled: available) { browser.copyItems(items, cut: true) }
        add("다른 폴더로 복사…", enabled: available) { browser.chooseDestination(items, move: false) }
        add("다른 폴더로 이동…", enabled: available) { browser.chooseDestination(items, move: true) }
        if entry.isNavigable {
            add("이 폴더에 붙여넣기", enabled: available && !FileClipboard.read().isEmpty) { browser.pasteFiles(into: entry.navigationURL) }
        }
        add("복제 · ⌘D", enabled: available) { browser.duplicateItems(items) }
        add("가상본 만들기", enabled: available) { browser.aliasItems(items) }
        add("압축", enabled: available) { browser.compressItems(items) }
        add("이름 변경 · Return", enabled: available) { browser.beginRename(items.count == 1 ? entry : nil) }
        add("태그…", enabled: available) { browser.beginTags(items) }
        menu.addItem(.separator())
        add("경로 복사 · ⌘⌥C") { browser.copySelectedPaths(items) }
        add("Finder에서 보기") { NSWorkspace.shared.activateFileViewerSelecting(items.map(\.url)) }
        let favoriteFolders = items.filter(\.isNavigable)
        if !favoriteFolders.isEmpty {
            let allSaved = favoriteFolders.allSatisfy { browser.isFavorite($0.navigationURL) }
            add(allSaved ? "즐겨찾기에서 제거" : "즐겨찾기에 추가") {
                for folder in favoriteFolders {
                    if allSaved { browser.removeFavorite(SavedLocation(path: folder.navigationURL.path)) }
                    else { browser.addFavorite(folder.navigationURL) }
                }
            }
        }
        if entry.isNavigable {
            add("새 터미널 탭에서 열기") {
                browser.openNewTerminal(in: entry.navigationURL, using: terminals)
            }
        }
        menu.addItem(.separator())
        add("휴지통으로 이동 · ⌘⌫", enabled: available) { browser.trashItems(items) }
        return menu
    }
}
