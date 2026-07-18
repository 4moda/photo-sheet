import AVFoundation
import CoreVideo
import SwiftUI
import UIKit

/// Z スキャン方式のスクロール動画を AVAssetWriter で書き出す。
///
/// # アルゴリズム
/// 1. SwiftUI の ImageRenderer でキャンバス全体を一度レンダリング
/// 2. SheetLayoutMath から行の Y 座標を算出し、visibleRows 行単位の「ストリップ」に分割
/// 3. 各ストリップ: 縦方向にズームして水平パン（左→右）
/// 4. ストリップ間はフェード・ブラックで切り替え（Z 字を描くように進む）
/// 5. 前後に全体俯瞰フェーズを任意挿入
final class AVFoundationVideoExporter: SheetVideoRenderer {

    // MARK: - 動画仕様

    static let fps: Int32 = 30

    private let canvasBuilder: @MainActor (Sheet, CGFloat) -> AnyView

    init(canvasBuilder: @MainActor @escaping (Sheet, CGFloat) -> AnyView) {
        self.canvasBuilder = canvasBuilder
    }

    // MARK: - SheetVideoRenderer

    @MainActor
    func renderVideo(
        sheet: Sheet,
        config: VideoExportConfig,
        outputURL: URL,
        onProgress: @Sendable (Double) async -> Void
    ) async throws {
        let outputSize = config.preset.outputSize
        let canvasWidth = outputSize.width

        // 1. キャンバス全体を一度だけレンダリング
        let view = canvasBuilder(sheet, canvasWidth)
        let imgRenderer = ImageRenderer(content: view)
        imgRenderer.proposedSize = ProposedViewSize(width: canvasWidth, height: nil)
        imgRenderer.scale = 1.0
        guard let fullImage = imgRenderer.uiImage else {
            throw VideoExportError.renderingFailed
        }
        guard let fullCGImage = fullImage.cgImage else {
            throw VideoExportError.renderingFailed
        }

        // 2. ストリップのジオメトリを計算
        let strips = VideoExportGeometry.computeStrips(sheet: sheet, canvasWidth: canvasWidth, config: config)

        // 3. 背景色
        let bgColor = UIColor(
            red:   sheet.layout.background.color.red,
            green: sheet.layout.background.color.green,
            blue:  sheet.layout.background.color.blue,
            alpha: sheet.layout.background.color.alpha
        )

        // 4. フレーム仕様リストを事前構築（メモリ効率: UIImage は一枚だけ保持）
        let fps = Self.fps
        let specs = VideoExportGeometry.buildFrameSpecs(
            config: config, strips: strips,
            canvasWidth: canvasWidth,
            canvasHeight: fullImage.size.height,
            outputSize: outputSize,
            fps: Double(fps)
        )

        guard !specs.isEmpty else { throw VideoExportError.renderingFailed }

        // 5. MP4 を書き出す（suspension point で Main Actor を解放）
        try await Self.writeMP4(
            specs:      specs,
            fullCGImage: fullCGImage,
            fullImageSize: fullImage.size,
            outputSize: outputSize,
            bgColor:    bgColor,
            fps:        fps,
            outputURL:  outputURL,
            onProgress: onProgress
        )
    }

    // MARK: - MP4 書き出し

    /// AVAssetWriter で MP4 を書き出す。
    /// requestMediaDataWhenReady の代わりに async ループを使い、
    /// コールバックが呼ばれない Simulator 上のハングを回避する。
    private static func writeMP4(
        specs:      [VideoExportGeometry.FrameSpec],
        fullCGImage: CGImage,
        fullImageSize: CGSize,
        outputSize: CGSize,
        bgColor:    UIColor,
        fps:        Int32,
        outputURL:  URL,
        onProgress: @Sendable (Double) async -> Void
    ) async throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey:  AVVideoCodecType.h264,
            AVVideoWidthKey:  Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey:         8_000_000,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        let pbAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey          as String: Int(outputSize.width),
            kCVPixelBufferHeightKey         as String: Int(outputSize.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pbAttrs
        )
        guard writer.canAdd(writerInput) else { throw VideoExportError.writingFailed }
        writer.add(writerInput)
        guard writer.startWriting() else {
            throw writer.error ?? VideoExportError.writingFailed
        }
        writer.startSession(atSourceTime: .zero)

        let timeScale = CMTimeScale(fps)
        let total = specs.count

        // フレームを順次書き込む（30 フレームごとに yield・進捗報告）
        for (frameIdx, spec) in specs.enumerated() {
            if frameIdx % 30 == 0 {
                await Task.yield()
                await onProgress(Double(frameIdx) / Double(max(1, total)))
            }

            // isReadyForMoreMediaData が false の間は待機（バッファがいっぱいのとき）
            var spinCount = 0
            while !writerInput.isReadyForMoreMediaData {
                await Task.yield()
                spinCount += 1
                if spinCount > 500 { throw VideoExportError.writingFailed }
            }

            let pb = try makePixelBuffer(
                spec:       spec,
                fullCGImage: fullCGImage,
                fullImageSize: fullImageSize,
                outputSize: outputSize,
                bgColor:    bgColor,
                poolRef:    adaptor.pixelBufferPool
            )
            let pts = CMTime(value: CMTimeValue(frameIdx), timescale: timeScale)
            guard adaptor.append(pb, withPresentationTime: pts) else {
                throw writer.error ?? VideoExportError.writingFailed
            }
        }

        writerInput.markAsFinished()
        await onProgress(1.0)

        // finishWriting は非同期コールバック → continuation でラップ
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            writer.finishWriting {
                if writer.status == .completed {
                    cont.resume()
                } else {
                    cont.resume(throwing: writer.error ?? VideoExportError.writingFailed)
                }
            }
        }
    }

    // MARK: - ピクセルバッファ生成

    private static func makePixelBuffer(
        spec:       VideoExportGeometry.FrameSpec,
        fullCGImage: CGImage,
        fullImageSize: CGSize,
        outputSize: CGSize,
        bgColor:    UIColor,
        poolRef:    CVPixelBufferPool?
    ) throws -> CVPixelBuffer {
        var pbOpt: CVPixelBuffer?
        if let pool = poolRef {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pbOpt)
        } else {
            let attrs: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey:           Int(outputSize.width),
                kCVPixelBufferHeightKey:          Int(outputSize.height),
                kCVPixelBufferIOSurfacePropertiesKey: [:]
            ]
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(outputSize.width), Int(outputSize.height),
                kCVPixelFormatType_32BGRA,
                attrs as CFDictionary, &pbOpt
            )
        }
        guard let pb = pbOpt else { throw VideoExportError.renderingFailed }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }
        guard let ctx = CGContext(
            data:             CVPixelBufferGetBaseAddress(pb),
            width:            Int(outputSize.width),
            height:           Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow:      CVPixelBufferGetBytesPerRow(pb),
            space:            CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:       CGImageAlphaInfo.premultipliedFirst.rawValue
                              | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { throw VideoExportError.renderingFailed }

        let frameRect = CGRect(origin: .zero, size: outputSize)
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(frameRect)

        switch spec.content {
        case .overview:
            // キャンバス全体を width fit で中央揃え
            let sc = outputSize.width / fullImageSize.width
            let dw = outputSize.width
            let dh = fullImageSize.height * sc
            let dy = (outputSize.height - dh) / 2
            ctx.draw(fullCGImage, in: CGRect(x: 0, y: dy, width: dw, height: dh))
        case .strip(let cr):
            // source crop を作らず、スケール+オフセットで直接描画
            guard cr.width > 0, cr.height > 0 else { break }
            let sx = outputSize.width / cr.width
            let sy = outputSize.height / cr.height
            let drawRect = CGRect(
                x: -cr.origin.x * sx,
                y: -cr.origin.y * sy,
                width: fullImageSize.width * sx,
                height: fullImageSize.height * sy
            )
            ctx.draw(fullCGImage, in: drawRect)
        }

        if spec.alpha < 0.999 {
            ctx.setFillColor(UIColor.black.withAlphaComponent(1 - spec.alpha).cgColor)
            ctx.fill(frameRect)
        }

        return pb
    }
}
