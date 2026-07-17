import ImageIO
import UIKit

/// 写真の元データをセル表示用にダウンサンプリングし、仕上げ調整を適用してキャッシュする。
/// セルは書き出し時でも高々 3000 / 2 列 = 1500px 程度なので、長辺 1500px に抑えてメモリを節約する。
final class PhotoImageCache {
    private var cache: [UUID: UIImage] = [:]
    private var rotatedCache: [UUID: UIImage] = [:]
    private let maxPixelSize: CGFloat = 1500
    /// 現在キャッシュ中の画像に適用済みの調整。変わったら全部作り直す
    private var appliedAdjustments: SheetAdjustments = .neutral

    /// - Parameters:
    ///   - adjustments: シートの仕上げ調整。前回と異なる場合はキャッシュを破棄して適用し直す
    ///   - rotatedQuarterTurn: true のとき 90 度回転した画像を返す
    ///     （フィルムモードで写真の向きとコマの向きが合わないときに使う）
    func image(
        for photo: SheetPhoto,
        adjustments: SheetAdjustments = .neutral,
        rotatedQuarterTurn: Bool = false
    ) -> UIImage? {
        if adjustments != appliedAdjustments {
            cache.removeAll()
            rotatedCache.removeAll()
            appliedAdjustments = adjustments
        }
        if rotatedQuarterTurn {
            if let cached = rotatedCache[photo.id] { return cached }
            guard let base = image(for: photo, adjustments: adjustments),
                  let cgImage = base.cgImage else { return nil }
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
              var cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        if !adjustments.isNeutral, let adjusted = FilmAdjustmentRenderer.apply(adjustments, to: cgImage) {
            cgImage = adjusted
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
