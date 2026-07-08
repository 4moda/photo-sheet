import ImageIO
import UIKit

/// 写真の元データをセル表示用にダウンサンプリングしてキャッシュする。
/// セルは書き出し時でも高々 3000 / 2 列 = 1500px 程度なので、長辺 1500px に抑えてメモリを節約する。
final class PhotoImageCache {
    private var cache: [UUID: UIImage] = [:]
    private var rotatedCache: [UUID: UIImage] = [:]
    private let maxPixelSize: CGFloat = 1500

    /// - Parameter rotatedQuarterTurn: true のとき 90 度回転した画像を返す
    ///   （フィルムモードで写真の向きとコマの向きが合わないときに使う）
    func image(for photo: SheetPhoto, rotatedQuarterTurn: Bool = false) -> UIImage? {
        if rotatedQuarterTurn {
            if let cached = rotatedCache[photo.id] { return cached }
            guard let base = image(for: photo), let cgImage = base.cgImage else { return nil }
            // orientation ベースの回転はピクセルの再描画なしで済む
            let rotated = UIImage(cgImage: cgImage, scale: base.scale, orientation: .right)
            rotatedCache[photo.id] = rotated
            return rotated
        }
        if let cached = cache[photo.id] { return cached }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let source = CGImageSourceCreateWithData(photo.imageData as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        cache[photo.id] = image
        return image
    }

    func remove(_ id: UUID) {
        cache[id] = nil
        rotatedCache[id] = nil
    }

    func removeAll() {
        cache.removeAll()
        rotatedCache.removeAll()
    }
}
