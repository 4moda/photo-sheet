import XCTest
#if canImport(PhotoSheetCore)
@testable import PhotoSheetCore
#else
@testable import PhotoSheet
#endif

final class SheetLayoutMathTests: XCTestCase {
    private func makePhotos(_ count: Int, aspect: Double = 1.5) -> [SheetPhoto] {
        (1...count).map { index in
            SheetPhoto(fileName: "\(index)", imageData: Data([0x01]), aspectRatio: aspect)
        }
    }

    private func makeSheet(_ count: Int, configure: (inout Sheet) -> Void = { _ in }) -> Sheet {
        var sheet = Sheet(photos: count > 0 ? makePhotos(count) : [], layout: .default)
        configure(&sheet)
        return sheet
    }

    func testRowRanges() {
        XCTAssertEqual(SheetLayoutMath.rowRanges(photoCount: 0, columns: 4).count, 0)
        XCTAssertEqual(SheetLayoutMath.rowRanges(photoCount: 8, columns: 4).count, 2)
        XCTAssertEqual(SheetLayoutMath.rowRanges(photoCount: 9, columns: 4).count, 3)
        XCTAssertEqual(SheetLayoutMath.rowRanges(photoCount: 9, columns: 4).last, 8..<9)
    }

    func testPaperFormatRatios() {
        XCTAssertNil(PaperFormat.flexible.aspectRatio)
        XCTAssertEqual(PaperFormat.print8x10.aspectRatio ?? 0, 0.8, accuracy: 0.001)
        XCTAssertEqual(PaperFormat.story9x16.aspectRatio ?? 0, 0.5625, accuracy: 0.001)
    }

    func testGridNaturalHeightMatchesManualCalculation() {
        // 幅 1000, デフォルト設定（margin 5%, spacing 1.2%, 4列, 3:2）で 8 枚 = 2 行
        var sheet = makeSheet(8)
        sheet.layout.columns = 4
        let width = 1000.0

        let margin = 50.0
        let spacing = 12.0
        let cellWidth = (900.0 - spacing * 3) / 4
        let rowHeight = cellWidth / 1.5
        let expected = margin * 2 + rowHeight * 2 + spacing

        XCTAssertEqual(
            SheetLayoutMath.naturalHeight(sheet: sheet, width: width),
            expected,
            accuracy: 0.01
        )
    }

    func testHeaderAddsHeight() {
        let plain = makeSheet(4)
        let titled = makeSheet(4) { $0.title = "TITLE" }
        let width = 1000.0

        let plainHeight = SheetLayoutMath.naturalHeight(sheet: plain, width: width)
        let titledHeight = SheetLayoutMath.naturalHeight(sheet: titled, width: width)

        // ヘッダーゾーン + ヘッダー下の間隔ぶんだけ高くなる
        let expectedDelta = width * SheetLayoutMath.headerZoneRatio + width * plain.layout.spacingRatio
        XCTAssertEqual(titledHeight - plainHeight, expectedDelta, accuracy: 0.01)
    }

    func testFilmStripNaturalHeightUsesStripStructure() {
        var sheet = makeSheet(12)
        sheet.layout.style = .filmStrip
        sheet.layout.columns = 6
        let width = 1000.0

        let frameWidth = SheetLayoutMath.filmFrameWidth(sheet.layout, width: width)
        let stripHeight = SheetLayoutMath.filmStripHeight(frameWidth: frameWidth, format: .fullFrame)
        let spacing = SheetLayoutMath.spacing(sheet.layout, width: width)
        let margin = SheetLayoutMath.margin(sheet.layout, width: width)
        let expected = margin * 2 + stripHeight * 2 + spacing

        XCTAssertEqual(
            SheetLayoutMath.naturalHeight(sheet: sheet, width: width),
            expected,
            accuracy: 0.01
        )
    }

    func testFilmStripHeightComposition() {
        let frameWidth = 150.0
        // 35mm フルフレーム（3:2 横）
        let fullFrame = frameWidth * (0.10 * 2 + 0.08 * 2) + frameWidth / 1.5
        XCTAssertEqual(
            SheetLayoutMath.filmStripHeight(frameWidth: frameWidth, format: .fullFrame),
            fullFrame,
            accuracy: 0.001
        )
        // ハーフフレーム（3:4 縦）はコマが縦長になるぶんストリップが高い
        let halfFrame = frameWidth * (0.10 * 2 + 0.08 * 2) + frameWidth / 0.75
        XCTAssertEqual(
            SheetLayoutMath.filmStripHeight(frameWidth: frameWidth, format: .halfFrame),
            halfFrame,
            accuracy: 0.001
        )
    }

    func testFilmStripHeightFor120HasNoSprocketBands() {
        let frameWidth = 150.0
        // 120（6×6）はパーフォレーションがないためスプロケット帯 2 本ぶん低い
        let square = frameWidth * (0.10 * 2) + frameWidth / 1.0
        XCTAssertEqual(
            SheetLayoutMath.filmStripHeight(frameWidth: frameWidth, format: .square66),
            square,
            accuracy: 0.001
        )
        let wide = frameWidth * (0.10 * 2) + frameWidth / 1.25
        XCTAssertEqual(
            SheetLayoutMath.filmStripHeight(frameWidth: frameWidth, format: .wide67),
            wide,
            accuracy: 0.001
        )
    }

    func testSleeveStripHeightWrapsFilmStripInPocket() {
        let frameWidth = 150.0
        // 中身は実物どおりフィルムストリップ（エッジ帯・スプロケット込み）+ 上下のポケット余白
        let expected = frameWidth * (0.06 * 2)
            + SheetLayoutMath.filmStripHeight(frameWidth: frameWidth, format: .fullFrame)
        XCTAssertEqual(
            SheetLayoutMath.sleeveStripHeight(frameWidth: frameWidth, format: .fullFrame),
            expected,
            accuracy: 0.001
        )
    }

    func testNegativeSleeveNaturalHeightUsesSleeveStrips() {
        var sheet = makeSheet(12)
        sheet.layout.style = .negativeSleeve
        sheet.layout.columns = 6
        let width = 1000.0

        let frameWidth = SheetLayoutMath.sleeveFrameWidth(sheet.layout, width: width)
        let stripHeight = SheetLayoutMath.sleeveStripHeight(frameWidth: frameWidth, format: .fullFrame)
        let spacing = SheetLayoutMath.spacing(sheet.layout, width: width)
        let margin = SheetLayoutMath.margin(sheet.layout, width: width)
        let expected = margin * 2 + stripHeight * 2 + spacing

        XCTAssertEqual(
            SheetLayoutMath.naturalHeight(sheet: sheet, width: width),
            expected,
            accuracy: 0.01
        )
    }

    func testFilmFrameWidthAccountsForLeaderAndSeparators() {
        let layout = LayoutConfig.default
        let width = 1000.0
        let content = SheetLayoutMath.contentWidth(layout, width: width)
        let separator = SheetLayoutMath.filmSeparator(layout, width: width)
        let leader = SheetLayoutMath.filmLeader(layout, width: width)
        let frameWidth = SheetLayoutMath.filmFrameWidth(layout, width: width)
        // 恒等式: leader×2 + コマ×n + 間隔×(n-1) = コンテンツ幅
        let total = leader * 2 + frameWidth * Double(layout.columns)
            + separator * Double(layout.columns - 1)
        XCTAssertEqual(total, content, accuracy: 0.001)
    }

    func testSleeveFrameWidthIsNarrowerByPunchMargin() {
        let layout = LayoutConfig.default
        let width = 1000.0
        // バインダー穴の余白ぶん、スリーブのコマはフィルムより狭い
        XCTAssertLessThan(
            SheetLayoutMath.sleeveFrameWidth(layout, width: width),
            SheetLayoutMath.filmFrameWidth(layout, width: width)
        )
        let stripWidth = SheetLayoutMath.sleeveContentWidth(layout, width: width)
        let punch = SheetLayoutMath.sleevePunchMargin(layout, width: width)
        XCTAssertEqual(
            stripWidth + punch,
            SheetLayoutMath.contentWidth(layout, width: width),
            accuracy: 0.001
        )
    }

    func testStripLayOffsetsAreDeterministicAndBounded() {
        for row in 0..<24 {
            XCTAssertEqual(
                SheetLayoutMath.stripLayOffsetRatio(row: row),
                SheetLayoutMath.stripLayOffsetRatio(row: row)
            )
            XCTAssertLessThanOrEqual(
                abs(SheetLayoutMath.stripLayOffsetRatio(row: row)),
                SheetLayoutMath.stripLayMaxOffsetRatio
            )
            XCTAssertLessThanOrEqual(
                abs(SheetLayoutMath.stripLayRotationDegrees(row: row)),
                SheetLayoutMath.stripLayMaxRotationDegrees
            )
        }
        // 全行が同じ値なら「手貼り感」にならない
        let offsets = Set((0..<24).map { SheetLayoutMath.stripLayOffsetRatio(row: $0) })
        XCTAssertGreaterThan(offsets.count, 1)
    }

    func testFilmFormatAspects() {
        XCTAssertEqual(FilmFormat.fullFrame.frameAspect, 1.5, accuracy: 0.001)
        XCTAssertEqual(FilmFormat.halfFrame.frameAspect, 0.75, accuracy: 0.001)
        XCTAssertEqual(FilmFormat.square66.frameAspect, 1.0, accuracy: 0.001)
        XCTAssertEqual(FilmFormat.wide67.frameAspect, 1.25, accuracy: 0.001)
    }

    func testFilmFormatSprocketHoles() {
        XCTAssertTrue(FilmFormat.fullFrame.hasSprocketHoles)
        XCTAssertTrue(FilmFormat.halfFrame.hasSprocketHoles)
        XCTAssertFalse(FilmFormat.square66.hasSprocketHoles)
        XCTAssertFalse(FilmFormat.wide67.hasSprocketHoles)
    }

    func testFilmNeedsRotationWhenOrientationsMismatch() {
        // 35mm 横コマ × 縦写真 → 回転
        XCTAssertTrue(SheetLayoutMath.filmNeedsRotation(photoAspect: 0.75, frameAspect: 1.5))
        // 35mm 横コマ × 横写真 → そのまま
        XCTAssertFalse(SheetLayoutMath.filmNeedsRotation(photoAspect: 1.5, frameAspect: 1.5))
        // ハーフ縦コマ × 横写真 → 回転
        XCTAssertTrue(SheetLayoutMath.filmNeedsRotation(photoAspect: 1.5, frameAspect: 0.75))
        // ハーフ縦コマ × 縦写真 → そのまま
        XCTAssertFalse(SheetLayoutMath.filmNeedsRotation(photoAspect: 0.75, frameAspect: 0.75))
        // 正方形コマ（6×6）には向きがないため、どの写真でも回転しない
        XCTAssertFalse(SheetLayoutMath.filmNeedsRotation(photoAspect: 0.75, frameAspect: 1.0))
        XCTAssertFalse(SheetLayoutMath.filmNeedsRotation(photoAspect: 1.5, frameAspect: 1.0))
    }

    func testGridOriginalAspectUsesTallestPhotoInRow() {
        var sheet = Sheet(
            photos: [
                SheetPhoto(fileName: "wide", imageData: Data([0x01]), aspectRatio: 2.0),
                SheetPhoto(fileName: "tall", imageData: Data([0x01]), aspectRatio: 0.5)
            ],
            layout: .default
        )
        sheet.layout.columns = 2
        sheet.layout.cellAspect = .original
        let width = 1000.0

        let cellWidth = SheetLayoutMath.gridCellWidth(sheet.layout, width: width)
        let rowHeight = SheetLayoutMath.gridRowHeight(sheet.photos, layout: sheet.layout, cellWidth: cellWidth)

        // 縦長写真（aspect 0.5 → 高さ = 幅 * 2）が行の高さを決める
        XCTAssertEqual(rowHeight, cellWidth * 2, accuracy: 0.01)
    }
}
