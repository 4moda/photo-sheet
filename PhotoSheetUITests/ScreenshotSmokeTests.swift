import XCTest

/// 主要画面・主要状態・主要操作を巡回し、fastlane snapshot でスクリーンショットを撮る。
/// スクショ名は `画面ID[-機能ID]-action-in-english` の安全な ASCII 名。
/// 画面ID・機能IDは docs/screens.md の一覧と対応し、
/// tools/build_screenshot_index.py が生成する index.html で絞り込める。
///
/// 状態を決定論的にするため常に `--uitest`（一時ディレクトリ保存）で起動する。
/// デモ投入が要る画面は `--seed-demo` も付ける。
final class ScreenshotSmokeTests: XCTestCase {

    @MainActor
    private func makeApp(seed: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest"] + (seed ? ["--seed-demo"] : [])
        setupSnapshot(app)
        return app
    }

    // MARK: - S01 プロジェクト一覧（空）→ S02 空エディタ

    @MainActor
    func testEmptyStateAndNewSheet() throws {
        let app = makeApp(seed: false)
        app.launch()

        XCTAssertTrue(app.staticTexts["シートがありません"].waitForExistence(timeout: 15))
        snapshot("S01-F02-project-list-empty-state")

        app.buttons["新しいシートを作る"].tap()
        XCTAssertTrue(app.staticTexts["写真を追加"].waitForExistence(timeout: 10))
        snapshot("S02-F05-editor-empty-state")

        if app.buttons["完了"].waitForExistence(timeout: 3) {
            app.buttons["完了"].tap()
        }
    }

    // MARK: - S01 プロジェクト一覧（デモ）→ S02 エディタ巡回

    @MainActor
    func testEditorTour() throws {
        let app = makeApp(seed: true)
        app.launch()

        // S01: デモプロジェクトのカード
        XCTAssertTrue(app.staticTexts["DEMO ROLL"].waitForExistence(timeout: 15))
        sleep(1)
        snapshot("S01-F01-project-list-populated")

        // S02: キャンバス（グリッド）
        app.staticTexts["DEMO ROLL"].tap()
        XCTAssertTrue(app.buttons["見た目"].waitForExistence(timeout: 10))
        sleep(1)
        snapshot("S02-F01-canvas-grid")

        captureAddMenu(app)
        capturePhotoMenu(app)
        captureAppearancePanel(app)
        captureAdjustPanel(app)
        captureTextPanel(app)
        captureExportPanel(app)

        if app.buttons["完了"].waitForExistence(timeout: 3) {
            app.buttons["完了"].tap()
        }
    }

    // MARK: - [+] メニュー（追加・撮影順に並べ替え・全削除）

    @MainActor
    private func captureAddMenu(_ app: XCUIApplication) {
        let addButton = app.buttons["写真を追加"]
        guard addButton.waitForExistence(timeout: 5) else { return }
        addButton.tap()
        guard app.buttons["撮影順に並べ替え"].waitForExistence(timeout: 5) else { return }
        sleep(1)
        snapshot("S02-F02-add-menu")
        // 並べ替えは非破壊なのでそのまま実行してメニューを閉じる
        app.buttons["撮影順に並べ替え"].tap()
        sleep(1)
    }

    // MARK: - 写真タップメニュー（削除）

    @MainActor
    private func capturePhotoMenu(_ app: XCUIApplication) {
        // キャンバス中央付近の写真をタップ（confirmationDialog が開く）
        let canvas = app.scrollViews.firstMatch
        guard canvas.waitForExistence(timeout: 5) else { return }
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3)).tap()
        if app.buttons["削除"].waitForExistence(timeout: 3) {
            sleep(1)
            snapshot("S02-F03-photo-menu")
            if app.buttons["キャンセル"].exists {
                app.buttons["キャンセル"].tap()
            }
        }
    }

    // MARK: - 見た目パネル（グリッド / フィルム / スリーブ）

    @MainActor
    private func captureAppearancePanel(_ app: XCUIApplication) {
        guard app.buttons["見た目"].waitForExistence(timeout: 5) else { return }
        app.buttons["見た目"].tap()
        guard app.buttons["フィルム"].waitForExistence(timeout: 5) else { return }
        sleep(1)
        snapshot("S02-F10-appearance-panel-grid")

        app.buttons["フィルム"].tap()
        sleep(1)
        snapshot("S02-F11-film-style")

        // 120（6×6）: パーフォレーションなしのストリップ
        if app.buttons["6×6"].waitForExistence(timeout: 3) {
            app.buttons["6×6"].tap()
            sleep(1)
            snapshot("S02-F13-film-120-square")
            app.buttons["35mm"].tap()
        }

        app.buttons["スリーブ"].tap()
        sleep(1)
        snapshot("S02-F12-sleeve-style")

        app.buttons["グリッド"].tap()
        sleep(1)
        app.buttons["見た目"].tap()
        sleep(1)
    }

    // MARK: - 調整パネル（モノクロ + デート焼き込み）

    @MainActor
    private func captureAdjustPanel(_ app: XCUIApplication) {
        guard app.buttons["調整"].waitForExistence(timeout: 5) else { return }
        app.buttons["調整"].tap()
        guard app.switches["モノクロ"].waitForExistence(timeout: 5) else { return }
        sleep(1)
        snapshot("S02-F20-adjust-panel")

        app.switches["モノクロ"].switches.firstMatch.tap()
        if app.switches["デート焼き込み"].exists {
            app.switches["デート焼き込み"].switches.firstMatch.tap()
        }
        sleep(2)
        snapshot("S02-F21-monochrome-datestamp")

        // 後続の撮影に影響しないよう元へ戻す
        if app.buttons["リセット"].exists {
            app.buttons["リセット"].tap()
        }
        if app.switches["デート焼き込み"].exists {
            app.switches["デート焼き込み"].switches.firstMatch.tap()
        }
        sleep(1)
        app.buttons["調整"].tap()
        sleep(1)
    }

    // MARK: - タイトルパネル（撮影日自動キャプション）

    @MainActor
    private func captureTextPanel(_ app: XCUIApplication) {
        guard app.buttons["タイトル"].waitForExistence(timeout: 5) else { return }
        app.buttons["タイトル"].tap()
        guard app.switches["撮影日を自動で入れる"].waitForExistence(timeout: 5) else { return }
        sleep(1)
        snapshot("S02-F30-text-panel")

        app.switches["撮影日を自動で入れる"].switches.firstMatch.tap()
        sleep(1)
        snapshot("S02-F31-auto-date-caption")
        app.switches["撮影日を自動で入れる"].switches.firstMatch.tap()
        app.buttons["タイトル"].tap()
        sleep(1)
    }

    // MARK: - 書き出しパネル（画像 / 動画）

    @MainActor
    private func captureExportPanel(_ app: XCUIApplication) {
        guard app.buttons["書き出し"].waitForExistence(timeout: 5) else { return }
        app.buttons["書き出し"].tap()
        guard app.buttons["動画"].waitForExistence(timeout: 5) else { return }
        sleep(1)
        snapshot("S02-F40-export-image-panel")

        app.buttons["動画"].tap()
        sleep(1)
        snapshot("S02-F41-export-video-panel")
        app.buttons["書き出し"].tap()
        sleep(1)
    }
}
