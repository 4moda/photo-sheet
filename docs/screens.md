# 画面・状態・操作カタログ

PhotoSheet の全画面について、**画面の状態**と**操作のバリエーション**を列挙する。
各画面に**画面ID**（`S01`…）、各機能に**機能ID**（`F01`…）を振り、CI が撮影する
スクリーンショットと 1:1 で対応づける。実機を動かさずに、CI が撮る画像と本書だけで
「どの画面のどの操作がどう見えるか」を追えるようにするのが目的（photo-layout と同じ運用）。

## スクリーンショットの命名規約と紐づけ

スクショ名（`PhotoSheetUITests/ScreenshotSmokeTests.swift` の `snapshot(...)`）は:

```
<画面ID>[-<機能ID>]-action-in-english
例: S01-F02-project-list-empty-state
```

fastlane snapshot の出力は `<言語>/<端末slug>--<スナップ名>.png`。
`PhotoSheetUITests/tools/build_screenshot_index.py` がこの規約でファイル名を解析し、
**言語・画面ID・端末で絞り込めて説明文で検索できる `index.html`** を生成する。

> **使う文字**: スナップ名はそのまま PNG ファイル名になるため `A-Z a-z 0-9 -` のみ。

閲覧経路:
- **人間**: Cloudflare Pages（`https://main-latest.photosheet-screenshots.pages.dev`、PR は `https://pr-<番号>.…`）
- **AIエージェント**: CI の `screenshots` artifact を `gh run download -n screenshots` で取得

## 画面一覧

| 画面ID | 画面 | 実装 | 役割 |
|---|---|---|---|
| S01 | プロジェクト一覧 | `ProjectListView` | 作成済みシートのサムネイル一覧・新規作成・削除 |
| S02 | シート編集 | `SheetEditorView` | キャンバス・写真の追加/並べ替え/削除・フローティングバー（見た目/調整/タイトル/書き出し）・書き出し起点 |

凡例: **撮** = CI で自動撮影しているもの（スナップ名を併記）。空欄は現状未撮影（将来追加候補）。

---

## S01 プロジェクト一覧（ProjectListView）

| 機能ID | 状態 / 操作 | 撮 |
|---|---|---|
| F01 | プロジェクトあり（カード: サムネイル・タイトル・更新日・枚数） | 撮 `S01-F01-project-list-populated` |
| F02 | 空状態（「シートがありません」＋新規作成ボタン） | 撮 `S01-F02-project-list-empty-state` |
| F03 | 右上 [+] で新規シート作成 → S02 | （S02-F05 で代替） |
| F04 | カード長押し contextMenu（削除） | |

## S02 シート編集（SheetEditorView + FloatingControlBar + SheetCanvasView）

| 機能ID | 状態 / 操作 | 撮 |
|---|---|---|
| F01 | キャンバス（グリッドスタイル・デモ 12 枚） | 撮 `S02-F01-canvas-grid` |
| F02 | 右上 [+] メニュー（追加 3 経路・撮影順に並べ替え・全削除） | 撮 `S02-F02-add-menu` |
| F03 | 写真タップメニュー（削除 / キャンセル） | 撮 `S02-F03-photo-menu` |
| F05 | 空状態（写真追加の 3 ボタン） | 撮 `S02-F05-editor-empty-state` |
| F10 | 見た目パネル（グリッド: 列数・比率・ファイル名・余白・間隔・背景） | 撮 `S02-F10-appearance-panel-grid` |
| F11 | フィルムスタイル（35mm ストリップ + フィルム設定・エッジテキスト/プリセット・コマ番号刻印） | 撮 `S02-F11-film-style` |
| F12 | スリーブスタイル（ネガシート風ポケット） | 撮 `S02-F12-sleeve-style` |
| F13 | 120 フィルム（6×6。パーフォレーションなし） | 撮 `S02-F13-film-120-square` |
| F20 | 調整パネル（モノクロ・コントラスト・粒状感・フェード・色温度・周辺減光・デート焼き込み） | 撮 `S02-F20-adjust-panel` |
| F21 | モノクロ + デート焼き込み適用後のキャンバス | 撮 `S02-F21-monochrome-datestamp` |
| F30 | タイトルパネル（タイトル・サブタイトル・撮影日自動表示トグル） | 撮 `S02-F30-text-panel` |
| F31 | 撮影日自動キャプション ON（ヘッダーに日付範囲） | 撮 `S02-F31-auto-date-caption` |
| F40 | 書き出しパネル（画像: 用紙・画質（印刷系用紙のみ）・保存/共有） | 撮 `S02-F40-export-image-panel` |
| F41 | 書き出しパネル（動画: 速度・表示行数・全体表示） | 撮 `S02-F41-export-video-panel` |
| F50 | 長押しドラッグ並べ替え（ドロップ先ハイライト） | （ドラッグ中 UI は XCUITest で安定撮影できないため未撮影） |
| F51 | 書き出し中の進捗オーバーレイ | |

## 撮影の前提（決定論）

- `--uitest` 起動引数: プロジェクト保存先を一時ディレクトリへ切替（毎回まっさら）
- `--seed-demo` 起動引数: 生成画像 12 枚のデモシート「DEMO ROLL」を投入
  （前半 8 枚は撮影日あり・後半 4 枚は EXIF なしスキャン相当。`UITestSeeder` 参照）
