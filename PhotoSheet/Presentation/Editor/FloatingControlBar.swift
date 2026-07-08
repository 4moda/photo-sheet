import SwiftUI

/// 画面下部に浮かぶツールバー。アイコンをタップすると該当する設定パネルだけがバーの上に開く。
/// 項目は 見た目 / タイトル / 書き出し の 3 個。用紙設定は書き出しパネル内に統合。
struct FloatingControlBar: View {
    @Bindable var viewModel: SheetEditorViewModel

    @State private var selectedTool: Tool?
    @State private var exportFormat: ExportFormat = .image

    // MARK: - ツール種別

    enum Tool: String, CaseIterable, Identifiable {
        case appearance
        case text
        case export

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .appearance: "square.grid.3x3"
            case .text: "textformat"
            case .export: "square.and.arrow.up"
            }
        }

        var title: String {
            switch self {
            case .appearance: "見た目"
            case .text: "タイトル"
            case .export: "書き出し"
            }
        }
    }

    /// 書き出しフォーマット（書き出しパネル内で選択）
    private enum ExportFormat { case image, video }

    var body: some View {
        ZStack(alignment: .bottom) {
            // パネルが開いているとき、範囲外タップで閉じる
            if selectedTool != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.snappy(duration: 0.2)) { selectedTool = nil }
                    }
            }
            VStack(spacing: 10) {
                if let tool = selectedTool {
                    toolPanel(tool)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                bar
            }
            .animation(.snappy(duration: 0.2), value: selectedTool)
        }
    }

    // MARK: - Bar

    private var bar: some View {
        HStack(spacing: 4) {
            ForEach(Tool.allCases) { tool in
                toolButton(tool)
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
        case .text:
            TextField("タイトル", text: $viewModel.sheet.title)
                .textFieldStyle(.roundedBorder)
            TextField("サブタイトル（日付・ロール番号など）", text: $viewModel.sheet.caption)
                .textFieldStyle(.roundedBorder)
        case .export:
            exportPanel
        }
    }

    @ViewBuilder
    private var appearancePanel: some View {
        Picker("スタイル", selection: styleSelectionBinding) {
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

        // 余白・間隔・背景色（旧 用紙パネルからここへ統合）
        Divider()
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

    private var isGridStyle: Bool {
        viewModel.sheet.layout.style == .grid
    }

    private var styleSelectionBinding: Binding<SheetStyle> {
        Binding(
            get: { viewModel.sheet.layout.style },
            set: { newStyle in
                let oldStyle = viewModel.sheet.layout.style
                let oldDefault = SheetBackground.recommended(for: oldStyle)
                viewModel.sheet.layout.style = newStyle
                // 背景を手動で変えていない場合のみ、スタイル既定色へ追従させる
                if viewModel.sheet.layout.background == oldDefault {
                    viewModel.sheet.layout.background = SheetBackground.recommended(for: newStyle)
                }
            }
        )
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

    // MARK: - 書き出しパネル

    @ViewBuilder
    private var exportPanel: some View {
        // フォーマット選択
        labeledRow("形式") {
            Picker("形式", selection: $exportFormat) {
                Text("画像").tag(ExportFormat.image)
                Text("動画").tag(ExportFormat.video)
            }
            .pickerStyle(.segmented)
        }

        Divider()

        // 形式別オプション（ZStack で重ねて高さを固定し、切替時にパネルがリサイズしない）
        ZStack(alignment: .topLeading) {
            imageExportOptions
                .opacity(exportFormat == .image ? 1 : 0)
                .allowsHitTesting(exportFormat == .image)
            videoExportOptions
                .opacity(exportFormat == .video ? 1 : 0)
                .allowsHitTesting(exportFormat == .video)
        }

        // 書き出しボタン
        Divider()
        HStack(spacing: 12) {
            Button {
                if exportFormat == .image {
                    viewModel.saveToPhotoLibrary()
                } else {
                    viewModel.saveVideoToPhotoLibrary()
                }
            } label: {
                Label("保存", systemImage: "square.and.arrow.down")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isExporting || viewModel.sheet.photos.isEmpty)

            Button {
                if exportFormat == .image {
                    viewModel.presentShareSheet()
                } else {
                    viewModel.presentVideoShareSheet()
                }
            } label: {
                Label("共有", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isExporting || viewModel.sheet.photos.isEmpty)

            if viewModel.isExporting {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var imageExportOptions: some View {
        labeledRow("用紙") {
            Picker("用紙", selection: $viewModel.sheet.layout.paperFormat) {
                ForEach(PaperFormat.allCases, id: \.self) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var videoExportOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledRow("速度") {
                Picker("速度", selection: $viewModel.videoConfig.speed) {
                    ForEach(VideoExportConfig.Speed.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            labeledRow("表示行数") {
                HStack(spacing: 10) {
                    Button {
                        viewModel.videoConfig.visibleRows = max(1, viewModel.videoConfig.visibleRows - 1)
                    } label: {
                        Image(systemName: "minus.circle").font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.videoConfig.visibleRows <= 1)

                    Text("\(viewModel.videoConfig.visibleRows)行")
                        .frame(minWidth: 36)
                        .monospacedDigit()

                    Button {
                        viewModel.videoConfig.visibleRows = min(8, viewModel.videoConfig.visibleRows + 1)
                    } label: {
                        Image(systemName: "plus.circle").font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.videoConfig.visibleRows >= 8)

                    Spacer()
                }
            }

            labeledRow("全体表示") {
                Toggle("前後に全体表示", isOn: $viewModel.videoConfig.showOverview)
                    .labelsHidden()
            }
        }
    }
}
