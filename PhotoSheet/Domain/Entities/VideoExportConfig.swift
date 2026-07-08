import Foundation

/// スクロール動画の書き出し設定（V2: Z スキャン方式）
struct VideoExportConfig: Equatable, Codable {

    /// スクロール速度プリセット（キャンバス座標系での px/秒）
    enum Speed: String, CaseIterable, Equatable, Codable {
        case slow   // 80 px/sec: じっくり見られる
        case medium // 160 px/sec: 標準
        case fast   // 320 px/sec: テンポよく流れる

        var canvasPixelsPerSecond: Double {
            switch self {
            case .slow:   80
            case .medium: 160
            case .fast:   320
            }
        }
    }

    /// 1ストリップあたりの表示行数（＝ズーム具合）
    /// 少ないほど写真が大きく、多いほど全体俯瞰に近い
    var visibleRows: Int

    /// スクロール速度
    var speed: Speed

    /// 前後に全体俯瞰フェーズ（静止）を挿入するか
    var showOverview: Bool

    static let `default` = VideoExportConfig(
        visibleRows: 3,
        speed: .medium,
        showOverview: true
    )
}
