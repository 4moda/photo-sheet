import Foundation

/// Z スキャン動画書き出しのジオメトリ計算（Platform 非依存・Linux でテスト可能）
///
/// AVFoundationVideoExporter はこの型を使いフレーム仕様を決定し、
/// 実際のピクセル描画のみ自身で行う。
enum VideoExportGeometry {

    // MARK: - データ型

    /// シートキャンバス内の「ストリップ」（visibleRows 行ぶん）の Y 範囲
    struct StripGeometry: Equatable {
        /// ストリップ先頭行のトップ Y（キャンバス座標）
        let yStart: CGFloat
        /// ストリップ末尾行のボトム Y（キャンバス座標）
        let yEnd: CGFloat
        var canvasHeight: CGFloat { yEnd - yStart }
    }

    /// 1 フレームの描画命令
    struct FrameSpec: Equatable {
        enum Content: Equatable {
            /// キャンバス全体を幅フィットで中央揃え（概要フェーズ）
            case overview
            /// キャンバス内クロップ領域を出力サイズに引き伸ばす
            case strip(cropRect: CGRect)
        }
        var content: Content
        /// フェード係数: 0 = 黒, 1 = 完全表示
        var alpha: CGFloat
    }

    // MARK: - ストリップ分割

    /// 写真の行を `config.visibleRows` 行単位でストリップに分割する
    static func computeStrips(
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
                    format: layout.filmFormat
                ))
            case .negativeSleeve:
                let fw = CGFloat(SheetLayoutMath.filmFrameWidth(layout, width: w))
                h = CGFloat(SheetLayoutMath.sleeveStripHeight(
                    frameWidth: Double(fw),
                    format: layout.filmFormat
                ))
            }
            rowTops.append(y)
            rowHeights.append(h)
            y += h + spacing
        }

        let step = max(1, config.visibleRows)
        var strips: [StripGeometry] = []
        var idx = 0
        while idx < ranges.count {
            let endIdx = min(idx + step - 1, ranges.count - 1)
            strips.append(StripGeometry(yStart: rowTops[idx], yEnd: rowTops[endIdx] + rowHeights[endIdx]))
            idx += step
        }
        return strips
    }

    // MARK: - フレーム仕様リスト

    /// ストリップ群から全フレームの描画仕様を構築する
    ///
    /// - Parameters:
    ///   - canvasWidth: キャンバスの幅（px）
    ///   - canvasHeight: キャンバスの高さ（px）
    ///   - outputSize: 動画の出力サイズ（px）
    ///   - fps: フレームレート
    static func buildFrameSpecs(
        config: VideoExportConfig,
        strips: [StripGeometry],
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        outputSize: CGSize,
        fps: Double
    ) -> [FrameSpec] {
        var specs: [FrameSpec] = []
        let overviewDur  = 2.0
        let fadeEdgeDur  = 0.4
        let fadeStripDur = 0.3
        let bleedFraction: CGFloat = 0.2

        func frames(_ dur: Double) -> Int { max(1, Int(dur * fps)) }

        struct DisplayGeom {
            var yStart: CGFloat
            var height: CGFloat
            var pan:    CGFloat
            var panDur: Double
        }

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
            let n = frames(fadeEdgeDur)
            for i in 0..<n {
                specs.append(.init(content: .overview, alpha: CGFloat(1 - Double(i) / Double(n))))
            }
        }

        // ─── ストリップ ────────────────────────────────────────────
        for (si, strip) in strips.enumerated() {
            let geom = displayGeom(strip)

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

            let panFrames = frames(geom.panDur)
            for idx in 0..<panFrames {
                let progress = panFrames > 1 ? Double(idx) / Double(panFrames - 1) : 0
                let xOff = CGFloat(easeInOut(progress)) * geom.pan
                specs.append(.init(content: .strip(cropRect: cropRect(yStart: geom.yStart, height: geom.height, xOffset: xOff)), alpha: 1))
            }

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

    static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}
