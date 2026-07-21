import SwiftUI
import UIKit

@main
struct PhotoSheetApp: App {
    private let container = AppContainer()

    init() {
        Self.configureSegmentedControlAppearance()
        Self.configureSwitchAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ProjectListView(container: container)
                // 暗室のアンバー(Safelight)。Color.accentColor の自動解決に頼らず、
                // Assets.xcassets の名前付きカラーを明示的に環境へ伝播させる
                // (このビルド環境では暗黙の AccentColor 解決が効かなかったため)。
                .tint(Color("AccentColor"))
                // ダークモードのスポットチェック撮影用（UITestSeeder 参照）。
                // 通常起動では forcesDarkMode が false なので nil = システム設定に従う。
                .preferredColorScheme(UITestSeeder.forcesDarkMode ? .dark : nil)
        }
    }

    /// 見た目パネル等の UISegmentedControl（グリッド/フィルム/用紙…）の選択ピルを
    /// system blue 依存の既定スタイルから Safelight へ。選択文字色は CardSurface を再利用
    /// （ライト時は暗いアンバー地に白紙色、ダーク時は明るいアンバー地に濃い紙色になり、
    /// どちらの配色でもコントラストが逆転しない）。
    private static func configureSegmentedControlAppearance() {
        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = UIColor(named: "AccentColor")
        segmented.setTitleTextAttributes(
            [.foregroundColor: UIColor(named: "CardSurface") ?? .white],
            for: .selected
        )
    }

    /// モノクロ・ファイル名表示・コマ番号刻印・撮影日自動表示などのトグルも
    /// iOS 既定の緑ではなく Safelight で統一する。
    private static func configureSwitchAppearance() {
        UISwitch.appearance().onTintColor = UIColor(named: "AccentColor")
    }
}
