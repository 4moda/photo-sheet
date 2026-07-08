/// 写真からシートを構築する。列数は枚数に応じたデフォルトを適用し、
/// レイアウト設定・タイトル・キャプションは現在のシートから引き継ぐ。
struct BuildSheetUseCase {
    func callAsFunction(
        photos: [SheetPhoto],
        basedOn current: Sheet = Sheet(photos: [], layout: .default)
    ) -> Sheet {
        var sheet = current
        sheet.photos = photos
        sheet.layout.columns = LayoutConfig.defaultColumns(forPhotoCount: photos.count)
        return sheet
    }
}
