import SwiftUI

/// Composition Root。レイヤーを跨ぐ依存はここで一括して組み立てる。
final class AppContainer {
    let imageCache = PhotoImageCache()
    private let projectRepository = FileSheetProjectRepository()

    @MainActor
    func makeProjectListViewModel() -> ProjectListViewModel {
        ProjectListViewModel(repository: projectRepository)
    }

    @MainActor
    func makeSheetEditorView(project: SheetProject) -> SheetEditorView {
        SheetEditorView(
            viewModel: makeSheetEditorViewModel(project: project),
            imageCache: imageCache
        )
    }

    @MainActor
    func makeSheetEditorViewModel(project: SheetProject) -> SheetEditorViewModel {
        let cache = imageCache
        // レンダラー（Data 層）には Presentation のキャンバスビューをビルダーとして注入する
        let renderer = SwiftUISheetRenderer { sheet, width in
            AnyView(SheetCanvasView(sheet: sheet, width: width, imageCache: cache))
        }
        return SheetEditorViewModel(
            project: project,
            importPhotosUseCase: ImportPhotosUseCase(repository: DefaultPhotoSourceRepository()),
            buildSheetUseCase: BuildSheetUseCase(),
            exportSheetUseCase: ExportSheetUseCase(renderer: renderer, saver: PhotoLibraryService()),
            imageCache: cache,
            projectRepository: projectRepository
        )
    }
}
