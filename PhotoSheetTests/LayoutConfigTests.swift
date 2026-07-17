import XCTest
#if canImport(PhotoSheetCore)
@testable import PhotoSheetCore
#else
@testable import PhotoSheet
#endif

final class LayoutConfigTests: XCTestCase {
    func testDefaultUsesPrint8x10PaperFormat() {
        XCTAssertEqual(LayoutConfig.default.paperFormat, .print8x10)
    }

    func testRecommendedBackgroundByStyle() {
        XCTAssertEqual(SheetBackground.recommended(for: .grid), .white)
        XCTAssertEqual(SheetBackground.recommended(for: .filmStrip), .black)
        XCTAssertEqual(SheetBackground.recommended(for: .negativeSleeve), .paperGray)
    }

    func testDefaultDecorationsAreOff() {
        XCTAssertFalse(LayoutConfig.default.showDateStamp)
        XCTAssertFalse(LayoutConfig.default.filmEdgeShowsFrameNumbers)
        XCTAssertFalse(LayoutConfig.filmEdgeTextPresets.isEmpty)
    }

    func testDefaultAdjustmentsAreNeutral() {
        XCTAssertEqual(LayoutConfig.default.adjustments, .neutral)
        XCTAssertTrue(SheetAdjustments.neutral.isNeutral)
        var adjusted = SheetAdjustments.neutral
        adjusted.monochrome = true
        XCTAssertFalse(adjusted.isNeutral)
    }

    func testCodableRoundTripKeepsAdjustments() throws {
        var config = LayoutConfig.default
        config.adjustments = SheetAdjustments(
            monochrome: true, contrast: 0.5, grain: 0.3, fade: 0.2, temperature: -0.4, vignette: 0.6
        )
        config.filmFormat = .square66
        config.style = .negativeSleeve
        config.showDateStamp = true
        config.filmEdgeShowsFrameNumbers = true
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LayoutConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    /// adjustments キーを持たない旧 manifest の layout が読めること（後方互換）
    func testDecodingLegacyConfigWithoutAdjustmentsFallsBackToNeutral() throws {
        let legacyJSON = """
        {
            "columns": 4,
            "cellAspect": "square",
            "spacingRatio": 0.02,
            "marginRatio": 0.04,
            "background": {"white": {}},
            "showFilename": true,
            "style": "grid",
            "paperFormat": "a4",
            "filmFormat": "halfFrame",
            "filmEdgeText": "TEST 400"
        }
        """
        let decoded = try JSONDecoder().decode(LayoutConfig.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decoded.columns, 4)
        XCTAssertEqual(decoded.cellAspect, .square)
        XCTAssertEqual(decoded.paperFormat, .a4)
        XCTAssertEqual(decoded.filmEdgeText, "TEST 400")
        XCTAssertEqual(decoded.adjustments, .neutral)
        XCTAssertFalse(decoded.showDateStamp)
        XCTAssertFalse(decoded.filmEdgeShowsFrameNumbers)
    }
}
