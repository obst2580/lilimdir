import SwiftUI

struct BatchRenameSheet: View {
    @Bindable var browser: BrowserState
    let selection: FileInfoSelection
    @State private var mode = BatchRenameMode.prefix
    @State private var text = ""
    @State private var replacement = ""
    @State private var start = 1
    private var plan: [(URL, String)] {
        selection.entries.enumerated().map { index, entry in
            (entry.url, mode.name(for: entry, index: index, text: text, replacement: replacement, start: start))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(selection.entries.count)개 항목의 이름 변경").font(.system(size: 18, weight: .semibold))
            Picker("방식", selection: $mode) { ForEach(BatchRenameMode.allCases) { Text($0.title).tag($0) } }
            TextField(mode == .replace ? "찾을 텍스트" : "추가할 이름", text: $text).textFieldStyle(.roundedBorder)
            if mode == .replace { TextField("바꿀 텍스트", text: $replacement).textFieldStyle(.roundedBorder) }
            if mode == .numbered { Stepper("시작 번호: \(start)", value: $start, in: 0...999999) }
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(plan.enumerated()), id: \.offset) { _, item in
                        Text(item.0.lastPathComponent + " → " + item.1).font(.system(size: 11)).lineLimit(1).help(item.1)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(height: 140)
            Text(mode == .replace ? "텍스트 대치는 확장자를 포함합니다. 이름 충돌 시 변경을 시작하지 않습니다." : "확장자를 유지합니다. 이름 충돌 시 변경을 시작하지 않습니다.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("취소") { browser.batchRenameSelection = nil }.keyboardShortcut(.cancelAction)
                Button("이름 변경") { browser.submitBatchRename(plan) }.buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction).disabled(text.isEmpty)
            }
        }.padding(24).frame(width: 520)
    }
}
