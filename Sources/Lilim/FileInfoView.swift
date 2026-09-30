import SwiftUI
import AppKit

struct FileInfoView: View {
    let selection: FileInfoSelection
    let browser: BrowserState
    @Environment(\.dismiss) private var dismiss
    @State private var details: FileInfoDetails?
    @State private var permissions = ""
    private let service = FileInfoService()
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                if let first = selection.entries.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: first.url.path)).resizable().frame(width: 48, height: 48)
                }
                Text(selection.entries.count == 1 ? selection.entries[0].name : "\(selection.entries.count)개 항목")
                    .font(.system(size: 18, weight: .semibold)).lineLimit(2)
            }
            Divider()
            if let details {
                LabeledContent("크기", value: ByteCountFormatter.string(fromByteCount: details.bytes, countStyle: .file))
                LabeledContent("파일 수", value: "\(details.files)")
                if let error = details.error { Text(error).foregroundStyle(.red).font(.system(size: 11)) }
            } else { HStack { ProgressView().controlSize(.small); Text("크기 계산 중…") } }
            if selection.entries.count == 1, let item = selection.entries.first {
                LabeledContent("종류", value: item.kind)
                if let date = item.createdAt { LabeledContent("생성일", value: date.formatted(date: .abbreviated, time: .shortened)) }
                if let date = item.modifiedAt { LabeledContent("수정일", value: date.formatted(date: .abbreviated, time: .shortened)) }
                if let details {
                    LabeledContent("소유자", value: details.owner)
                    HStack {
                        Text("접근 권한")
                        Spacer()
                        TextField("644", text: $permissions).frame(width: 58).textFieldStyle(.roundedBorder)
                        Button("변경") { if let value = Int(permissions, radix: 8) { browser.setPermissions(item.url, value: value) } }
                            .disabled(Int(permissions, radix: 8).map { !(0...0o777).contains($0) } ?? true)
                    }
                    Text("소유자·그룹·다른 사용자 순서의 8진수 권한입니다. 예: 644, 755")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    HStack {
                        LabeledContent("잠금", value: details.locked ? "잠김" : "잠기지 않음")
                        Button(details.locked ? "잠금 해제" : "잠금") { browser.setLocked(item.url, value: !details.locked) }
                    }
                }
                LabeledContent("태그", value: item.tags.joined(separator: ", "))
            }
            Text(selection.entries.map { $0.url.path }.joined(separator: "\n"))
                .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).lineLimit(8)
            HStack { Spacer(); Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction) }
        }.font(.system(size: 12)).padding(24).frame(width: 520)
            .task { details = await service.details(selection.entries.map(\.url)); permissions = details?.permissions ?? "" }
    }
}
