import XCTest
@testable import PhotoSheet

final class SheetTests: XCTestCase {
    private func makeSheet(_ names: [String]) -> Sheet {
        let photos = names.map {
            SheetPhoto(fileName: $0, imageData: Data([0x01]), aspectRatio: 1.5)
        }
        return Sheet(photos: photos, layout: .default)
    }

    private func id(of name: String, in sheet: Sheet) -> UUID {
        sheet.photos.first { $0.fileName == name }!.id
    }

    func testMovePhotoForward() {
        var sheet = makeSheet(["a", "b", "c", "d"])
        sheet.movePhoto(id: id(of: "a", in: sheet), toPositionOf: id(of: "c", in: sheet))
        XCTAssertEqual(sheet.photos.map(\.fileName), ["b", "c", "a", "d"])
    }

    func testMovePhotoBackward() {
        var sheet = makeSheet(["a", "b", "c", "d"])
        sheet.movePhoto(id: id(of: "d", in: sheet), toPositionOf: id(of: "b", in: sheet))
        XCTAssertEqual(sheet.photos.map(\.fileName), ["a", "d", "b", "c"])
    }

    func testMovePhotoToItselfDoesNothing() {
        var sheet = makeSheet(["a", "b", "c"])
        sheet.movePhoto(id: id(of: "b", in: sheet), toPositionOf: id(of: "b", in: sheet))
        XCTAssertEqual(sheet.photos.map(\.fileName), ["a", "b", "c"])
    }

    func testMovePhotoWithUnknownIdDoesNothing() {
        var sheet = makeSheet(["a", "b"])
        sheet.movePhoto(id: UUID(), toPositionOf: id(of: "a", in: sheet))
        XCTAssertEqual(sheet.photos.map(\.fileName), ["a", "b"])
    }
}
