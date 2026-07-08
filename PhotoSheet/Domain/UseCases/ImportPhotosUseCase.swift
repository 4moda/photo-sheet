import Foundation

/// 写真を取り込む。Photos は選択順を保持し、フォルダ / zip はファイル名の自然順に並べる。
struct ImportPhotosUseCase {
    private let repository: PhotoSourceRepository

    init(repository: PhotoSourceRepository) {
        self.repository = repository
    }

    func callAsFunction(source: PhotoImportSource) async throws -> [SheetPhoto] {
        let photos = try await repository.loadPhotos(from: source)
        guard !photos.isEmpty else { throw PhotoImportError.noImagesFound }
        switch source {
        case .picked:
            return photos
        case .folder, .zip:
            return photos.sorted {
                $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
            }
        }
    }
}
