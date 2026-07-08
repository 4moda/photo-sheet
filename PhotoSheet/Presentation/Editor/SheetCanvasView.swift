import SwiftUI

/// シート本体の描画ビュー。プレビューにも書き出しにも同じものを使う（WYSIWYG）。
/// レイアウト値は幅に対する比率で解釈するため、どの幅で描画しても相似形になる。
struct SheetCanvasView: View {
    let sheet: Sheet
    let width: CGFloat
    let imageCache: PhotoImageCache

    private var layout: LayoutConfig { sheet.layout }
    private var margin: CGFloat { width * layout.marginRatio }
    private var spacing: CGFloat { width * layout.spacingRatio }

    private var cellWidth: CGFloat {
        let columns = CGFloat(layout.columns)
        return (width - margin * 2 - spacing * (columns - 1)) / columns
    }

    private var rows: [[SheetPhoto]] {
        stride(from: 0, to: sheet.photos.count, by: layout.columns).map { start in
            Array(sheet.photos[start..<min(start + layout.columns, sheet.photos.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(rows.indices, id: \.self) { index in
                rowView(rows[index])
            }
        }
        .padding(margin)
        .frame(width: width, alignment: .topLeading)
        .background(Color(rgba: layout.background.color))
    }

    private func rowView(_ row: [SheetPhoto]) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(row) { photo in
                cellView(photo)
            }
        }
    }

    private func cellView(_ photo: SheetPhoto) -> some View {
        VStack(spacing: cellWidth * 0.04) {
            photoView(photo)
            if layout.showFilename {
                Text(photo.fileName)
                    .font(.system(size: cellWidth * 0.08, design: .monospaced))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
            }
        }
        .frame(width: cellWidth, alignment: .top)
    }

    private func photoView(_ photo: SheetPhoto) -> some View {
        Group {
            if let image = imageCache.image(for: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.15)
            }
        }
        .frame(width: cellWidth, height: photoHeight(photo))
        .clipped()
    }

    private func photoHeight(_ photo: SheetPhoto) -> CGFloat {
        switch layout.cellAspect {
        case .film3x2: cellWidth * 2 / 3
        case .square: cellWidth
        case .original: cellWidth / CGFloat(max(photo.aspectRatio, 0.05))
        }
    }

    /// 背景の明度に応じてラベル色を切り替える
    private var labelColor: Color {
        let color = layout.background.color
        let luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        return luminance > 0.5 ? Color.black.opacity(0.7) : Color.white.opacity(0.8)
    }
}
