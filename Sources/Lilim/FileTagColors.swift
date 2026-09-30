import SwiftUI

enum FileTagColors {
    static let labels = ["없음", "회색", "초록", "보라", "파랑", "노랑", "빨강", "주황"]
    static func color(_ label: Int) -> Color {
        switch label {
        case 1: .gray
        case 2: .green
        case 3: .purple
        case 4: .blue
        case 5: .yellow
        case 6: .red
        case 7: .orange
        default: .clear
        }
    }
}
