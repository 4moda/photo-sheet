import Foundation

/// シートを PNG 画像へレンダリングする境界
protocol SheetRenderer {
    /// - Parameter targetPixelWidth: 書き出す画像のピクセル幅
    @MainActor func renderPNG(sheet: Sheet, targetPixelWidth: Double) throws -> Data
}

/// レンダリング済み画像の保存先（カメラロール）
protocol PhotoLibrarySaver {
    func save(pngData: Data) async throws
}

enum SheetExportError: Error {
    case renderingFailed
    case authorizationDenied
    case saveFailed
}
