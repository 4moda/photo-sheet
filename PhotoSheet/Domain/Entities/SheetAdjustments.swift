import Foundation

/// シート全体へ一括で効くフィルム風の仕上げ調整。
/// 暗室でのプリント作業（号数・調色・覆い焼き）をメタファーにした最小セットで、
/// 値はすべて 0 / false がニュートラル（無効果）。描画実装（CoreImage 等）には依存しない。
struct SheetAdjustments: Equatable, Codable {
    /// モノクロ（彩度 0）。ON のとき色温度は調色（温黒調 / 冷黒調）として効く
    var monochrome: Bool = false
    /// コントラスト（-1〜1）。印画紙の号数を上下するイメージ
    var contrast: Double = 0
    /// 粒状感（0〜1）。ネガ由来のグレインなので写真ごとに乗る
    var grain: Double = 0
    /// フェード: シャドウの黒浮き（0〜1）。経年プリントの軟調
    var fade: Double = 0
    /// 色温度（-1: 冷調 〜 1: 温調）
    var temperature: Double = 0
    /// 周辺減光（0〜1）。レンズ由来なので写真ごとに乗る
    var vignette: Double = 0

    static let neutral = SheetAdjustments()

    var isNeutral: Bool { self == .neutral }
}
