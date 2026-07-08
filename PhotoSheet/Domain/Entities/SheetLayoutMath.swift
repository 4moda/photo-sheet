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
        !sheet.title.isEmpty || !sheet.caption.isEmpty
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

    static func filmFrameWidth(_ layout: LayoutConfig, width: Double) -> Double {
        let content = contentWidth(layout, width: width)
        let separator = filmSeparator(layout, width: width)
        return (content - separator * Double(layout.columns - 1)) / Double(layout.columns)
    }

    static func filmStripHeight(frameWidth: Double, frameAspect: Double) -> Double {
        let bands = frameWidth * (filmEdgeTextRatio * 2 + filmSprocketRatio * 2)
        return bands + frameWidth / frameAspect
    }

    /// フィルムでは長辺がストリップ方向を向くのが物理制約。
    /// 写真の向きとコマの向きが一致しないときは 90 度回転して収める。
    /// （35mm 横コマ × 縦写真 → 回転、ハーフ縦コマ × 横写真 → 回転）
    static func filmNeedsRotation(photoAspect: Double, frameAspect: Double) -> Bool {
        (photoAspect < 1) != (frameAspect < 1)
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
                frameAspect: layout.filmFormat.frameAspect
            )
            contentHeight = Double(ranges.count) * stripHeight
        }

        let headerH = headerHeight(sheet, width: width)
        let headerSpacing = hasHeader(sheet) && !ranges.isEmpty ? space : 0
        let rowSpacing = ranges.count > 1 ? space * Double(ranges.count - 1) : 0
        return margin(layout, width: width) * 2 + headerH + headerSpacing + contentHeight + rowSpacing
    }
}
