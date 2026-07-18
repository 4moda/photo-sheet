import Foundation

/// 画像書き出しの品質。UI 文言は DPI 数値を出さない定性的な表現にするため、
/// dpi 換算はこの型の内部実装詳細として持つ（印刷解像度を正しく算出するための計算単位）。
enum ImageExportQuality: String, CaseIterable, Equatable, Codable {
    /// 画面向け（現行の互換動作）
    case screen
    /// 印刷・標準品質
    case printStandard
    /// 印刷・高品質
    case printHigh

    /// 印刷相当の DPI。screen は物理紙面を前提としないため nil。
    var printDPI: Int? {
        switch self {
        case .screen: nil
        case .printStandard: 300
        case .printHigh: 600
        }
    }
}

/// シートのレンダリングと保存を調整する
struct ExportSheetUseCase {
    private let renderer: SheetRenderer
    private let saver: PhotoLibrarySaver

    /// レンダリング時に許容する最大ピクセル幅。非常に高い DPI 指定でもメモリ使用量が
    /// 過大にならないよう、この値へ自動的にクランプする（安全上限。警告 UI は別 Issue）。
    static let maxSafePixelWidth: Double = 6000

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

    /// 用紙フォーマットと DPI から目標ピクセル幅を計算する（用紙の物理幅 × DPI）。
    /// flexible / story9x16 は物理的な用紙サイズを持たない画面向けフォーマットのため対象外（nil を返す）。
    /// 算出結果が `maxSafePixelWidth` を超える場合は上限へクランプする。
    static func printPixelWidth(for format: PaperFormat, dpi: Int) -> Double? {
        guard let widthInches = format.printPhysicalWidthInches else { return nil }
        return min(widthInches * Double(dpi), maxSafePixelWidth)
    }

    /// 用紙フォーマットと選択品質から書き出しピクセル幅を決定する。
    /// 品質が印刷系でも用紙が対象外（flexible / story9x16）のときは画面向けの `defaultPixelWidth` にフォールバックする。
    static func targetPixelWidth(for format: PaperFormat, quality: ImageExportQuality) -> Double {
        guard let dpi = quality.printDPI, let width = printPixelWidth(for: format, dpi: dpi) else {
            return defaultPixelWidth(for: format)
        }
        return width
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
