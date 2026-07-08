import SwiftUI

@main
struct PhotoSheetApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ProjectListView(container: container)
        }
    }
}
