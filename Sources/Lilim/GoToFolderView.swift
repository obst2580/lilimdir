import SwiftUI

struct GoToFolderView: View {
    @Bindable var browser: BrowserState
    @FocusState private var pathFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("폴더로 바로 이동", systemImage: "arrow.turn.down.right")
                .font(.system(size: 17, weight: .semibold))
            Text("절대 경로, ~ 또는 현재 폴더 기준의 상대 경로를 입력하세요.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            TextField("~/Developer/my-project", text: $browser.goToPath)
                .textFieldStyle(.roundedBorder).font(.system(size: 13, design: .monospaced))
                .focused($pathFocused).onSubmit(browser.submitGoToFolder)
            HStack(spacing: 8) {
                ForEach(browser.recents.prefix(3)) { location in
                    Button(location.name) { browser.goToPath = location.path; browser.submitGoToFolder() }
                        .buttonStyle(.bordered).controlSize(.small).lineLimit(1).help(location.path)
                }
            }
            HStack {
                Spacer()
                Button("취소") { browser.showGoToFolder = false }.keyboardShortcut(.cancelAction)
                Button("이동", action: browser.submitGoToFolder)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 530)
        .onAppear { pathFocused = true }
    }
}
