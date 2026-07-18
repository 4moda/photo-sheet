import XCTest
#if canImport(PhotoSheetCore)
@testable import PhotoSheetCore
#else
@testable import PhotoSheet
#endif

// クラス全体を @MainActor にすると Linux の XCTest が同期テストを呼べないため、
// MainActor が必要な呼び出しはテスト内で await する。
final class ExportSheetUseCaseTests: XCTestCase {
    private struct MockRenderer: SheetRenderer {
        @MainActor
        func renderPNG(sheet: Sheet, targetPixelWidth: Double) throws -> Data {
            Data([0x89, 0x50])
        }
    }

    private final class MockSaver: PhotoLibrarySaver {
        private(set) var savedData: Data?

        func save(pngData: Data) async throws {
            savedData = pngData
        }
    }

    private func makeSheet() -> Sheet {
        let photo = SheetPhoto(fileName: "01", imageData: Data([0x01]), aspectRatio: 1.5)
        return Sheet(photos: [photo], layout: .default)
    }

    func testSaveToLibraryRendersAndSaves() async throws {
        let saver = MockSaver()
        let useCase = ExportSheetUseCase(renderer: MockRenderer(), saver: saver)

        try await useCase.saveToLibrary(sheet: makeSheet())

        XCTAssertEqual(saver.savedData, Data([0x89, 0x50]))
    }

    func testRenderReturnsRendererOutput() async throws {
        let useCase = ExportSheetUseCase(renderer: MockRenderer(), saver: MockSaver())

        let data = try await useCase.render(sheet: makeSheet())

        XCTAssertEqual(data, Data([0x89, 0x50]))
    }

    func testDefaultPixelWidthFavorsSNSAndPrint() {
        // SNS 想定: Instagram 表示解像度 1080 の 2 倍
        XCTAssertEqual(ExportSheetUseCase.defaultPixelWidth(for: .flexible), 2160)
        XCTAssertEqual(ExportSheetUseCase.defaultPixelWidth(for: .story9x16), 2160)
        // 印刷系用紙: 8×10 で 300dpi 相当
        XCTAssertEqual(ExportSheetUseCase.defaultPixelWidth(for: .print8x10), 2400)
        XCTAssertEqual(ExportSheetUseCase.defaultPixelWidth(for: .print4x6), 2400)
        XCTAssertEqual(ExportSheetUseCase.defaultPixelWidth(for: .a4), 2400)
    }

    func testPrintPixelWidthAt300DPI() throws {
        let width = try XCTUnwrap(ExportSheetUseCase.printPixelWidth(for: .print8x10, dpi: 300))
        XCTAssertEqual(width, 2400)
        // 高さは PaperFormat.aspectRatio（幅 / 高さ）から導出できる
        let aspectRatio = try XCTUnwrap(PaperFormat.print8x10.aspectRatio)
        XCTAssertEqual(width / aspectRatio, 3000)
    }

    func testPrintPixelWidthAt600DPI() throws {
        let width = try XCTUnwrap(ExportSheetUseCase.printPixelWidth(for: .print8x10, dpi: 600))
        XCTAssertEqual(width, 4800)
        let aspectRatio = try XCTUnwrap(PaperFormat.print8x10.aspectRatio)
        XCTAssertEqual(width / aspectRatio, 6000)
    }

    func testPrintPixelWidthIsNilForNonPrintFormats() {
        XCTAssertNil(ExportSheetUseCase.printPixelWidth(for: .flexible, dpi: 300))
        XCTAssertNil(ExportSheetUseCase.printPixelWidth(for: .story9x16, dpi: 300))
    }

    func testPrintPixelWidthClampsToSafeUpperBound() throws {
        // a4 は物理幅が最も広いため、高 DPI で最初に上限へ到達する
        let width = try XCTUnwrap(ExportSheetUseCase.printPixelWidth(for: .a4, dpi: 1200))
        XCTAssertEqual(width, ExportSheetUseCase.maxSafePixelWidth)
    }

    func testTargetPixelWidthMatchesDefaultWhenQualityIsScreen() {
        // 品質を明示的に選ばない場合（既定 = screen）は挙動互換のため defaultPixelWidth と一致する
        for format in PaperFormat.allCases {
            XCTAssertEqual(
                ExportSheetUseCase.targetPixelWidth(for: format, quality: .screen),
                ExportSheetUseCase.defaultPixelWidth(for: format)
            )
        }
    }

    func testTargetPixelWidthUsesPrintQualityForPrintFormats() {
        XCTAssertEqual(
            ExportSheetUseCase.targetPixelWidth(for: .print8x10, quality: .printStandard), 2400
        )
        XCTAssertEqual(
            ExportSheetUseCase.targetPixelWidth(for: .print8x10, quality: .printHigh), 4800
        )
    }

    func testTargetPixelWidthFallsBackToDefaultForNonPrintFormats() {
        // flexible / story9x16 は印刷品質を選んでいても対象外なので画面向け解像度のまま
        XCTAssertEqual(
            ExportSheetUseCase.targetPixelWidth(for: .flexible, quality: .printHigh),
            ExportSheetUseCase.defaultPixelWidth(for: .flexible)
        )
        XCTAssertEqual(
            ExportSheetUseCase.targetPixelWidth(for: .story9x16, quality: .printStandard),
            ExportSheetUseCase.defaultPixelWidth(for: .story9x16)
        )
    }
}
