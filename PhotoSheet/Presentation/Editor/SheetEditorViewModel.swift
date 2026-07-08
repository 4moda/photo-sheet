import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class SheetEditorViewModel {
    private let importPhotosUseCase: ImportPhotosUseCase
    private let buildSheetUseCase: BuildSheetUseCase
    private let exportSheetUseCase: ExportSheetUseCase
    private let exportVideoUseCase: ExportSheetVideoUseCase
    private let imageCache: PhotoImageCache
    private let projectRepository: SheetProjectRepository

    /// 編集対象プロジェクトの識別情報
    private let projectId: UUID
    private let projectCreatedAt: Date

    var sheet = Sheet(photos: [], layout: .default)
    var isImporting = false
    var isExporting = false
    var errorMessage: String?
    var infoMessage: String?
    var shareImage: UIImage?
    var isSharePresented = false
    /// 動画書き出し設定（フローティングバーの動画パネルで変更）
    var videoConfig = VideoExportConfig.default
    /// 共有する動画ファイルの URL（セット → shareSheet 表示）
    var shareVideoURL: URL?
    var isVideoSharePresented = false

    /// PhotosPicker の選択。セットされたら即座に取り込みを開始する。
    var pickerItems: [PhotosPickerItem] = [] {
        didSet {
            guard !pickerItems.isEmpty else { return }
            let items = pickerItems
            pickerItems = []
            Task { await importPicked(items) }
        }
    }

    init(
        project: SheetProject,
        importPhotosUseCase: ImportPhotosUseCase,
        buildSheetUseCase: BuildSheetUseCase,
        exportSheetUseCase: ExportSheetUseCase,
        exportVideoUseCase: ExportSheetVideoUseCase,
        imageCache: PhotoImageCache,
        projectRepository: SheetProjectRepository
    ) {
        self.projectId = project.id
        self.projectCreatedAt = project.createdAt
        self.sheet = project.sheet
        self.importPhotosUseCase = importPhotosUseCase
        self.buildSheetUseCase = buildSheetUseCase
        self.exportSheetUseCase = exportSheetUseCase
        self.exportVideoUseCase = exportVideoUseCase
        self.imageCache = imageCache
        self.projectRepository = projectRepository
        // 前のプロジェクトの画像キャッシュを持ち越さない
        imageCache.removeAll()
    }

    // MARK: - Persistence

    /// プロジェクトをローカルへ保存する（エディタを閉じるときに呼ぶ）。
    /// 何も作らずに閉じた空プロジェクトは残さない。
    func persist() {
        let project = SheetProject(
            id: projectId,
            createdAt: projectCreatedAt,
            updatedAt: Date(),
            sheet: sheet
        )
        Task {
            if project.sheet.photos.isEmpty && project.sheet.title.isEmpty {
                try? await projectRepository.delete(id: project.id)
                return
            }
            // 一覧用サムネイルは実物と同じキャンバスを小さくレンダリングする（WYSIWYG）
            let thumbnail: Data? = project.sheet.photos.isEmpty
                ? nil
                : try? exportSheetUseCase.render(sheet: project.sheet, targetPixelWidth: 600)
            try? await projectRepository.save(project, thumbnailPNG: thumbnail)
        }
    }

    // MARK: - Import

    func importFolder(_ result: Result<URL, Error>) {
        handleFileResult(result) { .folder($0) }
    }

    func importZip(_ result: Result<URL, Error>) {
        handleFileResult(result) { .zip($0) }
    }

    private func handleFileResult(_ result: Result<URL, Error>, source: (URL) -> PhotoImportSource) {
        switch result {
        case .success(let url):
            let importSource = source(url)
            Task { await runImport(importSource) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func importPicked(_ items: [PhotosPickerItem]) async {
        isImporting = true
        var picked: [PickedPhotoData] = []
        // 追加取り込みでもコマ番号が重複しないよう、既存枚数から連番を振る
        let startNumber = sheet.photos.count + 1
        for (offset, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let name = String(format: "%02d", startNumber + offset)
                picked.append(PickedPhotoData(suggestedName: name, data: data))
            }
        }
        isImporting = false
        await runImport(.picked(picked))
    }

    private func runImport(_ source: PhotoImportSource) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let photos = try await importPhotosUseCase(source: source)
            if sheet.photos.isEmpty {
                sheet = buildSheetUseCase(photos: photos, basedOn: sheet)
            } else {
                // 追加取り込み: ユーザーが調整済みのレイアウトを崩さない
                sheet.photos.append(contentsOf: photos)
            }
            if sheet.caption.isEmpty {
                sheet.caption = Self.captionDateFormatter.string(from: Date())
            }
        } catch let error as PhotoImportError {
            errorMessage = importErrorMessage(error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Photo management

    func removePhoto(_ id: UUID) {
        sheet.photos.removeAll { $0.id == id }
        imageCache.remove(id)
    }

    func movePhoto(_ draggedId: UUID, toPositionOf targetId: UUID) {
        sheet.movePhoto(id: draggedId, toPositionOf: targetId)
    }

    func removeAllPhotos() {
        sheet.photos = []
        imageCache.removeAll()
    }

    // MARK: - Export

    func saveToPhotoLibrary() {
        guard !sheet.photos.isEmpty else { return }
        Task {
            isExporting = true
            defer { isExporting = false }
            do {
                try await exportSheetUseCase.saveToLibrary(sheet: sheet)
                infoMessage = "写真に保存しました"
            } catch let error as SheetExportError {
                errorMessage = exportErrorMessage(error)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func presentShareSheet() {
        guard !sheet.photos.isEmpty else { return }
        do {
            let data = try exportSheetUseCase.render(sheet: sheet)
            guard let image = UIImage(data: data) else {
                throw SheetExportError.renderingFailed
            }
            shareImage = image
            isSharePresented = true
        } catch {
            errorMessage = "画像の生成に失敗しました"
        }
    }

    func shareToInstagramStory() {
        guard !sheet.photos.isEmpty else { return }
        do {
            let data = try exportSheetUseCase.render(sheet: sheet)
            InstagramStoryService.share(pngData: data)
        } catch {
            errorMessage = "画像の生成に失敗しました"
        }
    }

    /// 動画をカメラロールへ保存する
    func saveVideoToPhotoLibrary() {
        guard !sheet.photos.isEmpty else { return }
        Task {
            isExporting = true
            defer { isExporting = false }
            do {
                try await exportVideoUseCase.saveToLibrary(sheet: sheet, config: videoConfig)
                infoMessage = "動画を保存しました"
            } catch let error as VideoExportError {
                errorMessage = videoErrorMessage(error)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 動画をレンダリングして共有シートを表示する
    func presentVideoShareSheet() {
        guard !sheet.photos.isEmpty else { return }
        Task {
            isExporting = true
            defer { isExporting = false }
            do {
                let url = try await exportVideoUseCase.render(sheet: sheet, config: videoConfig)
                shareVideoURL = url
                isVideoSharePresented = true
            } catch let error as VideoExportError {
                errorMessage = videoErrorMessage(error)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Formatters

    /// インデックスプリントの日付表記風（例: 2026.07.08）
    private static let captionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    // MARK: - Messages

    private func importErrorMessage(_ error: PhotoImportError) -> String {
        switch error {
        case .noImagesFound: "画像が見つかりませんでした"
        case .folderAccessDenied: "フォルダにアクセスできませんでした"
        case .zipExtractionFailed: "ZIP ファイルを展開できませんでした"
        }
    }

    private func exportErrorMessage(_ error: SheetExportError) -> String {
        switch error {
        case .renderingFailed: "画像の生成に失敗しました"
        case .authorizationDenied: "写真への追加が許可されていません。設定アプリから許可してください"
        case .saveFailed: "写真への保存に失敗しました"
        }
    }

    private func videoErrorMessage(_ error: VideoExportError) -> String {
        switch error {
        case .renderingFailed: "動画の生成に失敗しました"
        case .writingFailed: "動画の書き出しに失敗しました"
        case .authorizationDenied: "写真への追加が許可されていません。設定アプリから許可してください"
        case .saveFailed: "動画の保存に失敗しました"
        }
    }
}
