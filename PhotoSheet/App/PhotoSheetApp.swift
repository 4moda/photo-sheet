import SwiftUI

@main
struct PhotoSheetApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ProjectListView(container: container)
                // 暗室のアンバー(Safelight)。Color.accentColor の自動解決に頼らず、
                // Assets.xcassets の名前付きカラーを明示的に環境へ伝播させる
                // (このビルド環境では暗黙の AccentColor 解決が効かなかったため)。
                .tint(Color("AccentColor"))
        }
    }
}
