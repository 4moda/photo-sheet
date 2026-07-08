import Photos

/// 動画ファイルをカメラロールへ保存する（PHPhotoLibrary 経由）
struct PhotoLibraryVideoSaver: VideoLibrarySaver {
    func saveVideo(at url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw VideoExportError.authorizationDenied
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        } catch {
            throw VideoExportError.saveFailed
        }
    }
}
