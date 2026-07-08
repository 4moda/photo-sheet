import XCTest
@testable import PhotoSheet

@MainActor
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

    func testRenderReturnsRendererOutput() throws {
        let useCase = ExportSheetUseCase(renderer: MockRenderer(), saver: MockSaver())

        let data = try useCase.render(sheet: makeSheet())

        XCTAssertEqual(data, Data([0x89, 0x50]))
    }
}
