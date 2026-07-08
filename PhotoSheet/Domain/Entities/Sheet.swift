/// 1 つの作品（コンタクトシート）
struct Sheet: Equatable {
    var photos: [SheetPhoto]
    var layout: LayoutConfig
    /// シート上部に表示するタイトル（空なら非表示）
    var title: String = ""
    /// タイトル右側に表示するサブテキスト（日付・ロール番号など。空なら非表示）
    var caption: String = ""
}
