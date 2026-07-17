import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// SheetAdjustments を CoreImage で画素へ適用する。
/// プレビュー・PNG 書き出し・動画書き出しのすべてが PhotoImageCache 経由で
/// この処理済み画像を使うため、3 経路の見た目が一致する（WYSIWYG）。
/// 粒状感・周辺減光はネガ / レンズ由来なので写真ごとに適用するのが本物のふるまい。
enum FilmAdjustmentRenderer {
    private static let context = CIContext()

    static func apply(_ adjustments: SheetAdjustments, to image: CGImage) -> CGImage? {
        var ciImage = CIImage(cgImage: image)
        let extent = ciImage.extent

        // 彩度（モノクロ）とコントラスト
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.saturation = adjustments.monochrome ? 0 : 1
        colorControls.contrast = Float(1 + adjustments.contrast * 0.5)
        ciImage = colorControls.outputImage ?? ciImage

        // 色温度。モノクロ後に掛けるので、モノクロ時は調色（温黒調 / 冷黒調）として効く
        if adjustments.temperature != 0 {
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = ciImage
            temperature.neutral = CIVector(x: 6500, y: 0)
            temperature.targetNeutral = CIVector(x: 6500 + CGFloat(adjustments.temperature) * 1300, y: 0)
            ciImage = temperature.outputImage ?? ciImage
        }

        // フェード: シャドウの黒浮き（トーンカーブの足元を持ち上げる）
        if adjustments.fade > 0 {
            let lift = CGFloat(adjustments.fade) * 0.22
            let curve = CIFilter.toneCurve()
            curve.inputImage = ciImage
            curve.point0 = CGPoint(x: 0, y: lift)
            curve.point1 = CGPoint(x: 0.25, y: 0.25 + lift * 0.55)
            curve.point2 = CGPoint(x: 0.5, y: 0.5 + lift * 0.2)
            curve.point3 = CGPoint(x: 0.75, y: 0.75)
            curve.point4 = CGPoint(x: 1, y: 1)
            ciImage = curve.outputImage ?? ciImage
        }

        // 粒状感: 疑似乱数ノイズを中間グレー中心に整えてオーバーレイ合成。
        // CIRandomGenerator は座標に対して決定的なので、同じ設定なら常に同じ絵になる
        if adjustments.grain > 0, let noise = CIFilter.randomGenerator().outputImage?.cropped(to: extent) {
            let strength = CGFloat(adjustments.grain) * 0.5
            let third = strength / 3
            let matrix = CIFilter.colorMatrix()
            matrix.inputImage = noise
            matrix.rVector = CIVector(x: third, y: third, z: third, w: 0)
            matrix.gVector = CIVector(x: third, y: third, z: third, w: 0)
            matrix.bVector = CIVector(x: third, y: third, z: third, w: 0)
            matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
            matrix.biasVector = CIVector(
                x: 0.5 - strength / 2, y: 0.5 - strength / 2, z: 0.5 - strength / 2, w: 1
            )
            if let grainImage = matrix.outputImage {
                let blend = CIFilter.overlayBlendMode()
                blend.inputImage = grainImage
                blend.backgroundImage = ciImage
                ciImage = blend.outputImage?.cropped(to: extent) ?? ciImage
            }
        }

        // 周辺減光
        if adjustments.vignette > 0 {
            let vignette = CIFilter.vignette()
            vignette.inputImage = ciImage
            vignette.intensity = Float(adjustments.vignette) * 1.4
            vignette.radius = 1.8
            ciImage = vignette.outputImage ?? ciImage
        }

        return context.createCGImage(ciImage, from: extent)
    }
}
