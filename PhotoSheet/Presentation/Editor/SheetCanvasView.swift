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
                .background(backgroundFill)
        }
    }

    /// 用紙比率固定: 内容が収まらない場合は相似形のまま縮小して収める
    private func fixedPaperBody(ratio: Double) -> some View {
        let outerHeight = width / ratio
        let naturalHeight = SheetLayoutMath.naturalHeight(sheet: sheet, width: width)
        let scale = naturalHeight > 0 ? min(1, outerHeight / naturalHeight) : 1
        return ZStack(alignment: .top) {
            backgroundFill
            sheetContent
                .scaleEffect(scale, anchor: .top)
        }
        .frame(width: width, height: outerHeight)
        .clipped()
    }

    /// 背景の描画。ライトテーブルは発光ビュアー風のグラデーション、
    /// バライタは温白 + ごく薄い周辺減光、それ以外はフラットな単色
    @ViewBuilder
    private var backgroundFill: some View {
        switch layout.background {
        case .lightTable:
            RadialGradient(
                colors: [
                    Color(red: 0.995, green: 0.99, blue: 0.965),
                    Color(red: 0.88, green: 0.875, blue: 0.845)
                ],
                center: .center,
                startRadius: 0,
                endRadius: width * 0.9
            )
        case .baryta:
            Color(rgba: layout.background.color)
                .overlay(
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.05)],
                        center: .center,
                        startRadius: width * 0.35,
                        endRadius: width * 1.0
                    )
                )
        default:
            Color(rgba: layout.background.color)
        }
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
            case .negativeSleeve:
                sleeveRows
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
            .dateStampOverlay(
                date: layout.showDateStamp ? photo.captureDate : nil,
                cellWidth: cellWidth
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
        let leader = SheetLayoutMath.filmLeader(layout, width: width)
        return ForEach(rowRanges.indices, id: \.self) { index in
            FilmStripRow(
                photos: Array(sheet.photos[rowRanges[index]]),
                startNumber: rowRanges[index].lowerBound + 1,
                columns: layout.columns,
                frameWidth: frameWidth,
                contentWidth: contentWidth,
                separator: separator,
                leader: leader,
                format: layout.filmFormat,
                edgeText: layout.filmEdgeText,
                edgeShowsFrameNumbers: layout.filmEdgeShowsFrameNumbers,
                showDateStamp: layout.showDateStamp,
                lightTable: layout.background == .lightTable,
                adjustments: layout.adjustments,
                imageCache: imageCache,
                onTapPhoto: onTapPhoto,
                onMovePhoto: onMovePhoto,
                dropTargetId: dropTargetId,
                onDropTargeted: { id, targeted in
                    withAnimation(.easeInOut(duration: 0.15)) { dropTargetId = targeted ? id : nil }
                }
            )
            // 手貼り感: ストリップは手で並べるため、行ごとに僅かに揃わない（決定論的乱数）
            .rotationEffect(
                .degrees(SheetLayoutMath.stripLayRotationDegrees(row: index)),
                anchor: .center
            )
            .offset(x: width * SheetLayoutMath.stripLayOffsetRatio(row: index))
        }
    }

    // MARK: - Negative sleeve style

    /// ネガファイル: バインダー穴の余白列 + フィルムストリップ入りポケットの段組み
    private var sleeveRows: some View {
        let frameWidth = SheetLayoutMath.sleeveFrameWidth(layout, width: width)
        let stripWidth = SheetLayoutMath.sleeveContentWidth(layout, width: width)
        let punchMargin = SheetLayoutMath.sleevePunchMargin(layout, width: width)
        let separator = SheetLayoutMath.filmSeparator(layout, width: width)
        let leader = SheetLayoutMath.filmLeader(layout, width: width)
        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(rowRanges.indices, id: \.self) { index in
                NegativeSleeveRow(
                    photos: Array(sheet.photos[rowRanges[index]]),
                    startNumber: rowRanges[index].lowerBound + 1,
                    columns: layout.columns,
                    frameWidth: frameWidth,
                    stripWidth: stripWidth,
                    separator: separator,
                    leader: leader,
                    format: layout.filmFormat,
                    edgeText: layout.filmEdgeText,
                    edgeShowsFrameNumbers: layout.filmEdgeShowsFrameNumbers,
                    showDateStamp: layout.showDateStamp,
                    lightTable: layout.background == .lightTable,
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
        .padding(.leading, punchMargin)
        .overlay(alignment: .leading) {
            punchHoleColumn(width: punchMargin)
        }
    }

    /// バインダーのパンチ穴（1/3・2/3 の位置に 2 個）
    private func punchHoleColumn(width punchWidth: Double) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            punchHole(diameter: punchWidth * 0.5)
            Spacer(minLength: 0)
            punchHole(diameter: punchWidth * 0.5)
            Spacer(minLength: 0)
        }
        .frame(width: punchWidth)
        .allowsHitTesting(false)
    }

    private func punchHole(diameter: Double) -> some View {
        Circle()
            .fill(Color.black.opacity(0.10))
            .overlay(Circle().strokeBorder(Color.black.opacity(0.14), lineWidth: 0.8))
            .frame(width: diameter, height: diameter)
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
    /// ストリップ端の切り残し余白（カットの痕跡）
    let leader: Double
    let format: FilmFormat
    let edgeText: String
    let edgeShowsFrameNumbers: Bool
    let showDateStamp: Bool
    /// 背景がライトテーブルのとき true。刻印がアンバー発光・スプロケットが光の抜けになる
    let lightTable: Bool
    let adjustments: SheetAdjustments
    let imageCache: PhotoImageCache
    let onTapPhoto: ((UUID) -> Void)?
    let onMovePhoto: ((UUID, UUID) -> Void)?
    var dropTargetId: UUID?
    var onDropTargeted: ((UUID, Bool) -> Void)?

    /// フィルムベースの黒。現像済みフィルムのベースは青ではなく**温かい暗グレー**
    /// （純黒より僅かに浮かせて「焼かれた黒」に寄せる）
    private static let filmBlack = Color(red: 0.055, green: 0.048, blue: 0.042)
    /// エッジ刻印の色。プリント上の刻印は紙白なので、純白でなく僅かに黄味の温白
    private static let edgeInk = Color(red: 0.97, green: 0.94, blue: 0.86)
    /// ライトテーブル時の刻印色。黒いベースの透明文字を光が透けるアンバー発光
    private static let amberInk = Color(red: 1.0, green: 0.72, blue: 0.32)

    private var ink: Color { lightTable ? Self.amberInk : Self.edgeInk }
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
        // コマ番号併記（▸12）は実物のフィルム縁刻印に倣ったオプション
        let segments = (0..<max(columns, 1)).map { offset in
            edgeShowsFrameNumbers ? "\(edgeText)  ▸\(startNumber + offset)" : edgeText
        }
        let repeated = segments.joined(separator: "        ")
        return Text(repeated)
            .font(.system(size: frameWidth * 0.055, weight: .medium, design: .monospaced))
            .tracking(frameWidth * 0.012)
            .foregroundStyle(ink.opacity(lightTable ? 0.95 : 0.6))
            .shadow(color: lightTable ? Self.amberInk.opacity(0.8) : .clear, radius: frameWidth * 0.012)
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
                    // プリントでは穴は光の素通し = レベートよりさらに黒く写る。
                    // ライトテーブルでは逆に、穴を光が抜けて明るく光る
                    .fill(lightTable
                        ? Color(red: 1.0, green: 0.93, blue: 0.80).opacity(0.95)
                        : Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: slotWidth * 0.14)
                            .strokeBorder(Self.edgeInk.opacity(lightTable ? 0 : 0.12), lineWidth: 0.5)
                    )
                    .shadow(
                        color: lightTable ? Self.amberInk.opacity(0.7) : .clear,
                        radius: slotWidth * 0.18
                    )
                    .frame(width: slotWidth * 0.45, height: sprocketBandHeight * 0.62)
                    .frame(width: slotWidth, height: sprocketBandHeight)
            }
        }
    }

    private var photoRow: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                frameView(photo, number: startNumber + offset)
                if offset < photos.count - 1 {
                    Color.clear.frame(
                        width: SheetLayoutMath.filmGapWidth(
                            afterFrame: offset, format: format, separator: separator
                        )
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, leader)
        .frame(width: contentWidth, height: frameHeight, alignment: .topLeading)
    }

    private func frameView(_ photo: SheetPhoto, number: Int) -> some View {
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
        .overlay(unevennessOverlay(number: number))
        .dateStampOverlay(
            date: showDateStamp ? photo.captureDate : nil,
            cellWidth: frameWidth
        )
        .dropTargetOverlay(show: dropTargetId == photo.id)
        .photoInteraction(photo, onTap: onTapPhoto, onMove: onMovePhoto, onDropTargeted: onDropTargeted)
    }

    /// 露光ムラ: ラボ焼きの僅かな明度差（±2%、コマ番号キーの決定論ノイズ）
    private func unevennessOverlay(number: Int) -> some View {
        let delta = (SheetLayoutMath.stripLayNoise(row: number, salt: 0xE4_B05E) - 0.5) * 0.04
        return (delta >= 0 ? Color.white.opacity(delta) : Color.black.opacity(-delta))
            .allowsHitTesting(false)
    }

    private var numberLine: some View {
        HStack(alignment: .center, spacing: 0) {
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
                .foregroundStyle(ink.opacity(lightTable ? 0.95 : 0.75))
                .shadow(color: lightTable ? Self.amberInk.opacity(0.8) : .clear, radius: frameWidth * 0.01)
                .padding(.horizontal, frameWidth * 0.03)
                .frame(width: frameWidth)
                if offset < photos.count - 1 {
                    Color.clear.frame(
                        width: SheetLayoutMath.filmGapWidth(
                            afterFrame: offset, format: format, separator: separator
                        )
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, leader)
        .frame(width: contentWidth, height: edgeBandHeight, alignment: .leading)
    }
}

/// ネガシート（スリーブ）の 1 段。実物どおり「切ったフィルムストリップ」が
/// 半透明ポケットに収まっているように、FilmStripRow をそのまま中身にする。
private struct NegativeSleeveRow: View {
    let photos: [SheetPhoto]
    let startNumber: Int
    let columns: Int
    let frameWidth: Double
    /// スリーブ内でストリップが使える幅（バインダー穴余白を除いたもの）
    let stripWidth: Double
    let separator: Double
    let leader: Double
    let format: FilmFormat
    let edgeText: String
    let edgeShowsFrameNumbers: Bool
    let showDateStamp: Bool
    let lightTable: Bool
    let adjustments: SheetAdjustments
    let imageCache: PhotoImageCache
    let onTapPhoto: ((UUID) -> Void)?
    let onMovePhoto: ((UUID, UUID) -> Void)?
    var dropTargetId: UUID?
    var onDropTargeted: ((UUID, Bool) -> Void)?

    private var padding: Double { frameWidth * SheetLayoutMath.sleevePaddingRatio }

    var body: some View {
        FilmStripRow(
            photos: photos,
            startNumber: startNumber,
            columns: columns,
            frameWidth: frameWidth,
            contentWidth: stripWidth,
            separator: separator,
            leader: leader,
            format: format,
            edgeText: edgeText,
            edgeShowsFrameNumbers: edgeShowsFrameNumbers,
            showDateStamp: showDateStamp,
            lightTable: lightTable,
            adjustments: adjustments,
            imageCache: imageCache,
            onTapPhoto: onTapPhoto,
            onMovePhoto: onMovePhoto,
            dropTargetId: dropTargetId,
            onDropTargeted: onDropTargeted
        )
        // 半透明スリーブ越しに見えるミルキーな膜（操作は透過させる）
        .overlay(Color.white.opacity(0.14).allowsHitTesting(false))
        .padding(.vertical, padding)
        .background(
            // 半透明ポケット: フロスト面・上下の溶着シーム・下端の影で立体感を出す
            ZStack {
                Color.white.opacity(0.5)
                VStack(spacing: 0) {
                    Rectangle().fill(Color.white.opacity(0.95)).frame(height: 2)
                    Spacer(minLength: 0)
                    Rectangle().fill(Color.black.opacity(0.07)).frame(height: 1.5)
                    Rectangle().fill(Color.white.opacity(0.95)).frame(height: 2)
                }
            }
        )
    }
}

private extension View {
    /// クォーツデート風のオレンジ日付をコマ右下に焼き込む（date が nil なら何もしない）
    @ViewBuilder
    func dateStampOverlay(date: Date?, cellWidth: Double) -> some View {
        if let date {
            let stampColor = Color(red: 1.0, green: 0.58, blue: 0.20)
            overlay(alignment: .bottomTrailing) {
                Text(DateStamp.text(for: date))
                    .font(.system(size: cellWidth * 0.062, weight: .semibold, design: .monospaced))
                    .foregroundStyle(stampColor.opacity(0.92))
                    .shadow(color: stampColor.opacity(0.85), radius: cellWidth * 0.006)
                    .padding([.bottom, .trailing], cellWidth * 0.045)
                    .allowsHitTesting(false)
            }
        } else {
            self
        }
    }
}
