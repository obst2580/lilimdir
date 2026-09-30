import SwiftUI
import Combine
import UniformTypeIdentifiers

struct SidebarView: View {
    @Bindable var browser: BrowserState
    @Bindable var terminals: TerminalStore
    private let home = FolderAccess.userHome

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                if let icon = NSImage(named: "LilimIcon") {
                    Image(nsImage: icon).resizable().interpolation(.high)
                        .frame(width: 32, height: 32).accessibilityHidden(true)
                } else {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 22)).foregroundStyle(Theme.accent)
                }
                Text("lilim").font(.system(size: 23, weight: .semibold, design: .rounded))
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section("바로가기") {
                        location("홈", symbol: "house", url: home)
                        location("데스크탑", symbol: "desktopcomputer", url: home.appendingPathComponent("Desktop"))
                        location("문서", symbol: "doc.text", url: home.appendingPathComponent("Documents"))
                        location("다운로드", symbol: "arrow.down.circle", url: home.appendingPathComponent("Downloads"))
                        location("응용 프로그램", symbol: "app.dashed", url: URL(fileURLWithPath: "/Applications"))
                        let cloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
                        if FileManager.default.fileExists(atPath: cloud.path) { location("iCloud Drive", symbol: "icloud", url: cloud) }
                        location("Macintosh HD", symbol: "internaldrive", url: URL(fileURLWithPath: "/"))
                    }
                    if !browser.mountedVolumes.isEmpty {
                        section("위치") {
                            ForEach(browser.mountedVolumes) { volume in
                                HStack(spacing: 1) {
                                    location(volume.name, symbol: volume.local ? "externaldrive" : "network", url: volume.url)
                                    if volume.ejectable {
                                        Button("\(volume.name) 추출", systemImage: "eject") { browser.eject(volume) }
                                            .labelStyle(.iconOnly).buttonStyle(.borderless).help("추출")
                                    }
                                }
                            }
                        }
                    }
                    section("즐겨찾기", addFavorites: true) {
                        if browser.favorites.isEmpty {
                            Text("+ 또는 폴더의 ☆을 눌러\n자주 쓰는 폴더를 모아 두세요.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                                .lineSpacing(4).padding(.horizontal, 9).padding(.vertical, 4)
                        }
                        ForEach(browser.favorites) { item in
                            location(item.name, symbol: "folder", url: item.url)
                        }
                    }
                    section("최근 방문") {
                        ForEach(browser.recents.prefix(7)) { item in
                            location(item.name, symbol: "clock", url: item.url)
                        }
                    }
                }.padding(.horizontal, 10)
            }
            Spacer(minLength: 0)
            Button(action: browser.chooseFolder) {
                Label("폴더 열기", systemImage: "folder.badge.plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .buttonStyle(.plain).foregroundStyle(Theme.accent)
            .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            .padding(12).help("폴더 선택 · ⌘⇧O")
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .task { browser.refreshVolumes() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in browser.refreshVolumes() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)) { _ in browser.refreshVolumes() }
    }

    private func section<Content: View>(_ title: String, addFavorites: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if addFavorites {
                    Button("즐겨찾기에 폴더 추가", systemImage: "plus", action: browser.chooseFavorites)
                        .labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(Theme.accent)
                        .help("폴더를 선택해 즐겨찾기에 추가")
                }
            }.padding(.horizontal, 9).padding(.bottom, 6)
            content()
        }
    }

    private func location(_ title: String, symbol: String, url: URL) -> some View {
        Button { browser.navigate(to: url) } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 13)).frame(width: 17)
                    .foregroundStyle(browser.currentDirectory.path == url.path ? Theme.accent : .secondary)
                Text(title).font(.system(size: 12)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9).padding(.vertical, 7)
            .background(browser.currentDirectory.path == url.path ? Theme.accent.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(url.path)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { browser.receiveDrop($0, into: url) }
        .accessibilityLabel("\(title) 폴더로 이동")
        .contextMenu {
            Button("새 터미널 탭에서 열기", systemImage: "plus.rectangle.on.rectangle") {
                browser.openNewTerminal(in: url, using: terminals)
            }
            Button("Finder에서 보기", systemImage: "finder") { browser.reveal(url) }
            Button(browser.isFavorite(url) ? "즐겨찾기에서 제거" : "즐겨찾기에 추가",
                   systemImage: browser.isFavorite(url) ? "star.slash" : "star") { browser.toggleFavorite(at: url) }
        }
    }
}
