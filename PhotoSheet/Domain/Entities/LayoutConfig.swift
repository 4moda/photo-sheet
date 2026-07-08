import Foundation

/// シートの描画スタイル
enum SheetStyle: String, CaseIterable, Equatable, Codable {
    /// 均等グリッド（インデックスプリント風）
    case grid
    /// フィルムストリップ（ベタ焼き風）: 行 = 黒いレベート帯のストリップ
    case filmStrip
}

/// フィルムの種類。コマの向きと比率が決まる。
enum FilmFormat: String, CaseIterable, Equatable, Codable {
    /// 35mm フルフレーム: 36×24mm = 3:2 横向き
    case fullFrame
    /// ハーフフレーム: 18×24mm = 3:4 縦向き
    case halfFrame

    /// コマの縦横比（幅 / 高さ）
    var frameAspect: Double {
        switch self {
        case .fullFrame: 3.0 / 2.0
        case .halfFrame: 3.0 / 4.0
        }
    }
}

/// 用紙フォーマット。固定比率を選ぶと定型プリントのようにシート全体の縦横比が固定される。
enum PaperFormat: String, CaseIterable, Equatable, Codable {
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

/// セルの縦横比（grid スタイル用）
enum CellAspect: String, CaseIterable, Equatable, Codable {
    /// 各写真の元の比率を尊重する
    case original
    /// 35mm フィルムのコマと同じ 3:2（ベタ焼き風）
    case film3x2
    /// 正方形
    case square
}

/// プラットフォーム非依存の色表現
struct RGBAColor: Equatable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}

/// シートの背景
enum SheetBackground: Equatable, Codable {
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

    /// スタイル別の推奨デフォルト背景
    static func recommended(for style: SheetStyle) -> SheetBackground {
        switch style {
        case .grid: .white
        case .filmStrip: .black
        }
    }
}

/// シートのレイアウト設定。
/// 余白・間隔はシート幅に対する「比率」で持つため、どの解像度で描画しても相似形になる（WYSIWYG の要）。
struct LayoutConfig: Equatable, Codable {
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
    /// フィルムの種類（filmStrip スタイルのみ）
    var filmFormat: FilmFormat
    /// フィルムストリップの縁に白抜きで入れるエッジテキスト
    var filmEdgeText: String

    /// デフォルトは 6 列（35mm ベタ焼きの伝統的な列数）。
    /// 用紙は一般的なコンタクトシート運用に合わせて 8x10 を既定にする。
    static let `default` = LayoutConfig(
        columns: 6,
        cellAspect: .film3x2,
        spacingRatio: 0.012,
        marginRatio: 0.05,
        background: .recommended(for: .grid),
        showFilename: false,
        style: .grid,
        paperFormat: .print8x10,
        filmFormat: .fullFrame,
        filmEdgeText: "PHOTO SHEET 400"
    )

    /// 選べる列数のプリセット（6 列は 35mm ベタ焼きの伝統的な列数）
    static let columnPresets = [2, 3, 4, 6]
}
