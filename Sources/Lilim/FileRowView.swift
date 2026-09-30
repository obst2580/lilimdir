import SwiftUI

struct FileRowView: View {
    let entry: FileEntry
    let selected: Bool
    var showDetails = false
    var detail: String?
    var iconMode = false

    var body: some View {
        if iconMode { iconTile }
        else { row }
    }

    private var iconTile: some View {
        VStack(spacing: 7) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: entry.url.path))
                .resizable().scaledToFit().frame(width: 44, height: 44)
            Text(entry.name).font(.system(size: 11)).lineLimit(2).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if entry.labelNumber != 0 {
                Circle().fill(FileTagColors.color(entry.labelNumber)).frame(width: 6, height: 6)
            }
        }
        .padding(7).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(selected ? Theme.accent.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 7))
    }

    private var row: some View {
        HStack(spacing: 9) {
            Image(systemName: entry.symbol)
                .font(.system(size: 14)).frame(width: 19)
                .foregroundStyle(entry.isNavigable ? Theme.accent : .secondary)
                .overlay(alignment: .bottomTrailing) {
                    if entry.isSymbolicLink {
                        Image(systemName: "arrow.turn.up.right").font(.system(size: 7, weight: .bold))
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                if let detail {
                    Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer(minLength: 4)
            if showDetails {
                Text(entry.isNavigable ? "폴더" : entry.kind + " · " + entry.sizeLabel).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            if entry.labelNumber != 0 {
                Circle().fill(FileTagColors.color(entry.labelNumber)).frame(width: 7, height: 7)
                    .help(entry.tags.joined(separator: ", "))
            }
            if entry.isNavigable {
                Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, detail == nil ? 6 : 8)
        .background(selected ? Theme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
