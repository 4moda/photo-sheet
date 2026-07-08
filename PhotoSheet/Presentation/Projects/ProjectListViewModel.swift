import Foundation
import Observation

@MainActor
@Observable
final class ProjectListViewModel {
    private let repository: SheetProjectRepository

    var summaries: [SheetProjectSummary] = []
    var errorMessage: String?

    init(repository: SheetProjectRepository) {
        self.repository = repository
    }

    func reload() async {
        summaries = (try? await repository.listSummaries()) ?? []
    }

    func makeNewProject() -> SheetProject {
        SheetProject.new(now: Date())
    }

    func openProject(id: UUID) async -> SheetProject? {
        do {
            return try await repository.load(id: id)
        } catch {
            errorMessage = "プロジェクトを開けませんでした"
            return nil
        }
    }

    func deleteProject(id: UUID) {
        Task {
            try? await repository.delete(id: id)
            await reload()
        }
    }
}
