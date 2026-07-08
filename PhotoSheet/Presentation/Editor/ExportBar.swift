import SwiftUI

/// 保存・共有・Story 共有のアクションバー
struct ExportBar: View {
    let viewModel: SheetEditorViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.saveToPhotoLibrary()
            } label: {
                Label("保存", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)

            Button {
                viewModel.presentShareSheet()
            } label: {
                Label("共有", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)

            if InstagramStoryService.isAvailable {
                Button {
                    viewModel.shareToInstagramStory()
                } label: {
                    Label("Story", systemImage: "camera")
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .disabled(viewModel.sheet.photos.isEmpty || viewModel.isExporting)
    }
}
