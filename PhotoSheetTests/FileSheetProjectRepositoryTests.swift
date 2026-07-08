import XCTest
#if canImport(PhotoSheetCore)
@testable import PhotoSheetCore
#else
@testable import PhotoSheet
#endif

final class FileSheetProjectRepositoryTests: XCTestCase {
    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        super.tearDown()
    }

    private func makeProject() -> SheetProject {
        var sheet = Sheet(
            photos: [
                SheetPhoto(fileName: "01.jpg", imageData: Data([0x01, 0x02, 0x03]), aspectRatio: 1.5),
                SheetPhoto(fileName: "02.jpg", imageData: Data([0x04, 0x05]), aspectRatio: 0.75)
            ],
            layout: .default
        )
        sheet.title = "OKINAWA"
        sheet.caption = "2026.07.08"
        sheet.layout.style = .filmStrip
        sheet.layout.filmFormat = .halfFrame
        sheet.layout.background = .custom(RGBAColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1))
        return SheetProject(id: UUID(), createdAt: Date(), updatedAt: Date(), sheet: sheet)
    }

    func testSaveLoadRoundTrip() async throws {
        let repository = FileSheetProjectRepository(root: tempRoot)
        let project = makeProject()

        try await repository.save(project, thumbnailPNG: Data([0x99]))
        let loaded = try await repository.load(id: project.id)

        XCTAssertEqual(loaded.id, project.id)
        XCTAssertEqual(loaded.sheet.title, "OKINAWA")
        XCTAssertEqual(loaded.sheet.caption, "2026.07.08")
        XCTAssertEqual(loaded.sheet.layout, project.sheet.layout)
        XCTAssertEqual(loaded.sheet.photos.count, 2)
        XCTAssertEqual(loaded.sheet.photos[0].imageData, Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(loaded.sheet.photos[1].aspectRatio, 0.75, accuracy: 0.001)
    }

    func testListSummariesIncludesThumbnail() async throws {
        let repository = FileSheetProjectRepository(root: tempRoot)
        try await repository.save(makeProject(), thumbnailPNG: Data([0x99]))

        let summaries = try await repository.listSummaries()

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].title, "OKINAWA")
        XCTAssertEqual(summaries[0].photoCount, 2)
        XCTAssertNotNil(summaries[0].thumbnailURL)
    }

    func testSaveRemovesDeletedPhotoFiles() async throws {
        let repository = FileSheetProjectRepository(root: tempRoot)
        var project = makeProject()
        try await repository.save(project, thumbnailPNG: nil)

        // 1 枚削除して保存し直す
        project.sheet.photos.removeLast()
        try await repository.save(project, thumbnailPNG: nil)

        let loaded = try await repository.load(id: project.id)
        XCTAssertEqual(loaded.sheet.photos.count, 1)
    }

    func testDeleteRemovesProject() async throws {
        let repository = FileSheetProjectRepository(root: tempRoot)
        let project = makeProject()
        try await repository.save(project, thumbnailPNG: nil)

        try await repository.delete(id: project.id)

        let summaries = try await repository.listSummaries()
        XCTAssertTrue(summaries.isEmpty)
    }
}
