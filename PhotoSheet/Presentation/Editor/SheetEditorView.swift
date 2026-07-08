import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 取り込み → 編集 → 書き出しの全体フロー
struct SheetEditorView: View {
    @State private var viewModel: SheetEditorViewModel
    private let imageCache: PhotoImageCache
    @Environment(\.dismiss) private var dismiss

    @State private var showPhotosPicker = false
    @State private var showFolderImporter = false
    @State private var showZipImporter = false
    /// タップされた写真（削除メニューの対象）
    @State private var actionPhotoId: UUID?

    init(viewModel: SheetEditorViewModel, imageCache: PhotoImageCache) {
        _viewModel = State(initialValue: viewModel)
        self.imageCache = imageCache
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            content
                .navigationTitle("Photo Sheet")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $viewModel.pickerItems, matching: .images)
        .fileImporter(isPresented: $showFolderImporter, allowedContentTypes: [.folder]) { result in
            viewModel.importFolder(result)
        }
        .fileImporter(isPresented: $showZipImporter, allowedContentTypes: [.zip]) { result in
            viewModel.importZip(result)
        }
        .confirmationDialog(
            actionPhotoName ?? "写真",
            isPresented: actionPhotoBinding,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let id = actionPhotoId { viewModel.removePhoto(id) }
                actionPhotoId = nil
            }
        }
        .sheet(isPresented: $viewModel.isSharePresented) {
            if let image = viewModel.shareImage {
                ActivityView(activityItems: [image])
            }
        }
        .sheet(isPresented: $viewModel.isVideoSharePresented, onDismiss: {
            // 共有完了後に一時ファイルを削除する
            if let url = viewModel.shareVideoURL {
                try? FileManager.default.removeItem(at: url)
                viewModel.shareVideoURL = nil
            }
        }) {
            if let url = viewModel.shareVideoURL {
                ActivityView(activityItems: [url])
            }
        }
        .alert("エラー", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(viewModel.infoMessage ?? "", isPresented: infoBinding) {
            Button("OK", role: .cancel) {}
        }
        .overlay {
            if viewModel.isImporting || viewModel.isExporting {
                loadingOverlay
            }
        }
        .onDisappear {
            viewModel.persist()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.sheet.photos.isEmpty {
            emptyState
        } else {
            GeometryReader { geometry in
                ScrollView {
                    SheetCanvasView(
                        sheet: viewModel.sheet,
                        width: geometry.size.width,
                        imageCache: imageCache,
                        onTapPhoto: { actionPhotoId = $0 },
                        onMovePhoto: { viewModel.movePhoto($0, toPositionOf: $1) }
                    )
                    // フローティングバーに隠れないよう下端に余白を確保
                    .padding(.bottom, 96)
                }
            }
            .overlay(alignment: .bottom) {
                FloatingControlBar(viewModel: viewModel)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("写真を追加", systemImage: "photo.stack")
        } description: {
            Text("フォトライブラリ・フォルダ・ZIP から写真を選んで、コンタクトシートを作りましょう。")
        } actions: {
            Button("フォトライブラリから選ぶ") { showPhotosPicker = true }
                .buttonStyle(.borderedProminent)
            Button("フォルダから選ぶ") { showFolderImporter = true }
            Button("ZIP から選ぶ") { showZipImporter = true }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("完了") {
                dismiss()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showPhotosPicker = true
                } label: {
                    Label("フォトライブラリから追加", systemImage: "photo.on.rectangle")
                }
                Button {
                    showFolderImporter = true
                } label: {
                    Label("フォルダから追加", systemImage: "folder")
                }
                Button {
                    showZipImporter = true
                } label: {
                    Label("ZIP ファイルから追加", systemImage: "doc.zipper")
                }
                if !viewModel.sheet.photos.isEmpty {
                    Divider()
                    Button(role: .destructive) {
                        viewModel.removeAllPhotos()
                    } label: {
                        Label("すべての写真を削除", systemImage: "trash")
                    }
                }
            } label: {
                Label("写真を追加", systemImage: "plus")
            }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Bindings

    private var actionPhotoName: String? {
        guard let id = actionPhotoId else { return nil }
        return viewModel.sheet.photos.first(where: { $0.id == id })?.fileName
    }

    private var actionPhotoBinding: Binding<Bool> {
        Binding(
            get: { actionPhotoId != nil },
            set: { if !$0 { actionPhotoId = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var infoBinding: Binding<Bool> {
        Binding(
            get: { viewModel.infoMessage != nil },
            set: { if !$0 { viewModel.infoMessage = nil } }
        )
    }
}
