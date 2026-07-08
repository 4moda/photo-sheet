import Foundation

/// シートのレンダリングと保存を調整する
struct ExportSheetUseCase {
    /// 書き出し画像のデフォルトピクセル幅
    static let defaultPixelWidth: Double = 3000

    private let renderer: SheetRenderer
    private let saver: PhotoLibrarySaver

    init(renderer: SheetRenderer, saver: PhotoLibrarySaver) {
        self.renderer = renderer
        self.saver = saver
    }

    /// 共有用に PNG をレンダリングする
    @MainActor
    func render(sheet: Sheet, targetPixelWidth: Double = ExportSheetUseCase.defaultPixelWidth) throws -> Data {
        try renderer.renderPNG(sheet: sheet, targetPixelWidth: targetPixelWidth)
    }

    /// レンダリングしてカメラロールへ保存する
    @MainActor
    func saveToLibrary(sheet: Sheet, targetPixelWidth: Double = ExportSheetUseCase.defaultPixelWidth) async throws {
        let data = try render(sheet: sheet, targetPixelWidth: targetPixelWidth)
        try await saver.save(pngData: data)
    }
}
