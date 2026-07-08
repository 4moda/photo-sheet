# Photo Sheet

写真を一覧で魅せ、一つの作品として残す iOS アプリ。

フィルム写真のコンタクトシート（ベタ焼き）やインデックスプリントのように、撮影した写真を一覧で眺め、選び、楽しむ文化を、フィルム・デジタルのどちらにも広げて現代的に再解釈します。写真は一枚ずつ鑑賞するだけでなく、複数枚が並ぶことで、その日やその場所の空気、撮影者の視点やストーリーが見えてきます。

## 機能（MVP）

- 写真の取り込み: フォトライブラリ / フォルダ / ZIP ファイル
- 均等グリッドへ自動配置（列数プリセット 2/3/4/6 ＋ 枚数に応じた賢いデフォルト）
- セル比率: 元の比率 / 3:2（ベタ焼き風）/ 1:1
- 仕上げ: 外余白・セル間隔・背景色・ファイル名ラベル
- 書き出し: 高解像度 PNG をカメラロールへ保存、共有シートでシェア

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
