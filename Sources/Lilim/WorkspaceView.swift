import SwiftUI

struct WorkspaceView: View {
    @Bindable var browser: BrowserState
    @Bindable var terminals: TerminalStore

    var body: some View {
        HSplitView {
            if browser.sidebarVisible {
                SidebarView(browser: browser, terminals: terminals)
                    .frame(minWidth: 175, idealWidth: 190, maxWidth: 245)
            }
            ExplorerView(browser: browser, terminals: terminals)
                .frame(minWidth: 300, idealWidth: 520)
                .layoutPriority(1)
            TerminalPane(terminals: terminals, browser: browser)
                .frame(minWidth: 420, idealWidth: 700)
                .layoutPriority(1)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("사이드바 토글", systemImage: "sidebar.left") { browser.sidebarVisible.toggle() }
                    .help("사이드바 표시 / 숨기기 · ⌘⌥S")
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text("탐색하고, 바로 실행하세요.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            ToolbarItem {
                Button("폴더로 이동", systemImage: "arrow.turn.down.right", action: browser.beginGoToFolder)
                    .help("폴더로 바로 이동 · ⌘L")
            }
        }
        .sheet(isPresented: $browser.showGoToFolder) { GoToFolderView(browser: browser) }
        .task {
            await Task.yield()
            if let requested = browser.initialDirectoryNeedingAccess {
                browser.initialDirectoryNeedingAccess = nil
                browser.chooseFolder(startingAt: requested)
            } else if FolderAccess.isSandboxBuild && !browser.folderAccess.hasRestoredFolders {
                browser.chooseFolder(startingAt: FolderAccess.userHome)
            }
        }
        .sheet(item: $browser.namePrompt) { FileNameSheet(browser: browser, prompt: $0) }
        .sheet(item: $browser.infoSelection) { FileInfoView(selection: $0, browser: browser) }
        .sheet(item: $browser.batchRenameSelection) { BatchRenameSheet(browser: browser, selection: $0) }
        .sheet(item: $browser.tagSelection) { FileTagsSheet(browser: browser, selection: $0) }
        .alert("작업을 확인해 주세요", isPresented: Binding(
            get: { browser.errorMessage != nil },
            set: { if !$0 { browser.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { browser.errorMessage = nil }
        } message: { Text(browser.errorMessage ?? "") }
    }
}
