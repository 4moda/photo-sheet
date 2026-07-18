import Foundation

/// シートの描画スタイル
enum SheetStyle: String, CaseIterable, Equatable, Codable {
    /// 均等グリッド（インデックスプリント風）
    case grid
    /// フィルムストリップ（ベタ焼き風）: 行 = 黒いレベート帯のストリップ
    case filmStrip
    /// ネガシート（スリーブ）: 現像所から返ってくるネガファイルの半透明ポケット風
    case negativeSleeve
}

/// フィルムの種類。コマの向きと比率、ストリップの見た目（パーフォレーションの有無）が決まる。
enum FilmFormat: String, CaseIterable, Equatable, Codable {
    /// 35mm フルフレーム: 36×24mm = 3:2 横向き
    case fullFrame
    /// ハーフフレーム: 18×24mm = 3:4 縦向き
    case halfFrame
    /// 120 フィルム 6×6 判: 56×56mm = 1:1
    case square66
    /// 120 フィルム 6×7 判: 56×70mm = 5:4 横向き
    case wide67

    /// コマの縦横比（幅 / 高さ）
    var frameAspect: Double {
        switch self {
        case .fullFrame: 3.0 / 2.0
        case .halfFrame: 3.0 / 4.0
        case .square66: 1.0
        case .wide67: 5.0 / 4.0
        }
    }

    /// パーフォレーション（スプロケット穴）の有無。35mm 系のみ。120 は裏紙送りで穴がない
    var hasSprocketHoles: Bool {
        switch self {
        case .fullFrame, .halfFrame: true
        case .square66, .wide67: false
        }
    }

    /// コマ番号の「8 / 8A」併記は 35mm の縁刻印。120 は番号のみ
    var usesSecondaryFrameNumber: Bool { hasSprocketHoles }
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
    /// バライタ印画紙風の温白（ごく薄い周辺減光付きで描かれる）
    case baryta
    /// ライトテーブル（発光ビュアー）。フィルムの刻印はアンバー発光になる
    case lightTable
    case custom(RGBAColor)

    var color: RGBAColor {
        switch self {
        case .white: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
        case .black: RGBAColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        case .paperGray: RGBAColor(red: 0.93, green: 0.92, blue: 0.90, alpha: 1)
        case .baryta: RGBAColor(red: 0.965, green: 0.945, blue: 0.91, alpha: 1)
        case .lightTable: RGBAColor(red: 0.97, green: 0.96, blue: 0.925, alpha: 1)
        case .custom(let color): color
        }
    }

    /// スタイル別の推奨デフォルト背景
    static func recommended(for style: SheetStyle) -> SheetBackground {
        switch style {
        case .grid: .white
        case .filmStrip: .black
        case .negativeSleeve: .paperGray
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
    /// フィルムの種類（filmStrip / negativeSleeve スタイル）
    var filmFormat: FilmFormat
    /// フィルムストリップの縁に白抜きで入れるエッジテキスト
    var filmEdgeText: String
    /// エッジテキストにコマ番号（▸12 など）を併記する
    var filmEdgeShowsFrameNumbers: Bool = false
    /// クォーツデート風のオレンジ日付を各コマ右下に焼き込む（EXIF 撮影日がある写真のみ）
    var showDateStamp: Bool = false
    /// シート全体の仕上げ調整（モノクロ・粒状感など）
    var adjustments: SheetAdjustments = .neutral

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

    /// エッジテキストのプリセット（実在銘柄は商標リスクがあるため汎用表記）
    static let filmEdgeTextPresets = [
        "PHOTO SHEET 400",
        "COLOR 400",
        "MONO 400",
        "CINE 800T",
        "EXPIRED 100"
    ]
}

// 後方互換の Codable 実装。保存済みプロジェクトの manifest に無いキーは
// デフォルト値へフォールバックし、フィールド追加で古いプロジェクトが開けなくなるのを防ぐ。
extension LayoutConfig {
    private enum CodingKeys: String, CodingKey {
        case columns, cellAspect, spacingRatio, marginRatio, background,
             showFilename, style, paperFormat, filmFormat, filmEdgeText,
             filmEdgeShowsFrameNumbers, showDateStamp, adjustments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = LayoutConfig.default
        columns = try container.decodeIfPresent(Int.self, forKey: .columns) ?? base.columns
        cellAspect = try container.decodeIfPresent(CellAspect.self, forKey: .cellAspect) ?? base.cellAspect
        spacingRatio = try container.decodeIfPresent(Double.self, forKey: .spacingRatio) ?? base.spacingRatio
        marginRatio = try container.decodeIfPresent(Double.self, forKey: .marginRatio) ?? base.marginRatio
        background = try container.decodeIfPresent(SheetBackground.self, forKey: .background) ?? base.background
        showFilename = try container.decodeIfPresent(Bool.self, forKey: .showFilename) ?? base.showFilename
        style = try container.decodeIfPresent(SheetStyle.self, forKey: .style) ?? base.style
        paperFormat = try container.decodeIfPresent(PaperFormat.self, forKey: .paperFormat) ?? base.paperFormat
        filmFormat = try container.decodeIfPresent(FilmFormat.self, forKey: .filmFormat) ?? base.filmFormat
        filmEdgeText = try container.decodeIfPresent(String.self, forKey: .filmEdgeText) ?? base.filmEdgeText
        filmEdgeShowsFrameNumbers = try container.decodeIfPresent(
            Bool.self, forKey: .filmEdgeShowsFrameNumbers
        ) ?? false
        showDateStamp = try container.decodeIfPresent(Bool.self, forKey: .showDateStamp) ?? false
        adjustments = try container.decodeIfPresent(SheetAdjustments.self, forKey: .adjustments) ?? .neutral
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(columns, forKey: .columns)
        try container.encode(cellAspect, forKey: .cellAspect)
        try container.encode(spacingRatio, forKey: .spacingRatio)
        try container.encode(marginRatio, forKey: .marginRatio)
        try container.encode(background, forKey: .background)
        try container.encode(showFilename, forKey: .showFilename)
        try container.encode(style, forKey: .style)
        try container.encode(paperFormat, forKey: .paperFormat)
        try container.encode(filmFormat, forKey: .filmFormat)
        try container.encode(filmEdgeText, forKey: .filmEdgeText)
        try container.encode(filmEdgeShowsFrameNumbers, forKey: .filmEdgeShowsFrameNumbers)
        try container.encode(showDateStamp, forKey: .showDateStamp)
        try container.encode(adjustments, forKey: .adjustments)
    }
}
