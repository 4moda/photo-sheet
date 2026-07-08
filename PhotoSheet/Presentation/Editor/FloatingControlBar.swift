import SwiftUI

/// 画面下部に浮かぶツールバー。アイコンをタップすると該当する設定パネルだけがバーの上に開く。
/// 項目は意味ごとに 3 グループ（見た目 / 用紙 / タイトル）+ 保存・共有の計 5 個に抑える。
struct FloatingControlBar: View {
    @Bindable var viewModel: SheetEditorViewModel

    @State private var selectedTool: Tool?

    enum Tool: String, CaseIterable, Identifiable {
        /// スタイル・列数・セル比率・ファイル名
        case appearance
        /// 用紙フォーマット・余白・背景
        case paper
        /// タイトル・サブタイトル
        case text
        /// スクロール動画の書き出し設定
        case video

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .appearance: "square.grid.3x3"
            case .paper: "rectangle.portrait"
            case .text: "textformat"
            case .video: "film.stack"
            }
        }

        var title: String {
            switch self {
            case .appearance: "見た目"
            case .paper: "用紙"
            case .text: "タイトル"
            case .video: "動画"
            }
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
            ForEach(Tool.allCases) { tool in
                toolButton(tool)
            }

            Divider().frame(height: 22)

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
                .frame(width: 40, height: 40)
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
        case .appearance:
            appearancePanel
        case .paper:
            paperPanel
        case .text:
            TextField("タイトル", text: $viewModel.sheet.title)
                .textFieldStyle(.roundedBorder)
            TextField("サブタイトル（日付・ロール番号など）", text: $viewModel.sheet.caption)
                .textFieldStyle(.roundedBorder)
        case .video:
            videoPanel
        }
    }

    @ViewBuilder
    private var appearancePanel: some View {
        Picker("スタイル", selection: $viewModel.sheet.layout.style) {
            ForEach(SheetStyle.allCases, id: \.self) { style in
                Text(style.displayName).tag(style)
            }
        }
        .pickerStyle(.segmented)

        labeledRow("列数") {
            Picker("列数", selection: $viewModel.sheet.layout.columns) {
                ForEach(LayoutConfig.columnPresets, id: \.self) { columns in
                    Text("\(columns)").tag(columns)
                }
            }
            .pickerStyle(.segmented)
        }

        // スタイル切替でパネルの高さが変わってバーが上下しないよう、
        // 両バリアントを重ねて常に最大高さを確保する
        ZStack(alignment: .topLeading) {
            gridOnlyOptions
                .opacity(isGridStyle ? 1 : 0)
                .allowsHitTesting(isGridStyle)
            filmOnlyOptions
                .opacity(isGridStyle ? 0 : 1)
                .allowsHitTesting(!isGridStyle)
        }
    }

    private var isGridStyle: Bool {
        viewModel.sheet.layout.style == .grid
    }

    private var gridOnlyOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledRow("比率") {
                Picker("セル比率", selection: $viewModel.sheet.layout.cellAspect) {
                    ForEach(CellAspect.allCases, id: \.self) { aspect in
                        Text(aspect.displayName).tag(aspect)
                    }
                }
                .pickerStyle(.segmented)
            }
            Toggle("ファイル名を表示", isOn: $viewModel.sheet.layout.showFilename)
                .font(.subheadline)
        }
    }

    private var filmOnlyOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledRow("フィルム") {
                Picker("フィルム", selection: $viewModel.sheet.layout.filmFormat) {
                    ForEach(FilmFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            }
            labeledRow("縁の文字") {
                TextField("エッジテキスト", text: $viewModel.sheet.layout.filmEdgeText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
        }
    }

    @ViewBuilder
    private var paperPanel: some View {
        Picker("用紙", selection: $viewModel.sheet.layout.paperFormat) {
            ForEach(PaperFormat.allCases, id: \.self) { format in
                Text(format.displayName).tag(format)
            }
        }
        .pickerStyle(.segmented)

        labeledRow("外余白") {
            Slider(value: $viewModel.sheet.layout.marginRatio, in: 0...0.1)
        }
        labeledRow("間隔") {
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
    }

    private func labeledRow(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 52, alignment: .leading)
            content()
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

    // MARK: - 動画パネル

    @ViewBuilder
    private var videoPanel: some View {
        // 方向選択
        labeledRow("方向") {
            HStack(spacing: 6) {
                ForEach(VideoExportConfig.ScrollDirection.allCases, id: \.self) { dir in
                    let isSelected = viewModel.videoConfig.direction == dir
                    Button {
                        viewModel.videoConfig.direction = dir
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: dir.icon)
                                .font(.system(size: 14))
                            Text(dir.displayName)
                                .font(.caption2)
                        }
                        .frame(width: 52, height: 40)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }

        // 動画の長さ
        labeledRow("長さ") {
            Picker("動画の長さ", selection: $viewModel.videoConfig.durationSeconds) {
                ForEach(VideoExportConfig.durationPresets, id: \.self) { secs in
                    Text("\(Int(secs))秒").tag(secs)
                }
            }
            .pickerStyle(.segmented)
        }

        // 操作ボタン
        HStack(spacing: 12) {
            Button {
                viewModel.saveVideoToPhotoLibrary()
            } label: {
                Label("動画を保存", systemImage: "square.and.arrow.down")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isExporting || viewModel.sheet.photos.isEmpty)

            Button {
                viewModel.presentVideoShareSheet()
            } label: {
                Label("共有", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isExporting || viewModel.sheet.photos.isEmpty)

            if viewModel.isExporting {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}
