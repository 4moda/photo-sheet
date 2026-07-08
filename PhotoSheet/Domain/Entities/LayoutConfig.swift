import Foundation

/// セルの縦横比
enum CellAspect: String, CaseIterable, Equatable {
    /// 各写真の元の比率を尊重する
    case original
    /// 35mm フィルムのコマと同じ 3:2（ベタ焼き風）
    case film3x2
    /// 正方形
    case square
}

/// プラットフォーム非依存の色表現
struct RGBAColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}

/// シートの背景
enum SheetBackground: Equatable {
    case white
    case black
    case paperGray
    case custom(RGBAColor)

    var color: RGBAColor {
        switch self {
        case .white: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
        case .black: RGBAColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        case .paperGray: RGBAColor(red: 0.93, green: 0.92, blue: 0.90, alpha: 1)
        case .custom(let color): color
        }
    }
}

/// シートのレイアウト設定。
/// 余白・間隔はシート幅に対する「比率」で持つため、どの解像度で描画しても相似形になる（WYSIWYG の要）。
struct LayoutConfig: Equatable {
    var columns: Int
    var cellAspect: CellAspect
    /// セル間隔（シート幅に対する比率）
    var spacingRatio: Double
    /// 外余白（シート幅に対する比率）
    var marginRatio: Double
    var background: SheetBackground
    /// 各セルの下にファイル名（コマ番号相当）を表示するか
    var showFilename: Bool

    static let `default` = LayoutConfig(
        columns: 4,
        cellAspect: .film3x2,
        spacingRatio: 0.012,
        marginRatio: 0.05,
        background: .white,
        showFilename: false
    )

    /// 選べる列数のプリセット（6 列は 35mm ベタ焼きの伝統的な列数）
    static let columnPresets = [2, 3, 4, 6]

    /// 枚数に応じたデフォルト列数。
    /// 伝統的なベタ焼きは 6 列固定だが、少枚数では間延びするため枚数に応じて寄せる。
    static func defaultColumns(forPhotoCount count: Int) -> Int {
        switch count {
        case ...4: 2
        case ...9: 3
        case ...16: 4
        default: 6
        }
    }
}
