import XCTest
#if canImport(PhotoSheetCore)
@testable import PhotoSheetCore
#else
@testable import PhotoSheet
#endif

/// VideoExportGeometry のジオメトリ計算をテストする
final class VideoExportGeometryTests: XCTestCase {

    // MARK: - computeStrips

    func testComputeStripsEmptyPhotos() async throws {
        let sheet = Sheet(photos: [], layout: .default)
        let strips = VideoExportGeometry.computeStrips(
            sheet: sheet, canvasWidth: 1080, config: .default
        )
        XCTAssertTrue(strips.isEmpty)
    }

    func testComputeStrips6PhotosVisibleRows3() async throws {
        // 6枚 / 6列 = 1行 → visibleRows=3 でストリップは 1
        let photos = (0..<6).map { i in
            SheetPhoto(fileName: "img\(i)", imageData: Data([0x01]), aspectRatio: 1.5)
        }
        let sheet = Sheet(photos: photos, layout: .default)
        let config = VideoExportConfig(visibleRows: 3, speed: .medium, showOverview: true)
        let strips = VideoExportGeometry.computeStrips(
            sheet: sheet, canvasWidth: 1080, config: config
        )
        XCTAssertEqual(strips.count, 1)
        // yStart > 0（margin 分だけ下がる）
        XCTAssertGreaterThan(strips[0].yStart, 0)
        // canvasHeight > 0
        XCTAssertGreaterThan(strips[0].canvasHeight, 0)
    }

    func testComputeStrips36Photos6Columns3VisibleRows() async throws {
        // 36枚 / 6列 = 6行 → visibleRows=3 でストリップは 2
        let photos = (0..<36).map { i in
            SheetPhoto(fileName: "img\(i)", imageData: Data([0x01]), aspectRatio: 1.5)
        }
        var layout = LayoutConfig.default
        layout.columns = 6
        let sheet = Sheet(photos: photos, layout: layout)
        let config = VideoExportConfig(visibleRows: 3, speed: .medium, showOverview: true)
        let strips = VideoExportGeometry.computeStrips(
            sheet: sheet, canvasWidth: 1080, config: config
        )
        XCTAssertEqual(strips.count, 2)
        // ストリップ 0 の yEnd <= ストリップ 1 の yStart（行間隔を考慮すると ≤ でよい）
        XCTAssertLessThanOrEqual(strips[0].yEnd, strips[1].yStart)
    }

    func testComputeStripsVisibleRows1() async throws {
        // 6行 / visibleRows=1 → ストリップは 6
        let photos = (0..<36).map { i in
            SheetPhoto(fileName: "img\(i)", imageData: Data([0x01]), aspectRatio: 1.5)
        }
        var layout = LayoutConfig.default
        layout.columns = 6
        let sheet = Sheet(photos: photos, layout: layout)
        let config = VideoExportConfig(visibleRows: 1, speed: .medium, showOverview: false)
        let strips = VideoExportGeometry.computeStrips(
            sheet: sheet, canvasWidth: 1080, config: config
        )
        XCTAssertEqual(strips.count, 6)
    }

    // MARK: - buildFrameSpecs

    private func makeSpecs(
        photos: [SheetPhoto] = [],
        config: VideoExportConfig = .default,
        outputSize: CGSize = CGSize(width: 1080, height: 1920),
        fps: Double = 30
    ) -> [VideoExportGeometry.FrameSpec] {
        var layout = LayoutConfig.default
        layout.columns = 6
        let sheet = photos.isEmpty
            ? Sheet(photos: (0..<6).map { SheetPhoto(fileName: "p\($0)", imageData: Data(), aspectRatio: 1.5) }, layout: layout)
            : Sheet(photos: photos, layout: layout)
        let canvasWidth: CGFloat = 1080
        let canvasHeight: CGFloat = 2000
        let strips = VideoExportGeometry.computeStrips(sheet: sheet, canvasWidth: canvasWidth, config: config)
        return VideoExportGeometry.buildFrameSpecs(
            config: config,
            strips: strips,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            outputSize: outputSize,
            fps: fps
        )
    }

    func testFrameSpecsNotEmptyWithPhotos() async throws {
        let specs = makeSpecs()
        XCTAssertFalse(specs.isEmpty)
    }

    func testFrameSpecsShowOverviewAddsOverviewFrames() async throws {
        let withOverview = makeSpecs(config: VideoExportConfig(visibleRows: 3, speed: .fast, showOverview: true))
        let withoutOverview = makeSpecs(config: VideoExportConfig(visibleRows: 3, speed: .fast, showOverview: false))
        XCTAssertGreaterThan(withOverview.count, withoutOverview.count)
        // 概要あり → 先頭フレームが overview コンテンツ
        if case .overview = withOverview.first?.content {} else {
            XCTFail("先頭フレームが overview でない")
        }
    }

    func testFrameSpecsFirstStripPhaseIsStrip() async throws {
        let specs = makeSpecs(config: VideoExportConfig(visibleRows: 3, speed: .fast, showOverview: false))
        // showOverview=false のとき先頭フレームはストリップ
        if case .strip = specs.first?.content {} else {
            XCTFail("先頭フレームが strip でない")
        }
    }

    func testFrameSpecsAlphaRange() async throws {
        let specs = makeSpecs()
        for spec in specs {
            XCTAssertGreaterThanOrEqual(spec.alpha, 0.0)
            XCTAssertLessThanOrEqual(spec.alpha, 1.0)
        }
    }

    func testFrameSpecsFasterSpeedFewerFrames() async throws {
        let slow = makeSpecs(config: VideoExportConfig(visibleRows: 3, speed: .slow, showOverview: false))
        let fast = makeSpecs(config: VideoExportConfig(visibleRows: 3, speed: .fast, showOverview: false))
        XCTAssertGreaterThan(slow.count, fast.count, "遅い速度ほどフレーム数が多い")
    }

    // MARK: - easeInOut

    func testEaseInOutBoundaries() async throws {
        XCTAssertEqual(VideoExportGeometry.easeInOut(0.0), 0.0, accuracy: 1e-9)
        XCTAssertEqual(VideoExportGeometry.easeInOut(1.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(VideoExportGeometry.easeInOut(0.5), 0.5, accuracy: 1e-9)
    }

    func testEaseInOutMonotonicallyIncreasing() async throws {
        var prev = 0.0
        for i in 1...10 {
            let next = VideoExportGeometry.easeInOut(Double(i) / 10.0)
            XCTAssertGreaterThan(next, prev)
            prev = next
        }
    }
}
