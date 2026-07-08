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

    static let outputWidth  = 1080
    static let outputHeight = 1920
    static let fps: Int32   = 30

    private let canvasBuilder: @MainActor (Sheet, CGFloat) -> AnyView

    init(canvasBuilder: @MainActor @escaping (Sheet, CGFloat) -> AnyView) {
        self.canvasBuilder = canvasBuilder
    }

    // MARK: - SheetVideoRenderer

    @MainActor
    func renderVideo(sheet: Sheet, config: VideoExportConfig, outputURL: URL) async throws {
        let canvasWidth = CGFloat(Self.outputWidth)

        // 1. キャンバス全体を一度だけレンダリング
        let view = canvasBuilder(sheet, canvasWidth)
        let imgRenderer = ImageRenderer(content: view)
        imgRenderer.proposedSize = ProposedViewSize(width: canvasWidth, height: nil)
        imgRenderer.scale = 1.0
        guard let fullImage = imgRenderer.uiImage else {
            throw VideoExportError.renderingFailed
        }

        // 2. ストリップのジオメトリを計算
        let outputSize = CGSize(width: Self.outputWidth, height: Self.outputHeight)
        let strips = Self.computeStrips(sheet: sheet, canvasWidth: canvasWidth, config: config)

        // 3. 背景色
        let bgColor = UIColor(
            red:   sheet.layout.background.color.red,
            green: sheet.layout.background.color.green,
            blue:  sheet.layout.background.color.blue,
            alpha: sheet.layout.background.color.alpha
        )

        // 4. フレーム仕様リストを事前構築（メモリ効率: UIImage は一枚だけ保持）
        let fps = Self.fps
        let specs = Self.buildFrameSpecs(config: config, strips: strips,
                                         canvasWidth: canvasWidth,
                                         canvasHeight: fullImage.size.height,
                                         outputSize: outputSize,
                                         fps: Double(fps))

        guard !specs.isEmpty else { throw VideoExportError.renderingFailed }

        // 5. MP4 を書き出す（suspension point で Main Actor を解放）
        try await Self.writeMP4(
            specs:      specs,
            fullImage:  fullImage,
            outputSize: outputSize,
            bgColor:    bgColor,
            fps:        fps,
            outputURL:  outputURL
        )
    }

    // MARK: - ストリップジオメトリ

/// 行をグループ化した「ストリップ」のキャンバス内 Y 範囲（行の正確な境界）
    struct StripGeometry {
        /// 最初の行のトップ Y 座標（canvas 座標、margin 込み）
        let yStart: CGFloat
        /// 最後の行のボトム Y 座標（canvas 座標、margin 込みではない）
        let yEnd: CGFloat
        var canvasHeight: CGFloat { yEnd - yStart }
    }

    /// ブリード込みの表示ジオメトリ（`buildFrameSpecs` 内で使用）
    private struct DisplayGeom {
        var yStart: CGFloat
        var height: CGFloat
        var pan:    CGFloat
        var panDur: Double
    }

    private static func computeStrips(
        sheet: Sheet,
        canvasWidth: CGFloat,
        config: VideoExportConfig
    ) -> [StripGeometry] {
        let layout = sheet.layout
        let w = Double(canvasWidth)
        let ranges = SheetLayoutMath.rowRanges(photoCount: sheet.photos.count, columns: layout.columns)
        guard !ranges.isEmpty else { return [] }

        let margin  = CGFloat(SheetLayoutMath.margin(layout, width: w))
        let spacing = CGFloat(SheetLayoutMath.spacing(layout, width: w))

        // 各行の Y 位置と高さを計算
        var rowTops: [CGFloat] = []
        var rowHeights: [CGFloat] = []
        var y = margin
        if SheetLayoutMath.hasHeader(sheet) {
            y += CGFloat(SheetLayoutMath.headerHeight(sheet, width: w)) + spacing
        }
        for rowRange in ranges {
            let photos = Array(sheet.photos[rowRange])
            let h: CGFloat
            switch layout.style {
            case .grid:
                let cw = CGFloat(SheetLayoutMath.gridCellWidth(layout, width: w))
                h = CGFloat(SheetLayoutMath.gridRowHeight(photos, layout: layout, cellWidth: Double(cw)))
            case .filmStrip:
                let fw = CGFloat(SheetLayoutMath.filmFrameWidth(layout, width: w))
                h = CGFloat(SheetLayoutMath.filmStripHeight(
                    frameWidth: Double(fw),
                    frameAspect: layout.filmFormat.frameAspect
                ))
            }
            rowTops.append(y)
            rowHeights.append(h)
            y += h + spacing
        }

        // visibleRows 行単位でストリップに分割（行の正確な境界を記録）
        let step = max(1, config.visibleRows)
        var strips: [StripGeometry] = []
        var i = 0
        while i < ranges.count {
            let endIdx = min(i + step - 1, ranges.count - 1)
            strips.append(StripGeometry(yStart: rowTops[i], yEnd: rowTops[endIdx] + rowHeights[endIdx]))
            i += step
        }
        return strips
    }

    // MARK: - フレーム仕様リスト

    /// 各フレームの描画命令（UIImage は保持しない）
    struct FrameSpec {
        enum Content {
            /// 全体俯瞰（canvas全体を outputWidth 幅に fit, 縦中央揃え）
            case overview
            /// ストリップ: キャンバス内のクロップ領域（キャンバス座標）を outputSize に引き伸ばす
            case strip(cropRect: CGRect)
        }
        var content: Content
        var alpha: CGFloat  // 0=黒, 1=完全表示
    }

    private static func buildFrameSpecs(
        config: VideoExportConfig,
        strips: [StripGeometry],
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        outputSize: CGSize,
        fps: Double
    ) -> [FrameSpec] {
        var specs: [FrameSpec] = []
        let overviewDur  = 2.0
        let fadeEdgeDur  = 0.4   // 概要フェーズへのフェード
        let fadeStripDur = 0.3   // ストリップ間フェード

        func frames(_ dur: Double) -> Int { max(1, Int(dur * fps)) }

        /// ブリード込みの表示ジオメトリを計算する（隣接行の端が少し見える）
        let bleedFraction: CGFloat = 0.2   // 行高さの 20% を上下に滲み出させる
        func displayGeom(_ strip: StripGeometry) -> DisplayGeom {
            let bleedPx = strip.canvasHeight * bleedFraction
            let dyStart = max(0, strip.yStart - bleedPx)
            let dyEnd   = min(canvasHeight, strip.yEnd + bleedPx)
            let dh      = max(1, dyEnd - dyStart)
            let sc      = outputSize.height / dh
            let cropW   = outputSize.width / sc
            let panAmt  = max(0, canvasWidth - cropW)
            let panDur  = max(0.5, Double(panAmt) / config.speed.canvasPixelsPerSecond)
            return DisplayGeom(yStart: dyStart, height: dh, pan: panAmt, panDur: panDur)
        }

        func cropRect(yStart: CGFloat, height: CGFloat, xOffset: CGFloat) -> CGRect {
            let sc    = outputSize.height / max(1, height)
            let cropW = min(outputSize.width / sc, canvasWidth - xOffset)
            return CGRect(x: xOffset, y: yStart, width: max(1, cropW), height: height)
        }

        // ─── 概要（冒頭） ───────────────────────────────────────────
        if config.showOverview {
            for _ in 0..<frames(overviewDur) {
                specs.append(.init(content: .overview, alpha: 1))
            }
            // フェードアウト
            let n = frames(fadeEdgeDur)
            for i in 0..<n {
                specs.append(.init(content: .overview, alpha: CGFloat(1 - Double(i) / Double(n))))
            }
        }

        // ─── ストリップ ────────────────────────────────────────────
        for (si, strip) in strips.enumerated() {
            let geom = displayGeom(strip)

            // フェードイン
            let fadeInFrames: Int
            if si == 0 && config.showOverview {
                fadeInFrames = frames(fadeEdgeDur)
            } else if si > 0 {
                fadeInFrames = frames(fadeStripDur)
            } else {
                fadeInFrames = 0
            }
            for idx in 0..<fadeInFrames {
                let alpha = CGFloat(Double(idx) / Double(max(1, fadeInFrames)))
                specs.append(.init(content: .strip(cropRect: cropRect(yStart: geom.yStart, height: geom.height, xOffset: 0)), alpha: alpha))
            }

            // パン本体
            let panFrames = frames(geom.panDur)
            for idx in 0..<panFrames {
                let progress = panFrames > 1 ? Double(idx) / Double(panFrames - 1) : 0
                let xOff = CGFloat(easeInOut(progress)) * geom.pan
                specs.append(.init(content: .strip(cropRect: cropRect(yStart: geom.yStart, height: geom.height, xOffset: xOff)), alpha: 1))
            }

            // フェードアウト
            let isLast = si == strips.count - 1
            let fadeOutFrames: Int
            if isLast && config.showOverview {
                fadeOutFrames = frames(fadeEdgeDur)
            } else if !isLast {
                fadeOutFrames = frames(fadeStripDur)
            } else {
                fadeOutFrames = 0
            }
            for idx in 0..<fadeOutFrames {
                let alpha = CGFloat(1 - Double(idx) / Double(max(1, fadeOutFrames)))
                specs.append(.init(content: .strip(cropRect: cropRect(yStart: geom.yStart, height: geom.height, xOffset: geom.pan)), alpha: alpha))
            }
        }

        // ─── 概要（末尾） ───────────────────────────────────────────
        if config.showOverview {
            // フェードイン
            let n = frames(fadeEdgeDur)
            for i in 0..<n {
                specs.append(.init(content: .overview, alpha: CGFloat(Double(i) / Double(n))))
            }
            for _ in 0..<frames(overviewDur) {
                specs.append(.init(content: .overview, alpha: 1))
            }
        }

        return specs
    }

    // MARK: - イージング

    private static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    // MARK: - MP4 書き出し

    /// AVAssetWriter で MP4 を書き出す。
    /// DispatchSemaphore の代わりに withCheckedThrowingContinuation を使い、
    /// Swift 協調スレッドプールをブロックしない。
    private static func writeMP4(
        specs:      [FrameSpec],
        fullImage:  UIImage,
        outputSize: CGSize,
        bgColor:    UIColor,
        fps:        Int32,
        outputURL:  URL
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
            kCVPixelBufferHeightKey         as String: Int(outputSize.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pbAttrs
        )
        guard writer.canAdd(writerInput) else { throw VideoExportError.writingFailed }
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var frameIndex = 0
        let timeScale  = CMTimeScale(fps)

        // continuation で Main Actor を解放したまま書き出しを待機
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var finished = false
            func complete(_ result: Result<Void, Error>) {
                guard !finished else { return }
                finished = true
                cont.resume(with: result)
            }

            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "photo.sheet.videowriter")) {
                while writerInput.isReadyForMoreMediaData {
                    if frameIndex >= specs.count {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            complete(writer.status == .completed
                                     ? .success(()) : .failure(VideoExportError.writingFailed))
                        }
                        return
                    }
                    do {
                        let pb = try makePixelBuffer(
                            spec:       specs[frameIndex],
                            fullImage:  fullImage,
                            outputSize: outputSize,
                            bgColor:    bgColor,
                            poolRef:    adaptor.pixelBufferPool
                        )
                        let pts = CMTime(value: CMTimeValue(frameIndex), timescale: timeScale)
                        adaptor.append(pb, withPresentationTime: pts)
                        frameIndex += 1
                    } catch {
                        writerInput.markAsFinished()
                        writer.finishWriting { complete(.failure(error)) }
                        return
                    }
                }
            }
        }
    }

    // MARK: - ピクセルバッファ生成

    private static func makePixelBuffer(
        spec:       FrameSpec,
        fullImage:  UIImage,
        outputSize: CGSize,
        bgColor:    UIColor,
        poolRef:    CVPixelBufferPool?
    ) throws -> CVPixelBuffer {
        // ① UIImage で frame を合成
        let frameImage = UIGraphicsImageRenderer(size: outputSize).image { _ in
            bgColor.setFill()
            UIRectFill(CGRect(origin: .zero, size: outputSize))

            switch spec.content {
            case .overview:
                // キャンバス全体を width fit で中央揃え
                let sc = outputSize.width / fullImage.size.width
                let dw = outputSize.width
                let dh = fullImage.size.height * sc
                let dy = (outputSize.height - dh) / 2
                fullImage.draw(in: CGRect(x: 0, y: dy, width: dw, height: dh))

            case .strip(let cr):
                // キャンバス内クロップ領域を outputSize に引き伸ばす
                guard cr.width > 0, cr.height > 0,
                      let cgImg = fullImage.cgImage?.cropping(to: cr) else { break }
                UIImage(cgImage: cgImg).draw(in: CGRect(origin: .zero, size: outputSize))
            }
        }

        // ② alpha フェード（黒オーバーレイ）
        let finalImage: UIImage
        if spec.alpha >= 0.999 {
            finalImage = frameImage
        } else {
            finalImage = UIGraphicsImageRenderer(size: outputSize).image { _ in
                frameImage.draw(at: .zero)
                UIColor.black.withAlphaComponent(1 - spec.alpha).setFill()
                UIRectFill(CGRect(origin: .zero, size: outputSize))
            }
        }

        // ③ UIImage → CVPixelBuffer
        return try pixelBuffer(from: finalImage, outputSize: outputSize, poolRef: poolRef)
    }

    private static func pixelBuffer(
        from image: UIImage,
        outputSize: CGSize,
        poolRef: CVPixelBufferPool?
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
        if let cgImg = image.cgImage {
            ctx.draw(cgImg, in: CGRect(origin: .zero, size: outputSize))
        }
        return pb
    }
}

