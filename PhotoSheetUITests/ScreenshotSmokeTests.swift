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

    /// フローティングバーのボタンを座標でタップする。
    /// バーは ScrollView 外のオーバーレイのため、通常の tap() が使う AX の
    /// 自動スクロール（kAXScrollToVisibleAction）が失敗することがある。
    /// photo-layout と同じく coordinate タップで回避する。
    @MainActor
    @discardableResult
    private func tapBarButton(_ app: XCUIApplication, _ label: String) -> Bool {
        let button = app.buttons[label]
        guard button.waitForExistence(timeout: 5) else { return false }
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return true
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

        // S01: デモプロジェクトのカード（サムネイル付きの一覧はツアー末尾で撮る）
        XCTAssertTrue(app.staticTexts["DEMO ROLL"].waitForExistence(timeout: 15))

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

        // 完了 = 保存完了を待ってから閉じる → 一覧にサムネイル付きカードが並ぶ
        if app.buttons["完了"].waitForExistence(timeout: 3) {
            app.buttons["完了"].tap()
        }
        XCTAssertTrue(app.staticTexts["DEMO ROLL"].waitForExistence(timeout: 10))
        sleep(2)
        snapshot("S01-F01-project-list-populated")
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
        // キャンバスの写真をタップ（confirmationDialog が開く）。
        // 画像要素が取れればそれを、だめなら座標でタップする
        let canvas = app.scrollViews.firstMatch
        guard canvas.waitForExistence(timeout: 5) else { return }
        let photo = canvas.images.firstMatch
        if photo.waitForExistence(timeout: 3) {
            photo.tap()
        } else {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3)).tap()
        }
        if app.buttons["削除"].waitForExistence(timeout: 3) {
            sleep(1)
            snapshot("S02-F03-photo-menu")
            if app.buttons["キャンセル"].exists {
                app.buttons["キャンセル"].tap()
            }
            // ダイアログの dismiss アニメーション完了を待つ（直後のバータップが吸われるのを防ぐ）
            sleep(1)
        }
    }

    // MARK: - 見た目パネル（グリッド / フィルム / スリーブ）

    @MainActor
    private func captureAppearancePanel(_ app: XCUIApplication) {
        guard tapBarButton(app, "見た目") else { return }
        if !app.buttons["フィルム"].waitForExistence(timeout: 3) {
            // ダイアログ閉じ直後などでタップが吸われた場合に一度だけ開き直す
            tapBarButton(app, "見た目")
            guard app.buttons["フィルム"].waitForExistence(timeout: 5) else { return }
        }
        sleep(1)
        snapshot("S02-F10-appearance-panel-grid")

        app.buttons["フィルム"].tap()
        sleep(1)
        snapshot("S02-F11-film-style")

        // 120（6×6）: パーフォレーションなしのストリップ。
        // フィルム選択セグメントは見た目パネルの ZStack（フィルム/スリーブ両バリアント）に
        // 同名で存在し曖昧になるため、firstMatch + 座標タップで可視側（ヒットテスト有効側）を押す
        let mediumFormat = app.buttons["6×6"].firstMatch
        if mediumFormat.waitForExistence(timeout: 3) {
            mediumFormat.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(1)
            snapshot("S02-F13-film-120-square")
            app.buttons["35mm"].firstMatch
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(1)
        }

        app.buttons["スリーブ"].tap()
        sleep(1)
        snapshot("S02-F12-sleeve-style")

        app.buttons["グリッド"].tap()
        sleep(1)
        tapBarButton(app, "見た目")
        sleep(1)
    }

    // MARK: - 調整パネル（モノクロ + デート焼き込み）

    @MainActor
    private func captureAdjustPanel(_ app: XCUIApplication) {
        guard tapBarButton(app, "調整") else { return }
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
        tapBarButton(app, "調整")
        sleep(1)
    }

    // MARK: - タイトルパネル（撮影日自動キャプション）

    @MainActor
    private func captureTextPanel(_ app: XCUIApplication) {
        guard tapBarButton(app, "タイトル") else { return }
        guard app.switches["撮影日を自動で入れる"].waitForExistence(timeout: 5) else { return }
        sleep(1)
        snapshot("S02-F30-text-panel")

        app.switches["撮影日を自動で入れる"].switches.firstMatch.tap()
        sleep(1)
        snapshot("S02-F31-auto-date-caption")
        app.switches["撮影日を自動で入れる"].switches.firstMatch.tap()
        tapBarButton(app, "タイトル")
        sleep(1)
    }

    // MARK: - 書き出しパネル（画像 / 動画）

    @MainActor
    private func captureExportPanel(_ app: XCUIApplication) {
        guard tapBarButton(app, "書き出し") else { return }
        guard app.buttons["動画"].waitForExistence(timeout: 5) else { return }
        sleep(1)
        snapshot("S02-F40-export-image-panel")

        app.buttons["動画"].tap()
        sleep(1)
        snapshot("S02-F41-export-video-panel")
        tapBarButton(app, "書き出し")
        sleep(1)
    }
}
