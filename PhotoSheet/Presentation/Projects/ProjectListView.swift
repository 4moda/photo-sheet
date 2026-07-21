import SwiftUI
import UIKit

/// 最上位画面: プロジェクト（シート作品）の一覧
struct ProjectListView: View {
    @State private var viewModel: ProjectListViewModel
    private let container: AppContainer

    @State private var activeProject: SheetProject?

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeProjectListViewModel())
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                if viewModel.summaries.isEmpty {
                    emptyState
                } else {
                    projectGrid
                }
            }
            .navigationTitle("Photo Sheet")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeProject = viewModel.makeNewProject()
                    } label: {
                        Label("新しいシート", systemImage: "plus")
                    }
                }
            }
        }
        .task { await viewModel.reload() }
        .fullScreenCover(item: $activeProject) {
            Task { await viewModel.reload() }
        } content: { project in
            container.makeSheetEditorView(project: project)
        }
        .alert("エラー", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Grid

    private var projectGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160), spacing: 16)],
                spacing: 16
            ) {
                ForEach(viewModel.summaries) { summary in
                    projectCard(summary)
                }
            }
            .padding()
        }
    }

    private func projectCard(_ summary: SheetProjectSummary) -> some View {
        Button {
            open(summary.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                thumbnail(summary)
                    .frame(height: 170)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(summary.title.isEmpty ? "無題のシート" : summary.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack {
                    Text(Self.dateFormatter.string(from: summary.updatedAt))
                    Spacer()
                    Text("\(summary.photoCount)枚")
                }
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color("CardSurface"), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteProject(id: summary.id)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func thumbnail(_ summary: SheetProjectSummary) -> some View {
        if let url = summary.thumbnailURL, let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(Color.gray.opacity(0.12))
                Image(systemName: "photo.stack")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("シートがありません", systemImage: "photo.stack")
        } description: {
            Text("写真を並べて、一つの作品として残しましょう。")
        } actions: {
            Button("新しいシートを作る") {
                activeProject = viewModel.makeNewProject()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private func open(_ id: UUID) {
        Task {
            if let project = await viewModel.openProject(id: id) {
                activeProject = project
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}
