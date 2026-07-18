import XCTest
#if canImport(PhotoSheetCore)
@testable import PhotoSheetCore
#else
@testable import PhotoSheet
#endif

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

    // MARK: - Preset

    func testStoryReelOutputSizeIs9x16() {
        let size = VideoExportConfig.Preset.storyReel.outputSize
        XCTAssertEqual(size.width, 1080)
        XCTAssertEqual(size.height, 1920)
    }

    func testFeedOutputSizeIs4x5() {
        let size = VideoExportConfig.Preset.feed.outputSize
        XCTAssertEqual(size.width, 1080)
        XCTAssertEqual(size.height, 1350)
    }

    func testSquareOutputSizeIs1x1() {
        let size = VideoExportConfig.Preset.square.outputSize
        XCTAssertEqual(size.width, 1080)
        XCTAssertEqual(size.height, 1080)
    }

    func testAllPresetsHaveFixedWidthAndDistinctAspect() {
        let sizes = VideoExportConfig.Preset.allCases.map(\.outputSize)
        for size in sizes {
            XCTAssertEqual(size.width, 1080, "幅は全プリセットで 1080px 固定")
        }
        XCTAssertEqual(Set(sizes.map(\.height)).count, sizes.count, "プリセットごとに高さ（アスペクト比）が異なる")
    }

    func testAllPresetsHaveNonEmptyDurationHint() {
        for preset in VideoExportConfig.Preset.allCases {
            XCTAssertFalse(preset.durationHint.isEmpty, "\(preset) の尺目安が空")
        }
    }

    func testAspectRatioLabelsAreReducedAndUnambiguous() {
        XCTAssertEqual(VideoExportConfig.Preset.storyReel.aspectRatioLabel, "9:16")
        XCTAssertEqual(VideoExportConfig.Preset.feed.aspectRatioLabel, "4:5")
        XCTAssertEqual(VideoExportConfig.Preset.square.aspectRatioLabel, "1:1")

        let labels = VideoExportConfig.Preset.allCases.map(\.aspectRatioLabel)
        XCTAssertEqual(Set(labels).count, labels.count, "アスペクト比ラベルはプリセットごとに一意であるべき")
    }

    // MARK: - Default

    func testDefaultConfig() {
        let config = VideoExportConfig.default
        XCTAssertEqual(config.speed, .medium)
        XCTAssertEqual(config.visibleRows, 3)
        XCTAssertTrue(config.showOverview)
    }

    func testDefaultConfigPresetIsStoryReel() {
        XCTAssertEqual(VideoExportConfig.default.preset, .storyReel)
    }

    func testLegacyInitializerDefaultsToStoryReelPreset() {
        let config = VideoExportConfig(visibleRows: 5, speed: .slow, showOverview: false)
        XCTAssertEqual(config.preset, .storyReel)
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
        config.preset = .feed

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VideoExportConfig.self, from: data)
        XCTAssertEqual(config, decoded)
    }
}
