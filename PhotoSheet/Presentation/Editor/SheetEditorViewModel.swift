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
    private let imageCache: PhotoImageCache

    var sheet = Sheet(photos: [], layout: .default)
    var isImporting = false
    var isExporting = false
    var errorMessage: String?
    var infoMessage: String?
    var shareImage: UIImage?
    var isSharePresented = false

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
        importPhotosUseCase: ImportPhotosUseCase,
        buildSheetUseCase: BuildSheetUseCase,
        exportSheetUseCase: ExportSheetUseCase,
        imageCache: PhotoImageCache
    ) {
        self.importPhotosUseCase = importPhotosUseCase
        self.buildSheetUseCase = buildSheetUseCase
        self.exportSheetUseCase = exportSheetUseCase
        self.imageCache = imageCache
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
}
