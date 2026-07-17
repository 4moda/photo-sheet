import XCTest
#if canImport(PhotoSheetCore)
@testable import PhotoSheetCore
#else
@testable import PhotoSheet
#endif

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

    // MARK: - 撮影順の並べ替え

    private func photo(_ name: String, capturedAt: Date? = nil) -> SheetPhoto {
        SheetPhoto(fileName: name, imageData: Data([0x01]), aspectRatio: 1.5, captureDate: capturedAt)
    }

    func testSortPhotosByCaptureDatePutsDatedFirstThenFileName() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        var sheet = Sheet(
            photos: [
                photo("scan10.jpg"),
                photo("late.jpg", capturedAt: base.addingTimeInterval(120)),
                photo("scan2.jpg"),
                photo("early.jpg", capturedAt: base)
            ],
            layout: .default
        )
        sheet.sortPhotosByCaptureDate()
        XCTAssertEqual(
            sheet.photos.map(\.fileName),
            ["early.jpg", "late.jpg", "scan2.jpg", "scan10.jpg"]
        )
    }

    // MARK: - 撮影日キャプション

    func testCaptureDateRangeIsNilWithoutDates() {
        let sheet = makeSheet(["a", "b"])
        XCTAssertNil(sheet.captureDateRange)
    }

    func testCaptureDateRangeSpansMinToMax() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let sheet = Sheet(
            photos: [
                photo("b", capturedAt: base.addingTimeInterval(3600)),
                photo("a", capturedAt: base),
                photo("c")
            ],
            layout: .default
        )
        XCTAssertEqual(sheet.captureDateRange, base...base.addingTimeInterval(3600))
    }

    func testDisplayCaptionUsesManualCaptionWhenAutoDateOff() {
        var sheet = makeSheet(["a"])
        sheet.caption = "ROLL 12"
        XCTAssertEqual(sheet.displayCaption, "ROLL 12")
    }

    func testDisplayCaptionFallsBackToManualCaptionWithoutDates() {
        var sheet = makeSheet(["a"])
        sheet.caption = "ROLL 12"
        sheet.autoDateCaption = true
        XCTAssertEqual(sheet.displayCaption, "ROLL 12")
    }

    func testDisplayCaptionShowsSingleDateForSameDay() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        var sheet = Sheet(photos: [photo("a", capturedAt: date)], layout: .default)
        sheet.autoDateCaption = true
        XCTAssertEqual(sheet.displayCaption, Sheet.captionText(for: date...date))
        XCTAssertFalse(sheet.displayCaption.contains("–"))
    }

    func testDisplayCaptionShowsRangeAcrossDays() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = start.addingTimeInterval(86_400 * 3)
        var sheet = Sheet(
            photos: [photo("a", capturedAt: start), photo("b", capturedAt: end)],
            layout: .default
        )
        sheet.autoDateCaption = true
        XCTAssertEqual(sheet.displayCaption, Sheet.captionText(for: start...end))
        XCTAssertTrue(sheet.displayCaption.contains("–"))
    }
}
