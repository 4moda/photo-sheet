import Foundation

/// プロジェクトの永続化境界（ローカル保存）
protocol SheetProjectRepository {
    func listSummaries() async throws -> [SheetProjectSummary]
    func load(id: UUID) async throws -> SheetProject
    /// - Parameter thumbnailPNG: 一覧表示用のサムネイル（レンダリング済み PNG）。nil なら据え置き。
    func save(_ project: SheetProject, thumbnailPNG: Data?) async throws
    func delete(id: UUID) async throws
}
