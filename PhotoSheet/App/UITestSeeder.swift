import UIKit

/// UIテスト / CIスクショ撮影用の決定論的なデモデータ投入。
/// `--uitest` 起動引数: プロジェクト保存先を一時ディレクトリへ切り替える（毎回まっさら）。
/// `--seed-demo` 起動引数: 生成画像入りのデモプロジェクトを 1 件作る。
/// 本番の起動経路には一切影響しない（引数がない限り何もしない）。
enum UITestSeeder {
    static var isUITest: Bool {
        CommandLine.arguments.contains("--uitest")
    }

    private static var shouldSeed: Bool {
        CommandLine.arguments.contains("--seed-demo")
    }

    /// UIテスト時のプロジェクト保存先（起動ごとに空の一時ディレクトリ）
    static func makeTestRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("uitest-projects-\(UUID().uuidString)", isDirectory: true)
    }

    /// 必要ならデモプロジェクトを投入する。アプリ起動前に完了させるため同期的にブロックする
    /// （テスト専用経路。通常起動では即 return）。
    static func seedIfRequested(repository: SheetProjectRepository) {
        guard isUITest, shouldSeed else { return }
        let project = makeDemoProject()
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            try? await repository.save(project, thumbnailPNG: nil)
            semaphore.signal()
        }
        semaphore.wait()
    }

    /// 生成画像 12 枚のデモシート。EXIF 相当の撮影日を持つ写真と持たない写真を混在させ、
    /// 撮影順整列・デート焼き込み・撮影日キャプションの状態も撮影できるようにする。
    private static func makeDemoProject() -> SheetProject {
        let baseDate = DateComponents(
            calendar: .current, year: 2026, month: 7, day: 12, hour: 10
        ).date ?? Date()
        let photos: [SheetPhoto] = (0..<12).map { index in
            let image = demoImage(index: index)
            let data = image.jpegData(compressionQuality: 0.8) ?? Data()
            return SheetPhoto(
                fileName: String(format: "%02d", index + 1),
                imageData: data,
                aspectRatio: 1.5,
                // 後半 4 枚は「EXIF なしのフィルムスキャン」を模して nil
                captureDate: index < 8 ? baseDate.addingTimeInterval(Double(index) * 1800) : nil
            )
        }
        var sheet = Sheet(photos: photos, layout: .default)
        sheet.title = "DEMO ROLL"
        sheet.caption = "2026.07.12"
        let now = Date()
        return SheetProject(id: UUID(), createdAt: now, updatedAt: now, sheet: sheet)
    }

    /// 単色 + コマ番号のシンプルな生成画像（デコード可能な実 JPEG にする）
    private static func demoImage(index: Int) -> UIImage {
        let size = CGSize(width: 600, height: 400)
        let hue = CGFloat(index) / 12.0
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(hue: hue, saturation: 0.45, brightness: 0.85, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 120, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let text = String(format: "%02d", index + 1) as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }
}
