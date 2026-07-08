import SwiftUI
import UIKit

extension Color {
    init(rgba: RGBAColor) {
        self.init(red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}

extension RGBAColor {
    init(color: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}

extension CellAspect {
    var displayName: String {
        switch self {
        case .original: "元の比率"
        case .film3x2: "3:2"
        case .square: "1:1"
        }
    }
}

extension SheetStyle {
    var displayName: String {
        switch self {
        case .grid: "グリッド"
        case .filmStrip: "フィルム"
        }
    }
}

extension FilmFormat {
    var displayName: String {
        switch self {
        case .fullFrame: "35mm"
        case .halfFrame: "ハーフ"
        }
    }
}

extension PaperFormat {
    var displayName: String {
        switch self {
        case .flexible: "自由"
        case .print8x10: "8×10"
        case .print4x6: "4×6"
        case .a4: "A4"
        case .story9x16: "9:16"
        }
    }
}

extension VideoExportConfig.ScrollDirection {
    var displayName: String {
        switch self {
        case .vertical:   "縦"
        case .horizontal: "横"
        case .diagonal:   "斜め"
        }
    }

    var icon: String {
        switch self {
        case .vertical:   "arrow.down"
        case .horizontal: "arrow.right"
        case .diagonal:   "arrow.down.right"
        }
    }
}
