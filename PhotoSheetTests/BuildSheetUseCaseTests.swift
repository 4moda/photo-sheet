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
        var current = Sheet(photos: [], layout: .default)
        current.layout.background = .black
        current.layout.showFilename = true
        current.layout.style = .filmStrip

        let sheet = BuildSheetUseCase()(photos: makePhotos(12), basedOn: current)

        XCTAssertEqual(sheet.layout.background, .black)
        XCTAssertTrue(sheet.layout.showFilename)
        XCTAssertEqual(sheet.layout.style, .filmStrip)
        XCTAssertEqual(sheet.layout.columns, 4)
    }

    func testKeepsTitleAndCaption() {
        var current = Sheet(photos: [], layout: .default)
        current.title = "OKINAWA"
        current.caption = "2026.07.08"

        let sheet = BuildSheetUseCase()(photos: makePhotos(6), basedOn: current)

        XCTAssertEqual(sheet.title, "OKINAWA")
        XCTAssertEqual(sheet.caption, "2026.07.08")
    }

    func testPreservesPhotoOrder() {
        let photos = makePhotos(5)
        let sheet = BuildSheetUseCase()(photos: photos)
        XCTAssertEqual(sheet.photos.map(\.fileName), ["01", "02", "03", "04", "05"])
    }
}
