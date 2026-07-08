import XCTest
@testable import PhotoSheet

final class LayoutConfigTests: XCTestCase {
    func testDefaultColumnsForSmallCounts() {
        XCTAssertEqual(LayoutConfig.defaultColumns(forPhotoCount: 1), 2)
        XCTAssertEqual(LayoutConfig.defaultColumns(forPhotoCount: 4), 2)
        XCTAssertEqual(LayoutConfig.defaultColumns(forPhotoCount: 5), 3)
        XCTAssertEqual(LayoutConfig.defaultColumns(forPhotoCount: 9), 3)
    }

    func testDefaultColumnsForLargeCounts() {
        XCTAssertEqual(LayoutConfig.defaultColumns(forPhotoCount: 10), 4)
        XCTAssertEqual(LayoutConfig.defaultColumns(forPhotoCount: 16), 4)
        XCTAssertEqual(LayoutConfig.defaultColumns(forPhotoCount: 17), 6)
        XCTAssertEqual(LayoutConfig.defaultColumns(forPhotoCount: 36), 6)
        XCTAssertEqual(LayoutConfig.defaultColumns(forPhotoCount: 100), 6)
    }
}
