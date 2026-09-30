import SwiftUI

struct FileActionsMenu: View {
    @Bindable var browser: BrowserState
    var body: some View {
        Button("새 폴더…", systemImage: "folder.badge.plus") { browser.beginNewFolder() }.disabled(browser.isWorking)
        Button("선택 항목으로 새 폴더…") { browser.beginNewFolder(withSelection: true) }.disabled(browser.selectedEntries.isEmpty || browser.isWorking)
        Button("새 텍스트 파일…", systemImage: "doc.badge.plus", action: browser.beginNewTextFile).disabled(browser.isWorking)
        Button("붙여넣기 · ⌘V", systemImage: "doc.on.clipboard") { browser.pasteFiles() }.disabled(browser.isWorking || FileClipboard.read().isEmpty)
        Button("여기로 이동 · ⌘⌥V", systemImage: "arrow.down.doc") { browser.pasteFiles(move: true) }.disabled(browser.isWorking || FileClipboard.read().isEmpty)
        Divider()
        Button("복사", systemImage: "doc.on.doc") { browser.copyItems() }.disabled(browser.selectedEntries.isEmpty)
        Button("다른 폴더로 이동…", systemImage: "folder") { browser.chooseDestination(move: true) }.disabled(browser.selectedEntries.isEmpty || browser.isWorking)
        Button("복제") { browser.duplicateItems() }.disabled(browser.selectedEntries.isEmpty || browser.isWorking)
        Button("이름 변경…", action: { browser.beginRename() }).disabled(browser.selectedEntries.isEmpty || browser.isWorking)
        Button("압축", systemImage: "archivebox") { browser.compressItems() }.disabled(browser.selectedEntries.isEmpty || browser.isWorking)
        Button("태그…", systemImage: "tag") { browser.beginTags() }.disabled(browser.selectedEntries.isEmpty || browser.isWorking)
        Button("정보 가져오기", systemImage: "info.circle") { browser.showInfo() }.disabled(browser.selectedEntries.isEmpty)
        Button("훑어보기", systemImage: "eye") { browser.previewItems() }.disabled(browser.selectedEntries.isEmpty)
        Divider()
        Button("휴지통으로 이동", systemImage: "trash") { browser.trashItems() }.disabled(browser.selectedEntries.isEmpty || browser.isWorking)
        Button("\(browser.operations.undoStack.last?.title ?? "작업") 실행 취소", systemImage: "arrow.uturn.backward", action: browser.undoFiles).disabled(!browser.operations.canUndo)
        Button("다시 실행", systemImage: "arrow.uturn.forward", action: browser.redoFiles).disabled(!browser.operations.canRedo)
    }
}
