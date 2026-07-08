import Foundation

/// 1 つの作品（コンタクトシート）
struct Sheet: Equatable {
    var photos: [SheetPhoto]
    var layout: LayoutConfig
    /// シート上部に表示するタイトル（空なら非表示）
    var title: String = ""
    /// タイトル右側に表示するサブテキスト（日付・ロール番号など。空なら非表示）
    var caption: String = ""

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
