import Foundation

/// 1 つの作品（コンタクトシート）
struct Sheet: Equatable {
    var photos: [SheetPhoto]
    var layout: LayoutConfig
    /// シート上部に表示するタイトル（空なら非表示）
    var title: String = ""
    /// タイトル右側に表示するサブテキスト（日付・ロール番号など。空なら非表示）
    var caption: String = ""
    /// ON のときキャプションの代わりに EXIF 撮影日（範囲）を自動表示する
    var autoDateCaption: Bool = false

    /// ヘッダーに実際へ表示するキャプション。
    /// 自動表示 ON かつ撮影日情報があるときだけ撮影日範囲へ置き換わり、それ以外は手入力の caption。
    var displayCaption: String {
        guard autoDateCaption, let range = captureDateRange else { return caption }
        return Self.captionText(for: range)
    }

    /// 写真の EXIF 撮影日時の範囲（撮影日を持つ写真が 1 枚もなければ nil）
    var captureDateRange: ClosedRange<Date>? {
        let dates = photos.compactMap(\.captureDate)
        guard let earliest = dates.min(), let latest = dates.max() else { return nil }
        return earliest...latest
    }

    /// 撮影日範囲のキャプション表記（例: "2026.07.01 – 2026.07.14"、同日は "2026.07.14"）
    static func captionText(for range: ClosedRange<Date>) -> String {
        let start = captionDateFormatter.string(from: range.lowerBound)
        let end = captionDateFormatter.string(from: range.upperBound)
        return start == end ? start : "\(start) – \(end)"
    }

    /// インデックスプリントの日付表記風
    private static let captionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    /// 撮影順（EXIF 撮影日時 → なければファイル名の自然順）に並べ替える
    mutating func sortPhotosByCaptureDate() {
        photos.sort(by: SheetPhoto.captureOrder)
    }

    /// ドラッグした写真がドロップ先の位置に来るように並べ替える。
    /// フィルムモードのコマ番号は表示位置から振られるため、並べ替えに自動で追従する。
    mutating func movePhoto(id: UUID, toPositionOf targetId: UUID) {
        guard id != targetId,
              let from = photos.firstIndex(where: { $0.id == id }),
              let target = photos.firstIndex(where: { $0.id == targetId }) else {
            return
        }
        let photo = photos.remove(at: from)
        photos.insert(photo, at: min(target, photos.count))
    }
}
