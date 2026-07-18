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

    /// 投稿先プリセット（出力アスペクト比・尺目安を決める）
    enum Preset: String, CaseIterable, Equatable, Codable {
        case storyReel // 9:16 Story/Reels 向け（既定）
        case feed      // 4:5 フィード向け
        case square    // 1:1 正方形

        /// 出力解像度（幅 1080px 固定、高さのみプリセットごとに変わる）
        var outputSize: CGSize {
            switch self {
            case .storyReel: CGSize(width: 1080, height: 1920)
            case .feed:      CGSize(width: 1080, height: 1350)
            case .square:    CGSize(width: 1080, height: 1080)
            }
        }

        /// パネルに表示する尺目安のテキスト（実際の長さを自動調整するものではない）
        var durationHint: String {
            switch self {
            case .storyReel: "90秒以内"
            case .feed:      "60秒以内"
            case .square:    "60秒以内"
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

    /// 投稿先プリセット
    var preset: Preset

    init(visibleRows: Int, speed: Speed, showOverview: Bool, preset: Preset = .storyReel) {
        self.visibleRows = visibleRows
        self.speed = speed
        self.showOverview = showOverview
        self.preset = preset
    }

    static let `default` = VideoExportConfig(
        visibleRows: 3,
        speed: .medium,
        showOverview: true
    )
}
