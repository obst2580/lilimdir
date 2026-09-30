import Foundation

enum BrowserViewMode: String, CaseIterable, Identifiable {
    case icons, list, columns, gallery
    var id: String { rawValue }
    var title: String {
        switch self { case .icons: "아이콘"; case .list: "목록"; case .columns: "컬럼"; case .gallery: "갤러리" }
    }
    var symbol: String {
        switch self { case .icons: "square.grid.2x2"; case .list: "list.bullet"; case .columns: "rectangle.split.3x1"; case .gallery: "rectangle.bottomthird.inset.filled" }
    }
}
