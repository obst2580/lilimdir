import SwiftUI

struct FileNameSheet: View {
    @Bindable var browser: BrowserState
    let prompt: FileNamePrompt
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(prompt.title).font(.system(size: 18, weight: .semibold))
            TextField("이름", text: $browser.nameInput).textFieldStyle(.roundedBorder)
                .focused($focused).onSubmit(browser.submitNamePrompt)
            Text(PathUtilities.displayPath(prompt.directory)).font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(2).textSelection(.enabled)
            HStack {
                Spacer()
                Button("취소") { browser.namePrompt = nil }.keyboardShortcut(.cancelAction)
                Button("확인", action: browser.submitNamePrompt).buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction).disabled(browser.nameInput.isEmpty)
            }
        }.padding(24).frame(width: 430).onAppear { focused = true }
    }
}
