import SwiftUI

/// シート本体の描画ビュー。プレビューにも書き出しにも同じものを使う（WYSIWYG）。
/// 寸法はすべて SheetLayoutMath から取得し、幅に対する比率で解釈するため、
/// どの幅で描画しても相似形になる。
struct SheetCanvasView: View {
    let sheet: Sheet
    let width: CGFloat
    let imageCache: PhotoImageCache
    /// エディタから渡される操作ハンドラ。nil のとき（書き出し時）は操作 UI を一切付けない。
    /// タップ = 写真メニュー、長押しドラッグ → 他の写真へドロップ = 並べ替え。
    var onTapPhoto: ((UUID) -> Void)?
    var onMovePhoto: ((_ dragged: UUID, _ target: UUID) -> Void)?

    /// ドラッグ中に hover しているドロップ先写真の ID
    @State private var dropTargetId: UUID?

    private var layout: LayoutConfig { sheet.layout }
    private var margin: Double { SheetLayoutMath.margin(layout, width: width) }
    private var spacing: Double { SheetLayoutMath.spacing(layout, width: width) }

    private var rowRanges: [Range<Int>] {
        SheetLayoutMath.rowRanges(photoCount: sheet.photos.count, columns: layout.columns)
    }

    var body: some View {
        if let ratio = layout.paperFormat.aspectRatio {
            fixedPaperBody(ratio: ratio)
        } else {
            sheetContent
                .background(Color(rgba: layout.background.color))
        }
    }

    /// 用紙比率固定: 内容が収まらない場合は相似形のまま縮小して収める
    private func fixedPaperBody(ratio: Double) -> some View {
        let outerHeight = width / ratio
        let naturalHeight = SheetLayoutMath.naturalHeight(sheet: sheet, width: width)
        let scale = naturalHeight > 0 ? min(1, outerHeight / naturalHeight) : 1
        return ZStack(alignment: .top) {
            Color(rgba: layout.background.color)
            sheetContent
                .scaleEffect(scale, anchor: .top)
        }
        .frame(width: width, height: outerHeight)
        .clipped()
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if SheetLayoutMath.hasHeader(sheet) {
                headerView
            }
            switch layout.style {
            case .grid:
                gridRows
            case .filmStrip:
                filmRows
            }
        }
        .padding(margin)
        .frame(width: width, alignment: .topLeading)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(sheet.title.uppercased())
                .font(.system(size: width * 0.024, weight: .semibold, design: .monospaced))
                .tracking(width * 0.004)
            Spacer(minLength: 0)
            Text(sheet.displayCaption)
                .font(.system(size: width * 0.019, design: .monospaced))
                .opacity(0.65)
        }
        .foregroundStyle(labelColor)
        .lineLimit(1)
        .frame(height: SheetLayoutMath.headerHeight(sheet, width: width), alignment: .bottomLeading)
    }

    // MARK: - Grid style

    private var gridRows: some View {
        let cellWidth = SheetLayoutMath.gridCellWidth(layout, width: width)
        return ForEach(rowRanges.indices, id: \.self) { index in
            HStack(alignment: .top, spacing: spacing) {
                ForEach(sheet.photos[rowRanges[index]]) { photo in
                    gridCell(photo, cellWidth: cellWidth)
                }
            }
        }
    }

    private func gridCell(_ photo: SheetPhoto, cellWidth: Double) -> some View {
        VStack(spacing: cellWidth * SheetLayoutMath.gridLabelGapRatio) {
            photoView(
                photo,
                cellWidth: cellWidth,
                height: SheetLayoutMath.gridPhotoHeight(photo, layout: layout, cellWidth: cellWidth)
            )
            .dropTargetOverlay(show: dropTargetId == photo.id)
            .photoInteraction(photo, onTap: onTapPhoto, onMove: onMovePhoto) { id, targeted in
                withAnimation(.easeInOut(duration: 0.15)) { dropTargetId = targeted ? id : nil }
            }
            if layout.showFilename {
                Text(photo.fileName)
                    .font(.system(size: cellWidth * 0.08, design: .monospaced))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .frame(height: cellWidth * SheetLayoutMath.gridLabelTextRatio)
            }
        }
        .frame(width: cellWidth, alignment: .top)
    }

    // MARK: - Film strip style

    private var filmRows: some View {
        let frameWidth = SheetLayoutMath.filmFrameWidth(layout, width: width)
        let contentWidth = SheetLayoutMath.contentWidth(layout, width: width)
        let separator = SheetLayoutMath.filmSeparator(layout, width: width)
        return ForEach(rowRanges.indices, id: \.self) { index in
            FilmStripRow(
                photos: Array(sheet.photos[rowRanges[index]]),
                startNumber: rowRanges[index].lowerBound + 1,
                columns: layout.columns,
                frameWidth: frameWidth,
                contentWidth: contentWidth,
                separator: separator,
                format: layout.filmFormat,
                edgeText: layout.filmEdgeText,
                adjustments: layout.adjustments,
                imageCache: imageCache,
                onTapPhoto: onTapPhoto,
                onMovePhoto: onMovePhoto,
                dropTargetId: dropTargetId,
                onDropTargeted: { id, targeted in
                    withAnimation(.easeInOut(duration: 0.15)) { dropTargetId = targeted ? id : nil }
                }
            )
        }
    }

    // MARK: - Shared

    private func photoView(_ photo: SheetPhoto, cellWidth: Double, height: Double) -> some View {
        Group {
            if let image = imageCache.image(for: photo, adjustments: layout.adjustments) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.15)
            }
        }
        .frame(width: cellWidth, height: height)
        .clipped()
    }

    /// 背景の明度に応じてラベル色を切り替える
    private var labelColor: Color {
        let color = layout.background.color
        let luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        return luminance > 0.5 ? Color.black.opacity(0.7) : Color.white.opacity(0.8)
    }
}

private extension View {
    /// ハンドラがあるときだけ操作を付ける（書き出し時は素通し）。
    /// タップ = 写真メニュー、長押しドラッグ → 他の写真にドロップ = 並べ替え。
    @ViewBuilder
    func photoInteraction(
        _ photo: SheetPhoto,
        onTap: ((UUID) -> Void)?,
        onMove: ((UUID, UUID) -> Void)?,
        onDropTargeted: ((UUID, Bool) -> Void)? = nil
    ) -> some View {
        if let onTap, let onMove {
            self
                .onTapGesture { onTap(photo.id) }
                .draggable(photo.id.uuidString)
                .dropDestination(for: String.self) { items, _ in
                    guard let first = items.first, let draggedId = UUID(uuidString: first) else {
                        return false
                    }
                    onMove(draggedId, photo.id)
                    return true
                } isTargeted: { targeted in
                    onDropTargeted?(photo.id, targeted)
                }
        } else {
            self
        }
    }

    /// ドロップ先をアクセントカラーでハイライト
    @ViewBuilder
    func dropTargetOverlay(show: Bool) -> some View {
        overlay {
            if show {
                Color.accentColor.opacity(0.25)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 3)
            }
        }
    }
}

/// ベタ焼きの 1 ストリップ（黒いレベート帯 + エッジテキスト + スプロケット穴 + コマ番号）
private struct FilmStripRow: View {
    let photos: [SheetPhoto]
    let startNumber: Int
    let columns: Int
    let frameWidth: Double
    let contentWidth: Double
    let separator: Double
    let format: FilmFormat
    let edgeText: String
    let adjustments: SheetAdjustments
    let imageCache: PhotoImageCache
    let onTapPhoto: ((UUID) -> Void)?
    let onMovePhoto: ((UUID, UUID) -> Void)?
    var dropTargetId: UUID?
    var onDropTargeted: ((UUID, Bool) -> Void)?

    /// フィルムベースの黒（純黒より僅かに浮かせて「焼かれた黒」に寄せる）
    private static let filmBlack = Color(red: 0.043, green: 0.043, blue: 0.05)

    private var frameAspect: Double { format.frameAspect }
    private var frameHeight: Double { frameWidth / frameAspect }
    private var edgeBandHeight: Double { frameWidth * SheetLayoutMath.filmEdgeTextRatio }
    private var sprocketBandHeight: Double { frameWidth * SheetLayoutMath.filmSprocketRatio }

    var body: some View {
        VStack(spacing: 0) {
            edgeTextLine
            // 120 フィルムにはパーフォレーションがない
            if format.hasSprocketHoles {
                sprocketRow
            }
            photoRow
            if format.hasSprocketHoles {
                sprocketRow
            }
            numberLine
        }
        .frame(width: contentWidth)
        .background(Self.filmBlack)
    }

    private var edgeTextLine: some View {
        let repeated = Array(repeating: edgeText, count: max(columns, 1))
            .joined(separator: "        ")
        return Text(repeated)
            .font(.system(size: frameWidth * 0.055, weight: .medium, design: .monospaced))
            .tracking(frameWidth * 0.012)
            .foregroundStyle(.white.opacity(0.55))
            .lineLimit(1)
            .frame(width: contentWidth, height: edgeBandHeight)
            .clipped()
    }

    private var sprocketRow: some View {
        let holeCount = columns * SheetLayoutMath.sprocketHolesPerFrame
        let slotWidth = contentWidth / Double(holeCount)
        return HStack(spacing: 0) {
            ForEach(0..<holeCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: slotWidth * 0.14)
                    .fill(.white.opacity(0.16))
                    .frame(width: slotWidth * 0.45, height: sprocketBandHeight * 0.62)
                    .frame(width: slotWidth, height: sprocketBandHeight)
            }
        }
    }

    private var photoRow: some View {
        HStack(alignment: .top, spacing: separator) {
            ForEach(photos) { photo in
                Group {
                    // フィルムの物理制約: 長辺はストリップ方向。向きが合わない写真は回転して収める
                    let rotate = SheetLayoutMath.filmNeedsRotation(
                        photoAspect: photo.aspectRatio,
                        frameAspect: frameAspect
                    )
                    if let image = imageCache.image(for: photo, adjustments: adjustments, rotatedQuarterTurn: rotate) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.gray.opacity(0.25)
                    }
                }
                .frame(width: frameWidth, height: frameHeight)
                .clipped()
                .dropTargetOverlay(show: dropTargetId == photo.id)
                .photoInteraction(photo, onTap: onTapPhoto, onMove: onMovePhoto, onDropTargeted: onDropTargeted)
            }
            Spacer(minLength: 0)
        }
        .frame(width: contentWidth, height: frameHeight, alignment: .topLeading)
    }

    private var numberLine: some View {
        HStack(alignment: .center, spacing: separator) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { offset, _ in
                let number = startNumber + offset
                HStack {
                    Text("\(number)")
                    Spacer(minLength: 0)
                    // 「8 / 8A」の併記は 35mm の縁刻印。120 は番号のみ
                    if format.usesSecondaryFrameNumber {
                        Text("\(number)A")
                        Spacer(minLength: 0)
                    }
                }
                .font(.system(size: frameWidth * 0.06, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, frameWidth * 0.03)
                .frame(width: frameWidth)
            }
            Spacer(minLength: 0)
        }
        .frame(width: contentWidth, height: edgeBandHeight, alignment: .leading)
    }
}
