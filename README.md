# Photo Sheet

写真を一覧で魅せ、一つの作品として残す iOS アプリ。

フィルム写真のコンタクトシート（ベタ焼き）やインデックスプリントのように、撮影した写真を一覧で眺め、選び、楽しむ文化を、フィルム・デジタルのどちらにも広げて現代的に再解釈します。写真は一枚ずつ鑑賞するだけでなく、複数枚が並ぶことで、その日やその場所の空気、撮影者の視点やストーリーが見えてきます。

## 機能（MVP）

- **プロジェクト一覧**が最上位画面。作成したシートはローカルに自動保存（閉じるときに保存、サムネイル付き）
- 写真の取り込み: フォトライブラリ / フォルダ / ZIP ファイル
- 2 つのスタイル:
  - **グリッド**（インデックスプリント風）: 均等グリッド、セル比率（元の比率 / 3:2 / 1:1）、ファイル名ラベル
  - **フィルムストリップ**（ベタ焼き風）: 黒いレベート帯・スプロケット穴・エッジテキスト・`1 | 1A` 形式のコマ番号
    - フィルム形式: **35mm**（3:2 横コマ）/ **ハーフ**（3:4 縦コマ）
    - 実物と同じく長辺がストリップ方向を向くよう、向きの合わない写真は自動で 90 度回転
- 列数プリセット 2/3/4/6（デフォルトは 6 列 = 35mm ベタ焼きの伝統）
- シートヘッダー（タイトル + 日付/ロール番号）
- 用紙フォーマット: 自由 / 8×10 / 4×6 / A4 / 9:16（固定比率は内容を相似形のまま収める）
- 仕上げ: 外余白・セル間隔・背景色
- 写真の追加取り込み（既存のシートに追加）・長押しで個別削除
- 書き出し: 高解像度 PNG をカメラロールへ保存、共有シートでシェア
  - SNS 想定で幅 2160px（Instagram 1080 の 2 倍）、印刷系用紙（8×10/4×6/A4）選択時は幅 2400px（8×10 で 300dpi 相当）

## アーキテクチャ

Clean Architecture（依存方向は内向き: Presentation → Domain ← Data）。

```
PhotoSheet/
  App/           # Composition Root（DI の組み立て）
  Domain/        # Entities / Repositories(protocol) / UseCases — フレームワーク非依存
  Data/          # 取り込み・レンダリング・保存の実装（PhotosUI, ImageIO, ZIPFoundation, Photos）
  Presentation/  # SwiftUI + MVVM（@Observable ViewModel）
PhotoSheetTests/ # Domain の単体テスト
```

プレビューと書き出しは同じ `SheetCanvasView` を使う WYSIWYG 設計。レイアウト値（余白・間隔）はシート幅に対する比率で持つため、どの解像度で描画しても相似形になります。

### 将来拡張のための設計ノート

- **すべての座標・寸法は Domain の `SheetLayoutMath`（純関数）が決める。** 将来のスクロール/スライド動画書き出しは「同じレイアウト計算のまま、表示オフセットを変えながらフレームを連続レンダリングする」ことで実現する（描画コードの複製は作らない）。
- **`FilmStripRow` は列数・コマ幅が引数**なので、横スクロールする 1 本の長いフィルム（列数 = 全枚数）にもそのまま流用できる。
- **永続化は `SheetProjectRepository` プロトコルの背後**（現在はファイルベース）。iCloud 同期などへの差し替えは Data 層の実装追加のみで済む。

## 開発

Xcode プロジェクトは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で生成します（`.xcodeproj` はコミットしません）。

```sh
# Mac 上で
brew install xcodegen
xcodegen generate
open PhotoSheet.xcodeproj
```

このリポジトリの開発は WSL2（Linux）上で行っており、ビルド・テストは GitHub Actions（macOS ランナー）で実行します。

## CI

GitHub Actions（`.github/workflows/ci.yml`）で PR / push ごとに実行:

1. SwiftLint による静的解析
2. `xcodebuild test`（iOS シミュレータ / Domain 単体テスト）— ビルド含む

## 将来のアイディア

- 多様なレイアウトやテンプレート
- 印刷を前提とした作品づくり
- 完成した作品をゆっくりスクロールするシンプルな動画として書き出す機能
- Instagram Story への直接共有（Meta App ID 取得後に有効化）
