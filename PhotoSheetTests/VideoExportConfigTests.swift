import XCTest
@testable import PhotoSheetCore

final class VideoExportConfigTests: XCTestCase {

    // MARK: - Speed

    func testSlowSpeedIsSlowerThanMedium() {
        XCTAssertLessThan(
            VideoExportConfig.Speed.slow.canvasPixelsPerSecond,
            VideoExportConfig.Speed.medium.canvasPixelsPerSecond
        )
    }

    func testMediumSpeedIsSlowerThanFast() {
        XCTAssertLessThan(
            VideoExportConfig.Speed.medium.canvasPixelsPerSecond,
            VideoExportConfig.Speed.fast.canvasPixelsPerSecond
        )
    }

    func testAllSpeedsArePositive() {
        for speed in VideoExportConfig.Speed.allCases {
            XCTAssertGreaterThan(speed.canvasPixelsPerSecond, 0, "\(speed) の速度が正でない")
        }
    }

    // MARK: - Default

    func testDefaultConfig() {
        let config = VideoExportConfig.default
        XCTAssertEqual(config.speed, .medium)
        XCTAssertEqual(config.visibleRows, 3)
        XCTAssertTrue(config.showOverview)
    }

    // MARK: - Equatable / Codable

    func testEquatable() {
        let a = VideoExportConfig.default
        var b = VideoExportConfig.default
        XCTAssertEqual(a, b)
        b.speed = .fast
        XCTAssertNotEqual(a, b)
    }

    func testRoundTripCodable() throws {
        var config = VideoExportConfig.default
        config.visibleRows = 5
        config.speed = .slow
        config.showOverview = false

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoExportConfig.self, from: data)
        XCTAssertEqual(config, decoded)
    }
}
