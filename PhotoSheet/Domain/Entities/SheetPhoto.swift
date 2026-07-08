import Foundation

/// シートに並べる 1 枚の写真。画像データとメタデータのみを保持し、UI フレームワークには依存しない。
struct SheetPhoto: Identifiable, Equatable {
    let id: UUID
    /// インデックスプリントのコマ番号に相当するラベル（実ファイル名または連番）
    let fileName: String
    /// 元画像データ（JPEG / PNG / HEIC など）
    let imageData: Data
    /// アスペクト比（幅 / 高さ）
    let aspectRatio: Double

    init(id: UUID = UUID(), fileName: String, imageData: Data, aspectRatio: Double) {
        self.id = id
        self.fileName = fileName
        self.imageData = imageData
        self.aspectRatio = aspectRatio
    }
}
