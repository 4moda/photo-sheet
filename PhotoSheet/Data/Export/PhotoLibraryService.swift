import Foundation
import Photos

/// カメラロールへの保存（追加のみの権限で動作する）
struct PhotoLibraryService: PhotoLibrarySaver {
    func save(pngData: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SheetExportError.authorizationDenied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: pngData, options: nil)
            }
        } catch {
            throw SheetExportError.saveFailed
        }
    }
}
