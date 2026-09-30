import AppKit
import SwiftUI

struct WorkspaceCommands: Commands {
    @Bindable var browser: BrowserState
    @Bindable var terminals: TerminalStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("새 폴더…") { if browser.hasFileFocus { browser.beginNewFolder() } }
                .keyboardShortcut("n", modifiers: [.command, .shift]).disabled(!browser.filesFocused || browser.isWorking)
            Button("선택 항목으로 새 폴더…") { if browser.hasFileFocus { browser.beginNewFolder(withSelection: true) } }
                .keyboardShortcut("n", modifiers: [.command, .control]).disabled(!browser.filesFocused || browser.selectedEntries.isEmpty || browser.isWorking)
            Button("새 텍스트 파일…", action: browser.beginNewTextFile).disabled(browser.isWorking)
            Divider()
            Button("열기") { if browser.hasFileFocus { browser.openSelection() } }
                .keyboardShortcut("o").disabled(!browser.filesFocused || browser.selectedEntries.isEmpty)
            Button("폴더 선택…", action: browser.chooseFolder).keyboardShortcut("o", modifiers: [.command, .shift])
            Divider()
            Button("복제") { if browser.hasFileFocus { browser.duplicateItems() } }.keyboardShortcut("d")
                .disabled(!browser.filesFocused || browser.selectedEntries.isEmpty || browser.isWorking)
            Button("이름 변경…") { if browser.hasFileFocus { browser.beginRename() } }
                .disabled(!browser.filesFocused || browser.selectedEntries.isEmpty || browser.isWorking)
            Button("휴지통으로 이동") { if browser.hasFileFocus { browser.trashItems() } }.keyboardShortcut(.delete)
                .disabled(!browser.filesFocused || browser.selectedEntries.isEmpty || browser.isWorking)
            Divider()
            Button("정보 가져오기") { if browser.hasFileFocus { browser.showInfo() } }.keyboardShortcut("i")
                .disabled(!browser.filesFocused || browser.selectedEntries.isEmpty)
            Button("훑어보기") { if browser.hasFileFocus { browser.previewItems() } }.keyboardShortcut("y")
                .disabled(!browser.filesFocused || browser.selectedEntries.isEmpty)
        }
        CommandGroup(replacing: .undoRedo) {
            Button(browser.filesFocused ? "\(browser.operations.undoStack.last?.title ?? "작업") 실행 취소" : "실행 취소") {
                NSApp.sendAction(#selector(ExplorerKeyboardView.undo(_:)), to: nil, from: nil)
            }.keyboardShortcut("z").disabled(browser.filesFocused ? !browser.operations.canUndo : !(NSApp.keyWindow?.firstResponder?.undoManager?.canUndo ?? false))
            Button("다시 실행") { NSApp.sendAction(#selector(ExplorerKeyboardView.redo(_:)), to: nil, from: nil) }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(browser.filesFocused ? !browser.operations.canRedo : !(NSApp.keyWindow?.firstResponder?.undoManager?.canRedo ?? false))
        }
        CommandGroup(after: .pasteboard) {
            Button("여기로 이동") { if browser.hasFileFocus { browser.pasteFiles(move: true) } }
                .keyboardShortcut("v", modifiers: [.command, .option]).disabled(!browser.filesFocused || browser.isWorking || FileClipboard.read().isEmpty)
            Button("경로 복사") { if browser.hasFileFocus { browser.copySelectedPaths() } }
                .keyboardShortcut("c", modifiers: [.command, .option]).disabled(!browser.filesFocused || browser.selectedEntries.isEmpty)
        }
        CommandMenu("이동") {
            Button("이전 폴더", action: browser.goBack).keyboardShortcut("[").disabled(!browser.canGoBack)
            Button("다음 폴더", action: browser.goForward).keyboardShortcut("]").disabled(!browser.canGoForward)
            Button("상위 폴더", action: browser.goUp).keyboardShortcut(.upArrow, modifiers: .command)
            Divider()
            Button("폴더로 이동…", action: browser.beginGoToFolder).keyboardShortcut("l")
            Button("경로로 이동…", action: browser.beginGoToFolder).keyboardShortcut("g", modifiers: [.command, .shift])
            Button("홈") { browser.navigate(to: FolderAccess.userHome) }
                .keyboardShortcut("h", modifiers: [.command, .shift])
        }
        CommandMenu("즐겨찾기") {
            Button(browser.isFavorite ? "현재 폴더를 즐겨찾기에서 제거" : "현재 폴더를 즐겨찾기에 추가",
                   action: browser.toggleFavorite)
            Button("폴더를 선택해 추가…", action: browser.chooseFavorites)
            if !browser.favorites.isEmpty {
                Divider()
                ForEach(browser.favorites) { location in
                    Button(location.name) { browser.navigate(to: location.url) }.help(location.path)
                }
            }
        }
        CommandMenu("터미널") {
            Button("새 터미널 탭") { terminals.newSession(directory: browser.currentDirectory) }.keyboardShortcut("t")
            Button("터미널에 포커스") { terminals.active?.focus() }.keyboardShortcut(.return, modifiers: .command)
            Divider()
            Button("글자 크게") {
                if let active = terminals.active { active.fontSize = min(24, active.fontSize + 1) }
            }.keyboardShortcut("+")
            Button("글자 작게") {
                if let active = terminals.active { active.fontSize = max(10, active.fontSize - 1) }
            }.keyboardShortcut("-")
            Button("기본 글자 크기") { terminals.active?.fontSize = 13 }.keyboardShortcut("0")
        }
        CommandGroup(after: .sidebar) {
            Button("사이드바 표시 / 숨기기") { browser.sidebarVisible.toggle() }
                .keyboardShortcut("s", modifiers: [.command, .option])
            Divider()
            Button("아이콘 보기") { browser.viewMode = .icons }.keyboardShortcut("1")
            Button("목록 보기") { browser.viewMode = .list }.keyboardShortcut("2")
            Button("컬럼 보기") { browser.viewMode = .columns }.keyboardShortcut("3")
            Button("갤러리 보기") { browser.viewMode = .gallery }.keyboardShortcut("4")
            Button("파일 목록에 포커스", action: browser.focusFiles).keyboardShortcut(.return, modifiers: [.command, .option])
            Button("숨김 파일 표시 / 숨기기", action: browser.toggleHidden)
                .keyboardShortcut(".", modifiers: [.command, .shift])
            Button("새로고침", action: browser.refresh).keyboardShortcut("r")
        }
        CommandGroup(after: .textEditing) {
            Button("폴더 안에서 검색") { browser.focusSearchToken += 1 }.keyboardShortcut("f")
        }
    }
}
