import Foundation

/// キャンバス描画と高さ計算の唯一の寸法ソース。
/// すべてシート幅（またはコマ幅）に対する比率で計算するため、どの解像度で描画しても相似形になる。
/// ビュー側は必ずここの値を使うこと（描画と naturalHeight の整合が WYSIWYG と用紙比率固定の前提）。
enum SheetLayoutMath {
    // MARK: - 比率定数

    /// ヘッダー行の高さ（シート幅比）
    static let headerZoneRatio = 0.045
    /// grid: 写真とラベルの間隔（セル幅比）
    static let gridLabelGapRatio = 0.04
    /// grid: ラベル文字ゾーンの高さ（セル幅比）
    static let gridLabelTextRatio = 0.09
    /// film: コマ間の黒い境界（コンテンツ幅比）
    static let filmSeparatorRatio = 0.008
    /// film: エッジテキスト帯・コマ番号帯の高さ（コマ幅比）
    static let filmEdgeTextRatio = 0.10
    /// film: スプロケット帯の高さ（コマ幅比）
    static let filmSprocketRatio = 0.08
    /// grid の 3:2 セル用の比率（35mm フルフレームと同じ）
    static let film3x2Aspect = 3.0 / 2.0
    /// film: 1 コマあたりのスプロケット穴数（35mm 実物と同じ 8 パーフォレーション）
    static let sprocketHolesPerFrame = 8
    /// sleeve: ポケットの上下余白（コマ幅比）
    static let sleevePaddingRatio = 0.06
    /// sleeve: バインダー穴の余白（コンテンツ幅比）
    static let sleevePunchMarginRatio = 0.07
    /// film: ストリップ端の切り残し余白（コンテンツ幅比）。実物はカットで先頭・末尾に数 mm 残る
    static let filmLeaderRatio = 0.012
    /// film: 手貼りオフセットの最大値（シート幅比）
    static let stripLayMaxOffsetRatio = 0.004
    /// film: 手貼り回転の最大値（度）
    static let stripLayMaxRotationDegrees = 0.22

    // MARK: - 共通

    static func margin(_ layout: LayoutConfig, width: Double) -> Double {
        width * layout.marginRatio
    }

    static func spacing(_ layout: LayoutConfig, width: Double) -> Double {
        width * layout.spacingRatio
    }

    static func contentWidth(_ layout: LayoutConfig, width: Double) -> Double {
        width - margin(layout, width: width) * 2
    }

    static func hasHeader(_ sheet: Sheet) -> Bool {
        !sheet.title.isEmpty || !sheet.displayCaption.isEmpty
    }

    static func headerHeight(_ sheet: Sheet, width: Double) -> Double {
        hasHeader(sheet) ? width * headerZoneRatio : 0
    }

    /// 写真を行（ストリップ）ごとの Range に分割する
    static func rowRanges(photoCount: Int, columns: Int) -> [Range<Int>] {
        guard photoCount > 0, columns > 0 else { return [] }
        return stride(from: 0, to: photoCount, by: columns).map { start in
            start..<min(start + columns, photoCount)
        }
    }

    // MARK: - grid スタイル

    static func gridCellWidth(_ layout: LayoutConfig, width: Double) -> Double {
        let content = contentWidth(layout, width: width)
        let space = spacing(layout, width: width)
        return (content - space * Double(layout.columns - 1)) / Double(layout.columns)
    }

    static func gridPhotoHeight(_ photo: SheetPhoto, layout: LayoutConfig, cellWidth: Double) -> Double {
        switch layout.cellAspect {
        case .film3x2: cellWidth / film3x2Aspect
        case .square: cellWidth
        case .original: cellWidth / max(photo.aspectRatio, 0.05)
        }
    }

    static func gridLabelHeight(_ layout: LayoutConfig, cellWidth: Double) -> Double {
        layout.showFilename ? cellWidth * (gridLabelGapRatio + gridLabelTextRatio) : 0
    }

    static func gridRowHeight(_ photos: [SheetPhoto], layout: LayoutConfig, cellWidth: Double) -> Double {
        let maxPhotoHeight = photos
            .map { gridPhotoHeight($0, layout: layout, cellWidth: cellWidth) }
            .max() ?? 0
        return maxPhotoHeight + gridLabelHeight(layout, cellWidth: cellWidth)
    }

    // MARK: - filmStrip スタイル

    static func filmSeparator(_ layout: LayoutConfig, width: Double) -> Double {
        contentWidth(layout, width: width) * filmSeparatorRatio
    }

    /// ストリップ端の切り残し余白（片側分）
    static func filmLeader(_ layout: LayoutConfig, width: Double) -> Double {
        contentWidth(layout, width: width) * filmLeaderRatio
    }

    /// コマ index の直後の間隔。ハーフフレームは実物どおり「2 コマで 35mm 1 コマ分」なので、
    /// ペア内は密着（0.25 倍）・ペア間は広め（1.75 倍）に振り分ける（平均は separator と同じ）
    static func filmGapWidth(afterFrame index: Int, format: FilmFormat, separator: Double) -> Double {
        guard format == .halfFrame else { return separator }
        return index.isMultiple(of: 2) ? separator * 0.25 : separator * 1.75
    }

    /// 行内の全間隔の合計
    static func filmGapsTotal(columns: Int, format: FilmFormat, separator: Double) -> Double {
        guard columns > 1 else { return 0 }
        return (0..<(columns - 1)).reduce(0.0) {
            $0 + filmGapWidth(afterFrame: $1, format: format, separator: separator)
        }
    }

    static func filmFrameWidth(_ layout: LayoutConfig, width: Double) -> Double {
        let content = contentWidth(layout, width: width)
        let separator = filmSeparator(layout, width: width)
        let leader = filmLeader(layout, width: width)
        let gaps = filmGapsTotal(columns: layout.columns, format: layout.filmFormat, separator: separator)
        return (content - leader * 2 - gaps) / Double(layout.columns)
    }

    // MARK: - 手貼り感（filmStrip）

    /// 行ごとの決定論的な擬似乱数 [0, 1)。整数ハッシュ（splitmix64）ベースなので
    /// プレビュー・書き出し・スナップショットで常に同じ値になる（WYSIWYG の前提）。
    static func stripLayNoise(row: Int, salt: UInt64) -> Double {
        var value = UInt64(bitPattern: Int64(row)) &+ salt &+ 0x9E37_79B9_7F4A_7C15
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value % 100_000) / 100_000.0
    }

    /// 手貼り感: 行ごとの僅かな横オフセット（シート幅比、±stripLayMaxOffsetRatio）。
    /// ベタ焼きは 6 コマずつ切ったストリップを手で並べるため、実物は行が完全には揃わない。
    static func stripLayOffsetRatio(row: Int) -> Double {
        (stripLayNoise(row: row, salt: 0x0FF5_E7) - 0.5) * 2 * stripLayMaxOffsetRatio
    }

    /// 手貼り感: 行ごとの僅かな回転（度、±stripLayMaxRotationDegrees）
    static func stripLayRotationDegrees(row: Int) -> Double {
        (stripLayNoise(row: row, salt: 0x0207_A7E) - 0.5) * 2 * stripLayMaxRotationDegrees
    }

    static func filmStripHeight(frameWidth: Double, format: FilmFormat) -> Double {
        let sprocketBands = format.hasSprocketHoles ? filmSprocketRatio * 2 : 0
        let bands = frameWidth * (filmEdgeTextRatio * 2 + sprocketBands)
        return bands + frameWidth / format.frameAspect
    }

    // MARK: - negativeSleeve スタイル

    /// バインダー穴の余白幅
    static func sleevePunchMargin(_ layout: LayoutConfig, width: Double) -> Double {
        contentWidth(layout, width: width) * sleevePunchMarginRatio
    }

    /// スリーブに入るフィルムストリップが使える幅（コンテンツ幅 − バインダー穴余白）
    static func sleeveContentWidth(_ layout: LayoutConfig, width: Double) -> Double {
        contentWidth(layout, width: width) - sleevePunchMargin(layout, width: width)
    }

    /// スリーブ内のコマ幅。中身は実物どおり「切ったフィルムストリップ」なので
    /// 端の切り残し余白（leader）・ハーフのペア間隔も含めて計算する
    static func sleeveFrameWidth(_ layout: LayoutConfig, width: Double) -> Double {
        let content = sleeveContentWidth(layout, width: width)
        let separator = filmSeparator(layout, width: width)
        let leader = filmLeader(layout, width: width)
        let gaps = filmGapsTotal(columns: layout.columns, format: layout.filmFormat, separator: separator)
        return (content - leader * 2 - gaps) / Double(layout.columns)
    }

    /// スリーブ 1 段（ポケット）の高さ。中身のフィルムストリップ + 上下のポケット余白
    static func sleeveStripHeight(frameWidth: Double, format: FilmFormat) -> Double {
        frameWidth * sleevePaddingRatio * 2 + filmStripHeight(frameWidth: frameWidth, format: format)
    }

    /// フィルムでは長辺がストリップ方向を向くのが物理制約。
    /// 写真の向きとコマの向きが一致しないときは 90 度回転して収める。
    /// （35mm 横コマ × 縦写真 → 回転、ハーフ縦コマ × 横写真 → 回転）
    /// 正方形コマ（6×6）には向きがないため回転しない。
    static func filmNeedsRotation(photoAspect: Double, frameAspect: Double) -> Bool {
        guard frameAspect != 1 else { return false }
        return (photoAspect < 1) != (frameAspect < 1)
    }

    // MARK: - 全体の高さ

    /// コンテンツの自然な高さ（用紙比率固定モードではこの値と目標高さの比でスケールする）
    static func naturalHeight(sheet: Sheet, width: Double) -> Double {
        let layout = sheet.layout
        let ranges = rowRanges(photoCount: sheet.photos.count, columns: layout.columns)
        let space = spacing(layout, width: width)

        let contentHeight: Double
        switch layout.style {
        case .grid:
            let cellWidth = gridCellWidth(layout, width: width)
            contentHeight = ranges
                .map { gridRowHeight(Array(sheet.photos[$0]), layout: layout, cellWidth: cellWidth) }
                .reduce(0, +)
        case .filmStrip:
            let frameWidth = filmFrameWidth(layout, width: width)
            let stripHeight = filmStripHeight(
                frameWidth: frameWidth,
                format: layout.filmFormat
            )
            contentHeight = Double(ranges.count) * stripHeight
        case .negativeSleeve:
            let frameWidth = sleeveFrameWidth(layout, width: width)
            let stripHeight = sleeveStripHeight(
                frameWidth: frameWidth,
                format: layout.filmFormat
            )
            contentHeight = Double(ranges.count) * stripHeight
        }

        let headerH = headerHeight(sheet, width: width)
        let headerSpacing = hasHeader(sheet) && !ranges.isEmpty ? space : 0
        let rowSpacing = ranges.count > 1 ? space * Double(ranges.count - 1) : 0
        return margin(layout, width: width) * 2 + headerH + headerSpacing + contentHeight + rowSpacing
    }
}
