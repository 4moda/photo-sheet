import XCTest
import Foundation
#if canImport(PhotoSheetCore)
@testable import PhotoSheetCore
#else
@testable import PhotoSheet
#endif

/// ExportSheetVideoUseCase をモックで検証する
final class ExportSheetVideoUseCaseTests: XCTestCase {

    // MARK: - モック実装

    /// 指定したデータの「MP4 もどき」を outputURL に書き込む
    private final class MockVideoRenderer: SheetVideoRenderer {
        let fileContent: Data
        private(set) var renderCallCount = 0

        init(fileContent: Data = Data("fake-mp4".utf8)) {
            self.fileContent = fileContent
        }

        @MainActor
        func renderVideo(
            sheet: Sheet,
            config: VideoExportConfig,
            outputURL: URL,
            onProgress: @Sendable (Double) async -> Void
        ) async throws {
            renderCallCount += 1
            await onProgress(0.5)
            try fileContent.write(to: outputURL)
            await onProgress(1.0)
        }
    }

    /// 保存先 URL を記録するサバー
    private final class MockVideoSaver: VideoLibrarySaver {
        private(set) var savedURLs: [URL] = []

        func saveVideo(at url: URL) async throws {
            savedURLs.append(url)
        }
    }

    /// 常にエラーを返すレンダラー
    private final class FailingRenderer: SheetVideoRenderer {
        @MainActor
        func renderVideo(
            sheet: Sheet,
            config: VideoExportConfig,
            outputURL: URL,
            onProgress: @Sendable (Double) async -> Void
        ) async throws {
            throw VideoExportError.renderingFailed
        }
    }

    /// 並行安全な進捗コレクター
    private final class ProgressCollector: @unchecked Sendable {
        var values: [Double] = []
        func record(_ v: Double) { values.append(v) }
    }

    // MARK: - ヘルパー

    private func makeSheet() -> Sheet {
        let photo = SheetPhoto(fileName: "test", imageData: Data([0x01]), aspectRatio: 1.5)
        return Sheet(photos: [photo], layout: .default)
    }

    // MARK: - render のテスト

    func testRenderCallsRendererAndReturnsMP4URL() async throws {
        let renderer = MockVideoRenderer()
        let useCase = ExportSheetVideoUseCase(renderer: renderer, saver: MockVideoSaver())

        let url = try await useCase.render(sheet: makeSheet(), config: .default)

        XCTAssertEqual(renderer.renderCallCount, 1)
        XCTAssertEqual(url.pathExtension, "mp4")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }

    func testRenderPropagatesProgress() async throws {
        let renderer = MockVideoRenderer()
        let useCase = ExportSheetVideoUseCase(renderer: renderer, saver: MockVideoSaver())
        let collector = ProgressCollector()

        let url = try await useCase.render(
            sheet: makeSheet(),
            config: .default,
            onProgress: { [collector] p in collector.record(p) }
        )
        try? FileManager.default.removeItem(at: url)

        XCTAssertFalse(collector.values.isEmpty, "進捗コールバックが呼ばれるべき")
        XCTAssertEqual(collector.values.last ?? -1, 1.0, accuracy: 0.001)
    }

    func testRenderThrowsOnRendererFailure() async throws {
        let useCase = ExportSheetVideoUseCase(renderer: FailingRenderer(), saver: MockVideoSaver())

        do {
            _ = try await useCase.render(sheet: makeSheet(), config: .default)
            XCTFail("例外が投げられるべき")
        } catch VideoExportError.renderingFailed {
            // expected
        }
    }

    // MARK: - saveToLibrary のテスト

    func testSaveToLibraryCallsRendererAndSaver() async throws {
        let renderer = MockVideoRenderer()
        let saver = MockVideoSaver()
        let useCase = ExportSheetVideoUseCase(renderer: renderer, saver: saver)

        try await useCase.saveToLibrary(sheet: makeSheet(), config: .default)

        XCTAssertEqual(renderer.renderCallCount, 1)
        XCTAssertEqual(saver.savedURLs.count, 1)
    }

    func testSaveToLibraryDeletesTempFileAfterSave() async throws {
        let renderer = MockVideoRenderer()
        let saver = MockVideoSaver()
        let useCase = ExportSheetVideoUseCase(renderer: renderer, saver: saver)

        try await useCase.saveToLibrary(sheet: makeSheet(), config: .default)

        if let savedURL = saver.savedURLs.first {
            XCTAssertFalse(FileManager.default.fileExists(atPath: savedURL.path),
                           "保存後にテンポラリファイルが削除されているべき")
        }
    }

    func testSaveToLibraryThrowsOnRendererFailure() async throws {
        let useCase = ExportSheetVideoUseCase(renderer: FailingRenderer(), saver: MockVideoSaver())

        do {
            try await useCase.saveToLibrary(sheet: makeSheet(), config: .default)
            XCTFail("例外が投げられるべき")
        } catch VideoExportError.renderingFailed {
            // expected
        }
    }

    func testSaveToLibraryPropagatesProgress() async throws {
        let renderer = MockVideoRenderer()
        let useCase = ExportSheetVideoUseCase(renderer: renderer, saver: MockVideoSaver())
        let collector = ProgressCollector()

        try await useCase.saveToLibrary(
            sheet: makeSheet(),
            config: .default,
            onProgress: { [collector] p in collector.record(p) }
        )

        XCTAssertFalse(collector.values.isEmpty)
        XCTAssertEqual(collector.values.last ?? -1, 1.0, accuracy: 0.001)
    }
}
