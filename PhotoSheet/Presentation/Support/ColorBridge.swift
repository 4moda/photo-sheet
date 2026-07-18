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
        case .negativeSleeve: "スリーブ"
        }
    }
}

extension FilmFormat {
    var displayName: String {
        switch self {
        case .fullFrame: "35mm"
        case .halfFrame: "ハーフ"
        case .square66: "6×6"
        case .wide67: "6×7"
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

extension SheetBackground {
    var accessibilityName: String {
        switch self {
        case .white: "白"
        case .black: "黒"
        case .paperGray: "グレー"
        case .baryta: "バライタ"
        case .lightTable: "ライトテーブル"
        case .custom: "カスタム"
        }
    }
}

extension VideoExportConfig.Speed {
    var displayName: String {
        switch self {
        case .slow:   "ゆっくり"
        case .medium: "ふつう"
        case .fast:   "はやく"
        }
    }
}

extension ImageExportQuality {
    var displayName: String {
        switch self {
        case .screen: "コンパクト"
        case .printStandard: "普通"
        case .printHigh: "高画質"
        }
    }
}
