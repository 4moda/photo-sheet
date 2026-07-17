import Foundation

/// 写真を取り込み、撮影順に並べる。
/// EXIF 撮影日時があるものは日時順、ないもの（フィルムスキャン等）はファイル名の自然順。
/// どの取り込み経路（Photos / フォルダ / zip）でも同じ順序規則を適用する。
struct ImportPhotosUseCase {
    private let repository: PhotoSourceRepository

    init(repository: PhotoSourceRepository) {
        self.repository = repository
    }

    func callAsFunction(source: PhotoImportSource) async throws -> [SheetPhoto] {
        let photos = try await repository.loadPhotos(from: source)
        guard !photos.isEmpty else { throw PhotoImportError.noImagesFound }
        return photos.sorted(by: SheetPhoto.captureOrder)
    }
}
