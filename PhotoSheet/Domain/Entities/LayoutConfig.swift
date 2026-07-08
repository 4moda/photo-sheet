import Foundation

/// シートの描画スタイル
enum SheetStyle: String, CaseIterable, Equatable {
    /// 均等グリッド（インデックスプリント風）
    case grid
    /// フィルムストリップ（ベタ焼き風）: 行 = 黒いレベート帯の 6 コマストリップ
    case filmStrip
}

/// 用紙フォーマット。固定比率を選ぶと定型プリントのようにシート全体の縦横比が固定される。
enum PaperFormat: String, CaseIterable, Equatable {
    case flexible
    case print8x10
    case print4x6
    case a4
    case story9x16

    /// 幅 / 高さ（縦向き）。flexible は内容に応じて可変（nil）。
    var aspectRatio: Double? {
        switch self {
        case .flexible: nil
        case .print8x10: 8.0 / 10.0
        case .print4x6: 4.0 / 6.0
        case .a4: 1.0 / 1.4142
        case .story9x16: 9.0 / 16.0
        }
    }
}

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
    /// 各セルの下にファイル名（コマ番号相当）を表示するか（grid スタイルのみ）
    var showFilename: Bool
    var style: SheetStyle
    var paperFormat: PaperFormat
    /// フィルムストリップの縁に白抜きで入れるエッジテキスト
    var filmEdgeText: String

    /// デフォルトは 6 列（35mm ベタ焼きの伝統的な列数）
    static let `default` = LayoutConfig(
        columns: 6,
        cellAspect: .film3x2,
        spacingRatio: 0.012,
        marginRatio: 0.05,
        background: .white,
        showFilename: false,
        style: .grid,
        paperFormat: .flexible,
        filmEdgeText: "PHOTO SHEET 400"
    )

    /// 選べる列数のプリセット（6 列は 35mm ベタ焼きの伝統的な列数）
    static let columnPresets = [2, 3, 4, 6]
}
