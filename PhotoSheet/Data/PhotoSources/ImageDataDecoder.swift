import Foundation
import ImageIO

/// ImageIO を使った軽量なメタデータ読み取り
enum ImageDataDecoder {
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "bmp", "webp"
    ]

    /// 画像データからアスペクト比（幅 / 高さ）を取得する。フルデコードはしない。
    static func aspectRatio(of data: Data) -> Double? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double,
              width > 0, height > 0 else {
            return nil
        }
        // EXIF orientation が 90 度系（5〜8）の場合は縦横が入れ替わる
        if let orientation = properties[kCGImagePropertyOrientation] as? UInt32, (5...8).contains(orientation) {
            return height / width
        }
        return width / height
    }
}
