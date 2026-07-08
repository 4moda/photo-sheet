# Architecture

## 構成

Clean Architecture（依存方向: Presentation → Domain ← Data）。

```text
PhotoSheet/
  App/           # Composition Root（DI）
  Domain/        # Entities / Repositories(protocol) / UseCases
  Data/          # 実装（Photos, AVFoundation, 永続化など）
  Presentation/  # SwiftUI + MVVM
PhotoSheetTests/
PhotoSheetSnapshotTests/
```

## 不変条件

1. Domain は Foundation 以外に依存しない。
2. `PhotoSheet/Domain`, `PhotoSheet/Data/Persistence`, `PhotoSheetTests` は Linux でコンパイル可能に保つ。
3. レイアウト寸法・座標は `SheetLayoutMath`（Domain の純関数）を唯一のソースにする。
4. 永続化の境界は `SheetProjectRepository`。実装詳細を Presentation に漏らさない。

## WYSIWYG の要点

- 余白・間隔などの値は「幅に対する比率」で保持する。
- プレビュー・画像書き出し・動画書き出しが同じ計算系を共有する。
- 動画のジオメトリ計算は `VideoExportGeometry`（Domain）に集約しており、ローカル Linux テスト可能。

## 書き出し設計（現状）

- 画像: `ExportSheetUseCase` + `SheetRenderer` + `PhotoLibrarySaver`
- 動画: `ExportSheetVideoUseCase` + `SheetVideoRenderer` + `VideoLibrarySaver`
- 動画書き出しは `AVFoundationVideoExporter` が `VideoExportGeometry.FrameSpec` を消費して生成する。
