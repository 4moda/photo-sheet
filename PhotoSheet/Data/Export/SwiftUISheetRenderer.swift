import SwiftUI

/// プレビューと同じ SwiftUI ビューをそのまま高解像度 PNG にレンダリングする（WYSIWYG）。
/// キャンバスビュー自体は Presentation 層にあるため、Composition Root からビルダーとして注入する。
struct SwiftUISheetRenderer: SheetRenderer {
    /// レイアウト計算上の基準幅（pt）。レイアウトは幅比率ベースなのでこの値は品質に影響しない。
    static let baseWidth: CGFloat = 1000

    let canvasBuilder: @MainActor (Sheet, CGFloat) -> AnyView

    @MainActor
    func renderPNG(sheet: Sheet, targetPixelWidth: Double) throws -> Data {
        let view = canvasBuilder(sheet, Self.baseWidth)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: Self.baseWidth, height: nil)
        renderer.scale = max(1, targetPixelWidth / Self.baseWidth)
        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw SheetExportError.renderingFailed
        }
        return data
    }
}
