import XCTest
#if canImport(PhotoSheetCore)
@testable import PhotoSheetCore
#else
@testable import PhotoSheet
#endif

final class ImportPhotosUseCaseTests: XCTestCase {
    private struct MockRepository: PhotoSourceRepository {
        var photos: [SheetPhoto] = []

        func loadPhotos(from source: PhotoImportSource) async throws -> [SheetPhoto] {
            photos
        }
    }

    private func photo(_ name: String, capturedAt: Date? = nil) -> SheetPhoto {
        SheetPhoto(fileName: name, imageData: Data([0x01]), aspectRatio: 1.5, captureDate: capturedAt)
    }

    func testPickedSortsByCaptureDate() async throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let repository = MockRepository(photos: [
            photo("b", capturedAt: base.addingTimeInterval(60)),
            photo("a", capturedAt: base)
        ])
        let useCase = ImportPhotosUseCase(repository: repository)

        let result = try await useCase(source: .picked([]))

        XCTAssertEqual(result.map(\.fileName), ["a", "b"])
    }

    func testPhotosWithoutCaptureDateFallBackToFileNameOrder() async throws {
        // フィルムスキャン等（EXIF なし）はファイル名の自然順
        let repository = MockRepository(photos: [photo("10.jpg"), photo("2.jpg"), photo("1.jpg")])
        let useCase = ImportPhotosUseCase(repository: repository)

        let result = try await useCase(source: .picked([]))

        XCTAssertEqual(result.map(\.fileName), ["1.jpg", "2.jpg", "10.jpg"])
    }

    func testFolderSortsByNaturalFileNameOrder() async throws {
        let repository = MockRepository(photos: [photo("10.jpg"), photo("2.jpg"), photo("1.jpg")])
        let useCase = ImportPhotosUseCase(repository: repository)

        let result = try await useCase(source: .folder(URL(fileURLWithPath: "/tmp")))

        XCTAssertEqual(result.map(\.fileName), ["1.jpg", "2.jpg", "10.jpg"])
    }

    func testMixedCaptureDatesPutDatedPhotosFirst() async throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let repository = MockRepository(photos: [
            photo("scan2.jpg"),
            photo("digital.jpg", capturedAt: base),
            photo("scan1.jpg")
        ])
        let useCase = ImportPhotosUseCase(repository: repository)

        let result = try await useCase(source: .picked([]))

        XCTAssertEqual(result.map(\.fileName), ["digital.jpg", "scan1.jpg", "scan2.jpg"])
    }

    func testThrowsWhenNoImagesFound() async {
        let useCase = ImportPhotosUseCase(repository: MockRepository())

        do {
            _ = try await useCase(source: .zip(URL(fileURLWithPath: "/tmp/a.zip")))
            XCTFail("expected PhotoImportError.noImagesFound")
        } catch {
            XCTAssertEqual(error as? PhotoImportError, .noImagesFound)
        }
    }
}
