import Foundation

/// ファイルベースのプロジェクト永続化。
/// Documents/Projects/<projectID>/ に manifest.json + photos/<photoID> + thumbnail.png を置く。
/// 写真データは manifest と分離して保存するため、一覧表示は写真を読まずに高速に行える。
final class FileSheetProjectRepository: SheetProjectRepository {
    private let root: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(root: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.root = root ?? documents.appendingPathComponent("Projects", isDirectory: true)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Stored form

    private struct PhotoManifest: Codable {
        let id: UUID
        let fileName: String
        let aspectRatio: Double
    }

    private struct Manifest: Codable {
        let id: UUID
        var title: String
        var caption: String
        var createdAt: Date
        var updatedAt: Date
        var layout: LayoutConfig
        var photos: [PhotoManifest]
    }

    // MARK: - Paths

    private func projectDir(_ id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func photosDir(_ id: UUID) -> URL {
        projectDir(id).appendingPathComponent("photos", isDirectory: true)
    }

    private func manifestURL(_ id: UUID) -> URL {
        projectDir(id).appendingPathComponent("manifest.json")
    }

    private func thumbnailURL(_ id: UUID) -> URL {
        projectDir(id).appendingPathComponent("thumbnail.png")
    }

    // MARK: - SheetProjectRepository

    func listSummaries() async throws -> [SheetProjectSummary] {
        let fileManager = FileManager.default
        guard let dirs = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var summaries: [SheetProjectSummary] = []
        for dir in dirs {
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("manifest.json")),
                  let manifest = try? decoder.decode(Manifest.self, from: data) else {
                continue
            }
            let thumbnail = dir.appendingPathComponent("thumbnail.png")
            summaries.append(SheetProjectSummary(
                id: manifest.id,
                title: manifest.title,
                caption: manifest.caption,
                photoCount: manifest.photos.count,
                updatedAt: manifest.updatedAt,
                thumbnailURL: fileManager.fileExists(atPath: thumbnail.path) ? thumbnail : nil
            ))
        }
        return summaries.sorted { $0.updatedAt > $1.updatedAt }
    }

    func load(id: UUID) async throws -> SheetProject {
        let data = try Data(contentsOf: manifestURL(id))
        let manifest = try decoder.decode(Manifest.self, from: data)
        let photoDir = photosDir(id)
        let photos: [SheetPhoto] = manifest.photos.compactMap { meta in
            let url = photoDir.appendingPathComponent(meta.id.uuidString)
            guard let imageData = try? Data(contentsOf: url) else { return nil }
            return SheetPhoto(id: meta.id, fileName: meta.fileName, imageData: imageData, aspectRatio: meta.aspectRatio)
        }
        var sheet = Sheet(photos: photos, layout: manifest.layout)
        sheet.title = manifest.title
        sheet.caption = manifest.caption
        return SheetProject(id: manifest.id, createdAt: manifest.createdAt, updatedAt: manifest.updatedAt, sheet: sheet)
    }

    func save(_ project: SheetProject, thumbnailPNG: Data?) async throws {
        let fileManager = FileManager.default
        let photoDir = photosDir(project.id)
        try fileManager.createDirectory(at: photoDir, withIntermediateDirectories: true)

        // 写真データは immutable なので、未保存のものだけ書く
        for photo in project.sheet.photos {
            let url = photoDir.appendingPathComponent(photo.id.uuidString)
            if !fileManager.fileExists(atPath: url.path) {
                try photo.imageData.write(to: url)
            }
        }
        // 削除された写真のファイルを掃除する
        let validNames = Set(project.sheet.photos.map { $0.id.uuidString })
        if let existing = try? fileManager.contentsOfDirectory(at: photoDir, includingPropertiesForKeys: nil) {
            for file in existing where !validNames.contains(file.lastPathComponent) {
                try? fileManager.removeItem(at: file)
            }
        }

        let manifest = Manifest(
            id: project.id,
            title: project.sheet.title,
            caption: project.sheet.caption,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            layout: project.sheet.layout,
            photos: project.sheet.photos.map {
                PhotoManifest(id: $0.id, fileName: $0.fileName, aspectRatio: $0.aspectRatio)
            }
        )
        try encoder.encode(manifest).write(to: manifestURL(project.id))

        if let thumbnailPNG {
            try? thumbnailPNG.write(to: thumbnailURL(project.id))
        }
    }

    func delete(id: UUID) async throws {
        try? FileManager.default.removeItem(at: projectDir(id))
    }
}
