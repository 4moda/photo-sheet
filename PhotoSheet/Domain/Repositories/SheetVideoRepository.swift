import Foundation

/// シートをスクロール動画へレンダリングする境界
/// 実装は AVFoundation に依存するため Data 層に置く。
protocol SheetVideoRenderer {
    /// - Parameters:
    ///   - outputURL: 書き出し先（既存ファイルは上書き）
    ///   - onProgress: 進捗コールバック（0.0〜1.0、メインスレッドから呼ばれる）
    @MainActor func renderVideo(
        sheet: Sheet,
        config: VideoExportConfig,
        outputURL: URL,
        onProgress: @Sendable (Double) async -> Void
    ) async throws
}

/// 動画ファイルをカメラロールへ保存する境界
protocol VideoLibrarySaver {
    func saveVideo(at url: URL) async throws
}

enum VideoExportError: Error {
    case renderingFailed
    case writingFailed
    case authorizationDenied
    case saveFailed
}
