import Foundation

/// 最上位の概念。1 プロジェクト = 1 枚のコンタクトシート作品。
struct SheetProject: Identifiable, Equatable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var sheet: Sheet

    /// 新規プロジェクト
    static func new(now: Date) -> SheetProject {
        SheetProject(id: UUID(), createdAt: now, updatedAt: now, sheet: Sheet(photos: [], layout: .default))
    }
}

/// 一覧表示用の軽量サマリー（写真データは読み込まない）
struct SheetProjectSummary: Identifiable, Equatable {
    let id: UUID
    var title: String
    var caption: String
    var photoCount: Int
    var updatedAt: Date
    var thumbnailURL: URL?
}
