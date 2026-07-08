import Foundation

/// スクロール動画のレンダリングとカメラロールへの保存を調整する
struct ExportSheetVideoUseCase {
    private let renderer: SheetVideoRenderer
    private let saver: VideoLibrarySaver

    init(renderer: SheetVideoRenderer, saver: VideoLibrarySaver) {
        self.renderer = renderer
        self.saver = saver
    }

    /// 動画をテンポラリファイルへレンダリングし、その URL を返す（共有用）
    @MainActor
    func render(
        sheet: Sheet,
        config: VideoExportConfig,
        onProgress: @Sendable (Double) async -> Void = { _ in }
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try await renderer.renderVideo(sheet: sheet, config: config, outputURL: outputURL, onProgress: onProgress)
        return outputURL
    }

    /// レンダリングしてカメラロールへ保存する
    @MainActor
    func saveToLibrary(
        sheet: Sheet,
        config: VideoExportConfig,
        onProgress: @Sendable (Double) async -> Void = { _ in }
    ) async throws {
        let url = try await render(sheet: sheet, config: config, onProgress: onProgress)
        defer { try? FileManager.default.removeItem(at: url) }
        try await saver.saveVideo(at: url)
    }
}
