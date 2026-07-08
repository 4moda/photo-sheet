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
    }
}
