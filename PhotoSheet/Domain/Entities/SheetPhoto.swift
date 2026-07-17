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
    /// EXIF の撮影日時。フィルムスキャン等のメタデータがない写真は nil
    let captureDate: Date?

    init(id: UUID = UUID(), fileName: String, imageData: Data, aspectRatio: Double, captureDate: Date? = nil) {
        self.id = id
        self.fileName = fileName
        self.imageData = imageData
        self.aspectRatio = aspectRatio
        self.captureDate = captureDate
    }
}

extension SheetPhoto {
    /// 撮影順の並び: EXIF 撮影日時があるものを日時順で先に置き、
    /// ないもの（フィルムスキャン等）はファイル名の自然順で後ろに続ける。
    /// スキャンデータはファイル名がスキャン順 = 撮影順であることが多いため、
    /// 「撮影順に並べる」という一つの操作で両方の実態をカバーする。
    static func captureOrder(_ a: SheetPhoto, _ b: SheetPhoto) -> Bool {
        switch (a.captureDate, b.captureDate) {
        case let (dateA?, dateB?):
            if dateA != dateB { return dateA < dateB }
            return a.fileName.localizedStandardCompare(b.fileName) == .orderedAscending
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return a.fileName.localizedStandardCompare(b.fileName) == .orderedAscending
        }
    }
}
