import XCTest
@testable import PhotoSheet

final class BuildSheetUseCaseTests: XCTestCase {
    private func makePhotos(_ count: Int) -> [SheetPhoto] {
        (1...count).map { index in
            SheetPhoto(fileName: String(format: "%02d", index), imageData: Data([0x01]), aspectRatio: 1.5)
        }
    }

    func testAppliesDefaultColumnsBasedOnCount() {
        let useCase = BuildSheetUseCase()
        XCTAssertEqual(useCase(photos: makePhotos(3)).layout.columns, 2)
        XCTAssertEqual(useCase(photos: makePhotos(12)).layout.columns, 4)
        XCTAssertEqual(useCase(photos: makePhotos(36)).layout.columns, 6)
    }

    func testKeepsOtherLayoutSettings() {
        var layout = LayoutConfig.default
        layout.background = .black
        layout.showFilename = true

        let sheet = BuildSheetUseCase()(photos: makePhotos(12), basedOn: layout)

        XCTAssertEqual(sheet.layout.background, .black)
        XCTAssertTrue(sheet.layout.showFilename)
        XCTAssertEqual(sheet.layout.columns, 4)
    }

    func testPreservesPhotoOrder() {
        let photos = makePhotos(5)
        let sheet = BuildSheetUseCase()(photos: photos)
        XCTAssertEqual(sheet.photos.map(\.fileName), ["01", "02", "03", "04", "05"])
    }
}
