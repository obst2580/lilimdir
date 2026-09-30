import SwiftUI

struct FileTagsSheet: View {
    @Bindable var browser: BrowserState
    let selection: FileInfoSelection
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(selection.entries.count)개 항목의 태그").font(.system(size: 18, weight: .semibold))
            TextField("태그를 쉼표로 구분하세요", text: $browser.tagInput).textFieldStyle(.roundedBorder)
            if selection.entries.count > 1 { Toggle("기존 태그를 유지하고 추가", isOn: $browser.appendTags) }
            Picker("색상", selection: $browser.tagLabel) {
                ForEach(0..<FileTagColors.labels.count, id: \.self) { number in
                    Text(FileTagColors.labels[number]).tag(number)
                }
            }.pickerStyle(.segmented)
            Text("Finder에서도 같은 태그를 확인할 수 있습니다.").font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("모든 태그 제거") { browser.tagInput = ""; browser.tagLabel = 0; browser.appendTags = false; browser.submitTags() }
                Spacer()
                Button("취소") { browser.tagSelection = nil }.keyboardShortcut(.cancelAction)
                Button("적용", action: browser.submitTags).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 560)
    }
}
