import Foundation

/// フォトピッカーで選択済みの生データ（Photos フレームワーク型を Domain に持ち込まないための入れ物）
struct PickedPhotoData: Equatable {
    let suggestedName: String?
    let data: Data
}

/// 写真の取り込み元
enum PhotoImportSource: Equatable {
    case picked([PickedPhotoData])
    case folder(URL)
    case zip(URL)
}

/// 写真取り込みの境界。Photos / フォルダ / zip の違いは実装側（Data 層）が吸収する。
protocol PhotoSourceRepository {
    /// ソースから写真を読み込み、アスペクト比を解決して返す
    func loadPhotos(from source: PhotoImportSource) async throws -> [SheetPhoto]
}

enum PhotoImportError: Error, Equatable {
    case noImagesFound
    case folderAccessDenied
    case zipExtractionFailed
}
