/// 写真からシートを構築する。列数は枚数に応じたデフォルトを適用し、その他の設定は引き継ぐ。
struct BuildSheetUseCase {
    func callAsFunction(photos: [SheetPhoto], basedOn current: LayoutConfig = .default) -> Sheet {
        var layout = current
        layout.columns = LayoutConfig.defaultColumns(forPhotoCount: photos.count)
        return Sheet(photos: photos, layout: layout)
    }
}
