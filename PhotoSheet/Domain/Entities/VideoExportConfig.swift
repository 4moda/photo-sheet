import Foundation

/// スクロール動画の書き出し設定
struct VideoExportConfig: Equatable, Codable {

    /// カメラの移動方向
    enum ScrollDirection: String, CaseIterable, Equatable, Codable {
        /// 縦（上→下）: キャンバスを垂直にスクロール
        case vertical
        /// 横（左→右）: キャンバスを 2× 幅でレンダリングし、左列から右列へ流れる
        case horizontal
        /// 斜め（左上→右下）: 縦と横を同時に動かすシネマティックな走査
        case diagonal
    }

    /// 動画の総再生時間（秒）
    var durationSeconds: Double
    /// カメラの移動方向
    var direction: ScrollDirection

    static let `default` = VideoExportConfig(durationSeconds: 20, direction: .vertical)
    static let durationPresets: [Double] = [10, 15, 20, 30]
}
