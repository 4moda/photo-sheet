import SwiftUI

/// 列数・比率・余白・背景・ラベルの調整パネル
struct ControlsView: View {
    @Bindable var viewModel: SheetEditorViewModel

    var body: some View {
        VStack(spacing: 12) {
            Picker("列数", selection: $viewModel.sheet.layout.columns) {
                ForEach(LayoutConfig.columnPresets, id: \.self) { columns in
                    Text("\(columns)列").tag(columns)
                }
            }
            .pickerStyle(.segmented)

            Picker("比率", selection: $viewModel.sheet.layout.cellAspect) {
                ForEach(CellAspect.allCases, id: \.self) { aspect in
                    Text(aspect.displayName).tag(aspect)
                }
            }
            .pickerStyle(.segmented)

            DisclosureGroup("余白と背景") {
                VStack(spacing: 10) {
                    HStack {
                        Text("外余白")
                            .frame(width: 56, alignment: .leading)
                        Slider(value: $viewModel.sheet.layout.marginRatio, in: 0...0.1)
                    }
                    HStack {
                        Text("間隔")
                            .frame(width: 56, alignment: .leading)
                        Slider(value: $viewModel.sheet.layout.spacingRatio, in: 0...0.05)
                    }
                    HStack(spacing: 12) {
                        Text("背景")
                            .frame(width: 56, alignment: .leading)
                        backgroundButton(.white)
                        backgroundButton(.black)
                        backgroundButton(.paperGray)
                        ColorPicker("カスタム背景色", selection: customColorBinding)
                            .labelsHidden()
                        Spacer()
                    }
                    Toggle("ファイル名を表示", isOn: $viewModel.sheet.layout.showFilename)
                }
                .padding(.top, 8)
            }
            .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.top, 12)
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
