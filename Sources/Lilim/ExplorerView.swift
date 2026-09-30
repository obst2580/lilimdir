import SwiftUI
import UniformTypeIdentifiers

struct ExplorerView: View {
    @Bindable var browser: BrowserState
    @Bindable var terminals: TerminalStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            Divider()
            searchBar
            Divider()
            if !browser.query.isEmpty { searchContent }
            else {
                switch browser.viewMode {
                case .columns: columnContent
                case .list: listContent
                case .icons: iconContent
                case .gallery: galleryContent
                }
            }
            Divider()
            statusBar
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .background(ExplorerKeyboardBridge(browser: browser).frame(width: 1, height: 1))
        .contextMenu { FileActionsMenu(browser: browser) }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { browser.receiveDrop($0, into: browser.currentDirectory) }
        .onChange(of: browser.query) { browser.updateSearch() }
        .onChange(of: browser.focusSearchToken) { searchFocused = true }
        .onChange(of: browser.viewMode) { browser.saveViewMode() }
        .onChange(of: browser.sortBy) { browser.saveSort() }
        .onChange(of: browser.sortAscending) { browser.saveSort() }
        .onChange(of: browser.foldersFirst) { browser.saveSort() }
    }

    private var navigationBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 5) {
                Button("이전 폴더", systemImage: "chevron.left", action: browser.goBack)
                    .disabled(!browser.canGoBack).help("이전 폴더 · ⌘[")
                Button("다음 폴더", systemImage: "chevron.right", action: browser.goForward)
                    .disabled(!browser.canGoForward).help("다음 폴더 · ⌘]")
                Button("상위 폴더", systemImage: "arrow.up", action: browser.goUp)
                    .disabled(browser.currentDirectory.path == "/").help("상위 폴더 · ⌘↑")
                Spacer()
                Button(action: browser.toggleFavorite) {
                    Image(systemName: browser.isFavorite ? "star.fill" : "star")
                }
                    .foregroundStyle(browser.isFavorite ? Theme.accent : .secondary)
                    .accessibilityLabel(browser.isFavorite ? "즐겨찾기 제거" : "즐겨찾기 추가")
                    .help(browser.isFavorite ? "즐겨찾기 제거" : "즐겨찾기 추가")
                Picker("보기 방식", selection: $browser.viewMode) {
                    ForEach(BrowserViewMode.allCases) { mode in Image(systemName: mode.symbol).accessibilityLabel(mode.title).tag(mode) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 116).help("아이콘 / 목록 / 컬럼 / 갤러리")
                Menu {
                    Picker("정렬 기준", selection: $browser.sortBy) {
                        ForEach(FileSort.allCases) { option in Text(option.title).tag(option) }
                    }
                    Toggle("오름차순", isOn: $browser.sortAscending)
                    Toggle("폴더를 먼저 표시", isOn: $browser.foldersFirst)
                } label: { Image(systemName: "arrow.up.arrow.down") }
                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("정렬")
                Menu {
                    FileActionsMenu(browser: browser)
                    Divider()
                    Button("경로로 이동…", systemImage: "arrow.turn.down.right", action: browser.beginGoToFolder)
                    Button("폴더 열기…", systemImage: "folder", action: browser.chooseFolder)
                    Button("새 터미널 탭에서 열기", systemImage: "plus.rectangle.on.rectangle") {
                        terminals.newSession(directory: browser.currentDirectory)
                    }
                    Divider()
                    Toggle("숨김 파일 표시", isOn: $browser.showHidden)
                        .onChange(of: browser.showHidden) { browser.refresh() }
                    Button("새로고침", systemImage: "arrow.clockwise", action: browser.refresh)
                    Button("Finder에서 보기", systemImage: "finder") { browser.reveal(browser.currentDirectory) }
                    Button("폴더 경로 복사", systemImage: "doc.on.doc") { browser.copyPath(browser.currentDirectory) }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("폴더 옵션")
            }
            .labelStyle(.iconOnly).buttonStyle(.borderless)

            HStack(spacing: 8) {
                Image(systemName: "folder.fill").font(.system(size: 20)).foregroundStyle(Theme.accent)
                Text(browser.currentDirectory.lastPathComponent.isEmpty ? "Macintosh HD" : browser.currentDirectory.lastPathComponent)
                    .font(.system(size: 18, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("새 폴더", systemImage: "folder.badge.plus") { browser.beginNewFolder() }
                    .buttonStyle(.borderless).labelStyle(.iconOnly).disabled(browser.isWorking).help("새 폴더 · ⌘⇧N")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(PathUtilities.breadcrumbs(for: browser.currentDirectory), id: \.path) { url in
                        if url.path != "/" {
                            Image(systemName: "chevron.right").font(.system(size: 7)).foregroundStyle(.tertiary)
                        }
                        Button {
                            browser.navigate(to: url)
                        } label: {
                            Text(url.path == "/" ? "Mac" : url.lastPathComponent)
                                .font(.system(size: 10)).foregroundStyle(url == browser.currentDirectory ? .primary : .secondary)
                        }.buttonStyle(.plain).help(url.path)
                    }
                }
            }
        }
        .padding(16)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("이 폴더와 하위 폴더 검색", text: $browser.query)
                .textFieldStyle(.plain).font(.system(size: 12)).focused($searchFocused)
                .onExitCommand { browser.clearSearch(); searchFocused = false }
            if browser.isSearching { ProgressView().controlSize(.mini) }
            if !browser.query.isEmpty {
                Button("검색 지우기", systemImage: "xmark.circle.fill", action: browser.clearSearch)
                    .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary)
            } else { Text("⌘F").font(.system(size: 10)).foregroundStyle(.tertiary) }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    private var columnContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(browser.columns.enumerated()), id: \.element.id) { index, column in
                        columnView(column, index: index).frame(width: 230)
                            .id(column.id)
                        if index < browser.columns.count - 1 { Divider() }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .onChange(of: browser.columns.count) {
                if let last = browser.columns.last { proxy.scrollTo(last.id, anchor: .trailing) }
            }
        }
    }

    private func columnView(_ column: BrowserColumn, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(column.directory.lastPathComponent.isEmpty ? "Macintosh HD" : column.directory.lastPathComponent)
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("\(column.entries.count)").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 13).padding(.vertical, 10)
            if column.isLoading { ProgressView().controlSize(.small).padding(24) }
            else if let error = column.error { emptyState("폴더를 읽을 수 없습니다", detail: error, symbol: "lock") }
            else if column.entries.isEmpty { emptyState("빈 폴더", detail: "새 파일을 만들면 여기에 표시됩니다.", symbol: "folder") }
            else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 1) {
                            ForEach(browser.sorted(column.entries)) { entry in
                                fileRow(entry, index: index, selected: browser.selectedEntries.contains(where: { $0.id == entry.id }) ||
                                        (browser.columns.indices.contains(index + 1) && browser.columns[index + 1].directory == entry.url))
                            }
                        }.padding(.horizontal, 5).padding(.bottom, 10)
                    }.onChange(of: browser.selection?.id) {
                        if browser.keyboardColumn == index, let id = browser.selection?.id { proxy.scrollTo(id) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { browser.receiveDrop($0, into: column.directory) }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            if let error = browser.currentError { emptyState("폴더를 읽을 수 없습니다", detail: error, symbol: "lock") }
            else if browser.columns.last?.isLoading == true { ProgressView().padding(30) }
            else if browser.currentEntries.isEmpty { emptyState("빈 폴더", detail: "새 파일을 만들면 여기에 표시됩니다.", symbol: "folder") }
            else {
                HStack {
                    Text("이름")
                    Spacer()
                    Text("종류 / 크기")
                }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 10)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(browser.currentEntries) { entry in
                                fileRow(entry, index: browser.columns.count - 1, selected: browser.selectedEntries.contains(where: { $0.id == entry.id }), details: true)
                            }
                        }.padding(.horizontal, 7)
                    }.onChange(of: browser.selection?.id) { if let id = browser.selection?.id { proxy.scrollTo(id) } }
                }
            }
            Spacer(minLength: 0)
        }.frame(maxHeight: .infinity)
    }

    private var iconContent: some View {
        ScrollView {
            if browser.currentEntries.isEmpty {
                emptyState(browser.currentError == nil ? "빈 폴더" : "폴더를 읽을 수 없습니다",
                           detail: browser.currentError ?? "새 파일을 만들면 여기에 표시됩니다.", symbol: "folder")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 140))], spacing: 12) {
                    ForEach(browser.currentEntries) { entry in
                        FileRowSurface(entry: entry, column: browser.columns.count - 1, browser: browser,
                                       terminals: terminals, selected: browser.selectedEntries.contains { $0.id == entry.id }, iconMode: true)
                            .frame(height: 100)
                    }
                }.padding(14)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var galleryContent: some View {
        VStack(spacing: 0) {
            if let entry = browser.selection ?? browser.currentEntries.first {
                FilePreviewView(url: entry.url).frame(minHeight: 130, maxHeight: .infinity)
                Text(entry.name).font(.system(size: 12, weight: .medium)).lineLimit(1).padding(9)
                Divider()
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(browser.currentEntries) { item in
                            FileRowSurface(entry: item, column: browser.columns.count - 1, browser: browser,
                                           terminals: terminals, selected: browser.selectedEntries.contains { $0.id == item.id }, iconMode: true)
                                .frame(width: 100, height: 100)
                        }
                    }.padding(10)
                }.frame(height: 122)
            } else {
                emptyState("미리볼 항목이 없습니다", detail: browser.currentError ?? "파일을 선택하면 여기에서 미리볼 수 있습니다.", symbol: "photo")
            }
        }.frame(maxHeight: .infinity)
    }

    private var searchContent: some View {
        VStack(spacing: 0) {
            if browser.searchResults.isEmpty && !browser.isSearching {
                emptyState("검색 결과가 없습니다", detail: "다른 이름으로 검색해 보세요.", symbol: "magnifyingglass")
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(browser.sorted(browser.searchResults)) { entry in
                            fileRow(entry, index: nil, selected: browser.selectedEntries.contains(where: { $0.id == entry.id }),
                                    detail: PathUtilities.displayPath(entry.url.deletingLastPathComponent()))
                        }
                    }.padding(7)
                }
            }
            Spacer(minLength: 0)
        }.frame(maxHeight: .infinity)
    }

    private func fileRow(_ entry: FileEntry, index: Int?, selected: Bool, details: Bool = false, detail: String? = nil) -> some View {
        FileRowSurface(entry: entry, column: index, browser: browser, terminals: terminals,
                       selected: selected, details: details, detail: detail)
            .frame(height: detail == nil ? 30 : 46)
            .id(entry.id)
    }

    private func emptyState(_ title: String, detail: String, symbol: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 27)).foregroundStyle(.tertiary)
            Text(title).font(.system(size: 12, weight: .medium))
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineLimit(5)
        }.padding(25).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            if browser.operations.isBusy {
                ProgressView().controlSize(.mini)
                Text(browser.operations.activity + " 중…")
                Button("중단", action: browser.operations.cancel).help("현재 항목을 완료한 뒤 다음 항목부터 중단합니다")
            } else if browser.selectedEntries.count > 1 {
                Text("\(browser.selectedEntries.count)개 선택 · \(ByteCountFormatter.string(fromByteCount: browser.selectedEntries.filter { !$0.isNavigable }.reduce(0) { $0 + $1.size }, countStyle: .file))")
            } else if !browser.query.isEmpty {
                Text(browser.searchTruncated ? "\(browser.searchResults.count)개 · 검색 범위 제한 도달" : "검색 결과 \(browser.searchResults.count)개")
            } else if let selection = browser.selection { Text("\(selection.name) · \(selection.sizeLabel)").lineLimit(1) }
            else { Text("\(browser.currentEntries.filter(\.isNavigable).count)개 폴더 · \(browser.currentEntries.filter { !$0.isNavigable }.count)개 파일") }
            Spacer(minLength: 5)
            if browser.showHidden { Image(systemName: "eye").help("숨김 파일 표시 중") }
            Button("새로고침", systemImage: "arrow.clockwise", action: browser.refresh)
                .buttonStyle(.plain).labelStyle(.iconOnly).help("새로고침 · ⌘R")
        }
        .font(.system(size: 10)).foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
