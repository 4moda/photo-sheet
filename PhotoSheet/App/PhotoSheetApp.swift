import SwiftUI

@main
struct PhotoSheetApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            SheetEditorView(
                viewModel: container.makeSheetEditorViewModel(),
                imageCache: container.imageCache
            )
        }
    }
}
