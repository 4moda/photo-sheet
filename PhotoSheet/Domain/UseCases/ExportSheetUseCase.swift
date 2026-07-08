import Foundation

/// シートのレンダリングと保存を調整する
struct ExportSheetUseCase {
    private let renderer: SheetRenderer
    private let saver: PhotoLibrarySaver

    init(renderer: SheetRenderer, saver: PhotoLibrarySaver) {
        self.renderer = renderer
        self.saver = saver
    }

    /// 用紙フォーマットに応じた書き出しピクセル幅。
    /// SNS 利用を主想定とし、印刷系の用紙を選んだときだけ印刷品質に寄せる。
    /// - SNS 系: 2160px（Instagram の表示解像度 1080px の 2 倍。圧縮・再リサイズ耐性を確保）
    /// - 印刷系: 2400px（8×10 で 300dpi 相当、A4 で約 290dpi）
    static func defaultPixelWidth(for format: PaperFormat) -> Double {
        switch format {
        case .print8x10, .print4x6, .a4: 2400
        case .flexible, .story9x16: 2160
        }
    }

    /// 共有用に PNG をレンダリングする
    @MainActor
    func render(sheet: Sheet, targetPixelWidth: Double? = nil) throws -> Data {
        let width = targetPixelWidth ?? Self.defaultPixelWidth(for: sheet.layout.paperFormat)
        return try renderer.renderPNG(sheet: sheet, targetPixelWidth: width)
    }

    /// レンダリングしてカメラロールへ保存する
    @MainActor
    func saveToLibrary(sheet: Sheet, targetPixelWidth: Double? = nil) async throws {
        let data = try render(sheet: sheet, targetPixelWidth: targetPixelWidth)
        try await saver.save(pngData: data)
    }
}
