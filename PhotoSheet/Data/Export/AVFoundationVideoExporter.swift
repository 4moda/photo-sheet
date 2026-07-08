import AVFoundation
import CoreVideo
import SwiftUI
import UIKit

/// AVAssetWriter でスクロール動画を書き出す。
/// SheetCanvasView を一度 ImageRenderer でレンダリングし、
/// フレームごとに viewport をシフトしながら MP4 を合成する。
final class AVFoundationVideoExporter: SheetVideoRenderer {

    // MARK: - 動画仕様

    /// Instagram Story 解像度（幅 × 高さ px）
    static let outputWidth  = 1080
    static let outputHeight = 1920
    static let fps: Int32   = 30
    /// 横・斜め方向でキャンバスを広げる倍率（この分だけセルが大きく見える）
    static let widePanFactor: CGFloat = 2.0

    private let canvasBuilder: @MainActor (Sheet, CGFloat) -> AnyView

    init(canvasBuilder: @MainActor @escaping (Sheet, CGFloat) -> AnyView) {
        self.canvasBuilder = canvasBuilder
    }

    // MARK: - SheetVideoRenderer

    @MainActor
    func renderVideo(sheet: Sheet, config: VideoExportConfig, outputURL: URL) async throws {
        // 1. 方向に応じてキャンバス幅を決定
        let canvasWidth: CGFloat = config.direction == .vertical
            ? CGFloat(Self.outputWidth)
            : CGFloat(Self.outputWidth) * Self.widePanFactor

        // 2. SwiftUI の ImageRenderer でキャンバス全体を一度だけレンダリング
        let view = canvasBuilder(sheet, canvasWidth)
        let imgRenderer = ImageRenderer(content: view)
        imgRenderer.proposedSize = ProposedViewSize(width: canvasWidth, height: nil)
        imgRenderer.scale = 1.0   // 1px = 1pt（フレーム切り出し時の座標系を統一）
        guard let fullImage = imgRenderer.uiImage else {
            throw VideoExportError.renderingFailed
        }

        // 3. viewport の移動パス（開始点 → 終了点）を計算
        let viewportW = CGFloat(Self.outputWidth)
        let viewportH = CGFloat(Self.outputHeight)
        let canvasH   = fullImage.size.height

        let maxPanX = max(0, fullImage.size.width  - viewportW)
        let maxPanY = max(0, canvasH               - viewportH)

        let endOffset = CGPoint(
            x: config.direction == .vertical   ? 0      : maxPanX,
            y: config.direction == .horizontal ? 0      : maxPanY
        )

        // 4. 背景色（シートが viewport より小さい場合のレターボックス）
        let bgColor = UIColor(
            red:   sheet.layout.background.color.red,
            green: sheet.layout.background.color.green,
            blue:  sheet.layout.background.color.blue,
            alpha: sheet.layout.background.color.alpha
        )

        // 5. バックグラウンドで MP4 を書き出す
        //    UIImage は @unchecked Sendable なので detached task に渡せる
        let totalFrames = Int(config.durationSeconds * Double(Self.fps))
        let fps         = Self.fps
        let outW        = Self.outputWidth
        let outH        = Self.outputHeight

        try await Task.detached(priority: .userInitiated) {
            try AVFoundationVideoExporter.writeMP4(
                fullImage:   fullImage,
                endOffset:   endOffset,
                viewportSize: CGSize(width: outW, height: outH),
                bgColor:     bgColor,
                totalFrames: totalFrames,
                fps:         fps,
                outputURL:   outputURL
            )
        }.value
    }

    // MARK: - MP4 書き出し（バックグラウンドスレッド）

    private static func writeMP4(
        fullImage:    UIImage,
        endOffset:    CGPoint,
        viewportSize: CGSize,
        bgColor:      UIColor,
        totalFrames:  Int,
        fps:          Int32,
        outputURL:    URL
    ) throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey:  AVVideoCodecType.h264,
            AVVideoWidthKey:  Int(viewportSize.width),
            AVVideoHeightKey: Int(viewportSize.height),
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
            kCVPixelBufferWidthKey          as String: Int(viewportSize.width),
            kCVPixelBufferHeightKey         as String: Int(viewportSize.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput:             writerInput,
            sourcePixelBufferAttributes:  pbAttrs
        )

        guard writer.canAdd(writerInput) else { throw VideoExportError.writingFailed }
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var frameIndex = 0
        let timeScale  = CMTimeScale(fps)

        // requestMediaDataWhenReady はコールバックベースのため
        // CheckedContinuation でブリッジする（同期書き出し）
        let sema = DispatchSemaphore(value: 0)
        var writeError: Error?

        writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "videowriter")) {
            while writerInput.isReadyForMoreMediaData {
                if frameIndex >= totalFrames {
                    writerInput.markAsFinished()
                    writer.finishWriting { sema.signal() }
                    return
                }

                let t       = totalFrames > 1
                    ? Double(frameIndex) / Double(totalFrames - 1)
                    : 0.0
                let eased   = Self.easeInOut(t)
                let offsetX = endOffset.x * eased
                let offsetY = endOffset.y * eased

                do {
                    let buf = try Self.makePixelBuffer(
                        from:         fullImage,
                        offsetX:      offsetX,
                        offsetY:      offsetY,
                        viewportSize: viewportSize,
                        bgColor:      bgColor,
                        poolRef:      adaptor.pixelBufferPool
                    )
                    let pts = CMTime(value: CMTimeValue(frameIndex), timescale: timeScale)
                    adaptor.append(buf, withPresentationTime: pts)
                    frameIndex += 1
                } catch {
                    writeError = error
                    writerInput.markAsFinished()
                    writer.finishWriting { sema.signal() }
                    return
                }
            }
        }

        sema.wait()

        if let err = writeError { throw err }
        if writer.status != .completed {
            throw VideoExportError.writingFailed
        }
    }

    // MARK: - フレーム生成

    private static func makePixelBuffer(
        from fullImage:  UIImage,
        offsetX:         Double,
        offsetY:         Double,
        viewportSize:    CGSize,
        bgColor:         UIColor,
        poolRef:         CVPixelBufferPool?
    ) throws -> CVPixelBuffer {
        var pbOpt: CVPixelBuffer?
        if let pool = poolRef {
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pbOpt)
        } else {
            let attrs: [CFString: Any] = [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey:           Int(viewportSize.width),
                kCVPixelBufferHeightKey:          Int(viewportSize.height),
                kCVPixelBufferIOSurfacePropertiesKey: [:]
            ]
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(viewportSize.width), Int(viewportSize.height),
                kCVPixelFormatType_32BGRA,
                attrs as CFDictionary, &pbOpt
            )
        }
        guard let pb = pbOpt else { throw VideoExportError.renderingFailed }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        guard let ctx = CGContext(
            data:             CVPixelBufferGetBaseAddress(pb),
            width:            Int(viewportSize.width),
            height:           Int(viewportSize.height),
            bitsPerComponent: 8,
            bytesPerRow:      CVPixelBufferGetBytesPerRow(pb),
            space:            CGColorSpaceCreateDeviceRGB(),
            bitmapInfo:       CGImageAlphaInfo.premultipliedFirst.rawValue
                              | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { throw VideoExportError.renderingFailed }

        // 背景塗りつぶし
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(CGRect(origin: .zero, size: viewportSize))

        // キャンバス画像のうち viewport に相当する領域を描画
        let srcRect = CGRect(
            x:      offsetX,
            y:      offsetY,
            width:  min(viewportSize.width,  fullImage.size.width  - offsetX),
            height: min(viewportSize.height, fullImage.size.height - offsetY)
        )
        let dstRect = CGRect(origin: .zero, size: srcRect.size)

        if srcRect.width > 0, srcRect.height > 0,
           let cgImg = fullImage.cgImage?.cropping(to: srcRect) {
            ctx.draw(cgImg, in: dstRect)
        }

        return pb
    }

    // MARK: - イージング

    /// ease-in-out（最初と最後をゆっくりにする）
    private static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}
