import Foundation
import ZIPFoundation

/// Photos ピッカー / フォルダ / zip の 3 経路をまとめた取り込み実装
struct DefaultPhotoSourceRepository: PhotoSourceRepository {
    func loadPhotos(from source: PhotoImportSource) async throws -> [SheetPhoto] {
        switch source {
        case .picked(let items):
            return loadPicked(items)
        case .folder(let url):
            return try loadFolder(url)
        case .zip(let url):
            return try loadZip(url)
        }
    }

    // MARK: - Picked (Photos)

    private func loadPicked(_ items: [PickedPhotoData]) -> [SheetPhoto] {
        items.enumerated().compactMap { index, item in
            guard let aspect = ImageDataDecoder.aspectRatio(of: item.data) else { return nil }
            // ファイル名がない場合はベタ焼きのコマ番号風に連番を振る
            let name = item.suggestedName ?? String(format: "%02d", index + 1)
            return SheetPhoto(
                fileName: name,
                imageData: item.data,
                aspectRatio: aspect,
                captureDate: ImageDataDecoder.captureDate(of: item.data)
            )
        }
    }

    // MARK: - Folder

    private func loadFolder(_ url: URL) throws -> [SheetPhoto] {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        return try collectImages(in: url, accessError: .folderAccessDenied)
    }

    // MARK: - Zip

    private func loadZip(_ url: URL) throws -> [SheetPhoto] {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: url, to: tempDir)
        } catch {
            throw PhotoImportError.zipExtractionFailed
        }
        return try collectImages(in: tempDir, accessError: .zipExtractionFailed)
    }

    // MARK: - Common

    private func collectImages(in directory: URL, accessError: PhotoImportError) throws -> [SheetPhoto] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw accessError
        }
        var photos: [SheetPhoto] = []
        for case let fileURL as URL in enumerator {
            guard ImageDataDecoder.imageExtensions.contains(fileURL.pathExtension.lowercased()),
                  let data = try? Data(contentsOf: fileURL),
                  let aspect = ImageDataDecoder.aspectRatio(of: data) else {
                continue
            }
            photos.append(SheetPhoto(
                fileName: fileURL.lastPathComponent,
                imageData: data,
                aspectRatio: aspect,
                captureDate: ImageDataDecoder.captureDate(of: data)
            ))
        }
        return photos
    }
}
