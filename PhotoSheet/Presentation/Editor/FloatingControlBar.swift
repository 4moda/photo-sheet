import SwiftUI

/// 画面下部に浮かぶツールバー。アイコンをタップすると該当する設定パネルだけがバーの上に開く。
/// プレビュー領域を常に最大限確保するためのデザイン。
struct FloatingControlBar: View {
    @Bindable var viewModel: SheetEditorViewModel
    let onAddPhotos: () -> Void

    @State private var selectedTool: Tool?

    enum Tool: String, CaseIterable, Identifiable {
        case style
        case columns
        case aspect
        case paper
        case text
        case appearance

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .style: "film"
            case .columns: "square.grid.3x3"
            case .aspect: "aspectratio"
            case .paper: "rectangle.portrait"
            case .text: "textformat"
            case .appearance: "paintpalette"
            }
        }

        var title: String {
            switch self {
            case .style: "スタイル"
            case .columns: "列数"
            case .aspect: "セル比率"
            case .paper: "用紙"
            case .text: "タイトル"
            case .appearance: "余白と背景"
            }
        }
    }

    /// フィルムモードではセル比率（3:2 固定）を出さない
    private var visibleTools: [Tool] {
        Tool.allCases.filter { tool in
            tool != .aspect || viewModel.sheet.layout.style == .grid
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            if let tool = selectedTool {
                toolPanel(tool)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            bar
        }
        .animation(.snappy(duration: 0.2), value: selectedTool)
    }

    // MARK: - Bar

    private var bar: some View {
        HStack(spacing: 4) {
            barButton(icon: "plus", accessibilityLabel: "写真を追加") {
                selectedTool = nil
                onAddPhotos()
            }

            barDivider

            ForEach(visibleTools) { tool in
                toolButton(tool)
            }

            barDivider

            barButton(icon: "square.and.arrow.down", accessibilityLabel: "写真に保存") {
                selectedTool = nil
                viewModel.saveToPhotoLibrary()
            }
            barButton(icon: "square.and.arrow.up", accessibilityLabel: "共有") {
                selectedTool = nil
                viewModel.presentShareSheet()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .disabled(viewModel.isExporting)
    }

    private var barDivider: some View {
        Divider().frame(height: 22)
    }

    private func toolButton(_ tool: Tool) -> some View {
        let isSelected = selectedTool == tool
        return barButton(
            icon: tool.icon,
            accessibilityLabel: tool.title,
            isHighlighted: isSelected
        ) {
            selectedTool = isSelected ? nil : tool
        }
    }

    private func barButton(
        icon: String,
        accessibilityLabel: String,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(isHighlighted ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Panels

    private func toolPanel(_ tool: Tool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tool.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            panelContent(tool)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }

    @ViewBuilder
    private func panelContent(_ tool: Tool) -> some View {
        switch tool {
        case .style:
            Picker("スタイル", selection: $viewModel.sheet.layout.style) {
                ForEach(SheetStyle.allCases, id: \.self) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)

        case .columns:
            Picker("列数", selection: $viewModel.sheet.layout.columns) {
                ForEach(LayoutConfig.columnPresets, id: \.self) { columns in
                    Text("\(columns)").tag(columns)
                }
            }
            .pickerStyle(.segmented)

        case .aspect:
            Picker("セル比率", selection: $viewModel.sheet.layout.cellAspect) {
                ForEach(CellAspect.allCases, id: \.self) { aspect in
                    Text(aspect.displayName).tag(aspect)
                }
            }
            .pickerStyle(.segmented)

        case .paper:
            Picker("用紙", selection: $viewModel.sheet.layout.paperFormat) {
                ForEach(PaperFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)

        case .text:
            TextField("タイトル", text: $viewModel.sheet.title)
                .textFieldStyle(.roundedBorder)
            TextField("サブタイトル（日付・ロール番号など）", text: $viewModel.sheet.caption)
                .textFieldStyle(.roundedBorder)

        case .appearance:
            HStack {
                Text("外余白")
                    .font(.subheadline)
                    .frame(width: 52, alignment: .leading)
                Slider(value: $viewModel.sheet.layout.marginRatio, in: 0...0.1)
            }
            HStack {
                Text("間隔")
                    .font(.subheadline)
                    .frame(width: 52, alignment: .leading)
                Slider(value: $viewModel.sheet.layout.spacingRatio, in: 0...0.05)
            }
            HStack(spacing: 12) {
                Text("背景")
                    .font(.subheadline)
                    .frame(width: 52, alignment: .leading)
                backgroundButton(.white)
                backgroundButton(.black)
                backgroundButton(.paperGray)
                ColorPicker("カスタム背景色", selection: customColorBinding)
                    .labelsHidden()
                Spacer()
            }
            if viewModel.sheet.layout.style == .grid {
                Toggle("ファイル名を表示", isOn: $viewModel.sheet.layout.showFilename)
                    .font(.subheadline)
            }
        }
    }

    private func backgroundButton(_ background: SheetBackground) -> some View {
        let isSelected = viewModel.sheet.layout.background == background
        return Button {
            viewModel.sheet.layout.background = background
        } label: {
            Circle()
                .fill(Color(rgba: background.color))
                .frame(width: 28, height: 28)
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? Color.accentColor : Color.gray.opacity(0.4),
                        lineWidth: isSelected ? 2 : 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { Color(rgba: viewModel.sheet.layout.background.color) },
            set: { viewModel.sheet.layout.background = .custom(RGBAColor(color: $0)) }
        )
    }
}
