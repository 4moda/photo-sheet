/// 写真からシートを構築する。レイアウト設定・タイトル・キャプションは現在のシートから引き継ぐ。
/// 列数はユーザー設定（デフォルト 6 列）をそのまま維持する。
struct BuildSheetUseCase {
    func callAsFunction(
        photos: [SheetPhoto],
        basedOn current: Sheet = Sheet(photos: [], layout: .default)
    ) -> Sheet {
        var sheet = current
        sheet.photos = photos
        return sheet
    }
}
