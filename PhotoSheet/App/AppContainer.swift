import SwiftUI

/// Composition Root。レイヤーを跨ぐ依存はここで一括して組み立てる。
final class AppContainer {
    let imageCache = PhotoImageCache()

    @MainActor
    func makeSheetEditorViewModel() -> SheetEditorViewModel {
        let cache = imageCache
        // レンダラー（Data 層）には Presentation のキャンバスビューをビルダーとして注入する
        let renderer = SwiftUISheetRenderer { sheet, width in
            AnyView(SheetCanvasView(sheet: sheet, width: width, imageCache: cache))
        }
        return SheetEditorViewModel(
            importPhotosUseCase: ImportPhotosUseCase(repository: DefaultPhotoSourceRepository()),
            buildSheetUseCase: BuildSheetUseCase(),
            exportSheetUseCase: ExportSheetUseCase(renderer: renderer, saver: PhotoLibraryService()),
            imageCache: cache
        )
    }
}
