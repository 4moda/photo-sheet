import SnapshotTesting
import SwiftUI
import XCTest
@testable import PhotoSheet

/// SheetCanvasView のスナップショットテスト。
/// 写真セルは無効データのためグレープレースホルダー（Color.gray.opacity(0.15)）で描画される。
/// キャンバスのレイアウト構造（余白・間隔・グリッド・フィルムストリップ）の回帰検知が目的。
///
/// # 参照画像の更新
/// GitHub Actions の「Update Snapshots」ワークフローを手動実行 →
/// Artifacts の `snapshot-images` をダウンロードして
/// `PhotoSheetSnapshotTests/__Snapshots__/SheetCanvasViewSnapshotTests/` に展開 → コミット。
final class SheetCanvasViewSnapshotTests: XCTestCase {

    /// テスト用の固定幅（iPhone 16 論理幅）
    private static let canvasWidth: CGFloat = 390

    /// RECORD_SNAPSHOTS=true のとき参照画像を上書き生成する（CI の Update Snapshots ジョブで使用）。
    /// nil のときはライブラリのデフォルト（.missing: 参照画像がなければ記録して fail）を使う。
    private static var recordMode: SnapshotTestingConfiguration.Record? {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "true" ? .all : nil
    }

    private let imageCache = PhotoImageCache()

    // MARK: - ヘルパー

    private func makePhotos(_ count: Int, aspectRatio: Double = 1.5) -> [SheetPhoto] {
        (1...count).map { index in
            // 無効な画像データ → PhotoImageCache のデコードが失敗 → グレープレースホルダー表示
            SheetPhoto(
                fileName: "IMG_\(String(format: "%04d", index))",
                imageData: Data([0x01]),
                aspectRatio: aspectRatio
            )
        }
    }

    /// スナップショットの土台となるレイアウト。
    /// これらのテストは「キャンバスのレイアウト構造」の回帰検知が目的なので、
    /// 可変な `LayoutConfig.default`（用紙デフォルトは変わりうる）に追従させず、
    /// 用紙は常に `.flexible`（自然な高さ）に固定して描く。
    /// 用紙固定モードの挙動は `testGrid_fixedPaper_8x10` が個別に検証する。
    private func baseLayout() -> LayoutConfig {
        var layout = LayoutConfig.default
        layout.paperFormat = .flexible
        return layout
    }

    /// ビューをスナップショットと比較（またはレコード）する。
    /// sizeThatFits を使うことで SheetCanvasView の frame に合わせた自然なサイズで描画する。
    private func assertCanvas<V: View>(
        _ view: V,
        named name: String? = nil,
        testName: String = #function
    ) {
        assertSnapshot(
            of: view,
            as: .image(
                layout: .sizeThatFits,
                traits: UITraitCollection(userInterfaceStyle: .light)
            ),
            named: name,
            record: Self.recordMode,
            testName: testName
        )
    }

    // MARK: - グリッドスタイル

    /// グリッド 6 列・3:2 固定比率（デフォルト設定）
    func testGrid_6columns_film3x2() {
        var layout = baseLayout()
        layout.columns = 6
        layout.cellAspect = .film3x2
        layout.showFilename = false
        let sheet = Sheet(photos: makePhotos(12), layout: layout)
        let view = SheetCanvasView(
            sheet: sheet, width: Self.canvasWidth, imageCache: imageCache
        )
        assertCanvas(view)
    }

    /// グリッド 3 列・元の比率・ファイル名ラベルあり
    func testGrid_3columns_original_withFilename() {
        var layout = baseLayout()
        layout.columns = 3
        layout.cellAspect = .original
        layout.showFilename = true
        let sheet = Sheet(photos: makePhotos(6, aspectRatio: 1.5), layout: layout)
        let view = SheetCanvasView(
            sheet: sheet, width: Self.canvasWidth, imageCache: imageCache
        )
        assertCanvas(view)
    }

    /// グリッド 4 列・正方形比率
    func testGrid_4columns_square() {
        var layout = baseLayout()
        layout.columns = 4
        layout.cellAspect = .square
        layout.showFilename = false
        let sheet = Sheet(photos: makePhotos(8, aspectRatio: 1.0), layout: layout)
        let view = SheetCanvasView(
            sheet: sheet, width: Self.canvasWidth, imageCache: imageCache
        )
        assertCanvas(view)
    }

    // MARK: - フィルムストリップ

    /// フィルムストリップ 35mm（横コマ・3:2）
    func testFilmStrip_35mm() {
        var layout = baseLayout()
        layout.style = .filmStrip
        layout.filmFormat = .fullFrame
        layout.columns = 6
        layout.background = .black
        let sheet = Sheet(photos: makePhotos(12, aspectRatio: 1.5), layout: layout)
        let view = SheetCanvasView(
            sheet: sheet, width: Self.canvasWidth, imageCache: imageCache
        )
        assertCanvas(view)
    }

    /// フィルムストリップ ハーフフレーム（縦コマ・3:4）
    func testFilmStrip_halfFrame() {
        var layout = baseLayout()
        layout.style = .filmStrip
        layout.filmFormat = .halfFrame
        layout.columns = 6
        layout.background = .black
        let sheet = Sheet(photos: makePhotos(12, aspectRatio: 0.75), layout: layout)
        let view = SheetCanvasView(
            sheet: sheet, width: Self.canvasWidth, imageCache: imageCache
        )
        assertCanvas(view)
    }

    // MARK: - ヘッダー付き

    /// グリッドにタイトル・キャプションのヘッダーを追加
    func testGrid_withHeader() {
        var layout = baseLayout()
        layout.columns = 6
        var sheet = Sheet(photos: makePhotos(12), layout: layout)
        sheet.title = "ROLL 01"
        sheet.caption = "2025-06-28"
        let view = SheetCanvasView(
            sheet: sheet, width: Self.canvasWidth, imageCache: imageCache
        )
        assertCanvas(view)
    }

    // MARK: - 用紙固定

    /// 用紙固定（8×10）で内容が相似形に収まるか
    func testGrid_fixedPaper_8x10() {
        var layout = baseLayout()
        layout.columns = 6
        layout.paperFormat = .print8x10
        let sheet = Sheet(photos: makePhotos(12), layout: layout)
        let view = SheetCanvasView(
            sheet: sheet, width: Self.canvasWidth, imageCache: imageCache
        )
        assertCanvas(view)
    }
}
