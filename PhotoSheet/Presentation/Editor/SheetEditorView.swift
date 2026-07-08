import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 取り込み → 編集 → 書き出しの全体フロー
struct SheetEditorView: View {
    @State private var viewModel: SheetEditorViewModel
    private let imageCache: PhotoImageCache

    @State private var showPhotosPicker = false
    @State private var showFolderImporter = false
    @State private var showZipImporter = false

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
        .sheet(isPresented: $viewModel.isSharePresented) {
            if let image = viewModel.shareImage {
                ActivityView(activityItems: [image])
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
                        imageCache: imageCache
                    )
                }
            }
            .safeAreaInset(edge: .bottom) { bottomPanel }
        }
    }

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            ControlsView(viewModel: viewModel)
            ExportBar(viewModel: viewModel)
        }
        .background(.regularMaterial)
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
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showPhotosPicker = true
                } label: {
                    Label("フォトライブラリ", systemImage: "photo.on.rectangle")
                }
                Button {
                    showFolderImporter = true
                } label: {
                    Label("フォルダ", systemImage: "folder")
                }
                Button {
                    showZipImporter = true
                } label: {
                    Label("ZIP ファイル", systemImage: "doc.zipper")
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
