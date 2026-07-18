# photo-sheet 開発ガイド

写真をコンタクトシート（ベタ焼き）/ インデックスプリント風に並べ、一つの作品として書き出す iOS アプリ。

関連ドキュメント:
- 設計: `docs/architecture.md`
- 開発運用: `docs/development-guide.md`
- 現在の仕様判断: `docs/product-decisions.md`

## 開発環境の前提（最重要）

- このリポジトリは **Mac がなくても開発できる**構成になっている。アプリ全体のビルド・テストは GitHub Actions（macOS ランナー）で行う。Mac がある場合は `xcodegen generate` して Xcode でそのまま開発してもよい。
- **コア層（Domain + Data/Persistence + PhotoSheetTests）は SwiftPM パッケージ `PhotoSheetCore` として Linux/macOS のローカルでビルド・テストできる**。必ず活用すること:

```sh
scripts/test-core.sh          # コアのテストが数秒で回る。コア変更時は必ず実行
```

- Linux で Swift がない場合: swift.org の Linux ツールチェインを展開し、`SWIFT_TOOLCHAIN_DIR` 環境変数で bin ディレクトリを指すか、`~/toolchains/swift-*/usr/bin` に置く（scripts が自動検出する）。
- **「動作確認した」と報告してよいのは、ローカルテスト成功 + CI グリーンを確認した後だけ。** UI の見た目・操作感はシミュレータ/実機でしか確認できないため、断定せず確認手順を提示する。

## 検証ループ（変更 → 確認の手順）

1. コアに触れたら `scripts/test-core.sh`（編集時フックも自動でコンパイルチェックする）
2. **push 前の必須条件**: ① コアテストがグリーン ② UI 層（UIKit/SwiftUI 依存部分）の差分は型・API の自己レビューを済ませる（macOS CI の 1 往復 ≈ 10 分＋課金を無駄にしない）
3. コミット・push → ワークフローが走る:
   - **CI**: SwiftLint / Linux コアテスト / macOS ビルド+テスト+Domain カバレッジゲート(80%) / **スクショ撮影**（fastlane snapshot、`docs/screens.md` の画面ID・機能IDと 1:1）。**docs/Markdown のみの変更では走らない**（paths-ignore）
   - スクショの閲覧: 人間は Cloudflare Pages（main は `main-latest.photosheet-screenshots.pages.dev`、PR は `pr-<番号>.…` + 自動コメント）、AI は `gh run download -n screenshots`。画面を追加・変更したら `PhotoSheetUITests/ScreenshotSmokeTests.swift` と `docs/screens.md` も更新する
   - **Appetize Deploy** / **Device Build**: CI が main で**成功した後にだけ** workflow_run で起動（赤いビルドを配布しないゲート。手動実行も可能）
   - **actionlint**: `.github/workflows/` を変更したときだけワークフロー定義を静的検査
4. CI の監視: `gh run list --limit 3` / `gh run watch <id> --exit-status`
5. 失敗時: `gh run view <id> --log-failed | grep -E "error:" | head -30` → **即 fix-forward**（revert より前進修正を優先）

## アーキテクチャの不変条件

- **Clean Architecture**。依存方向は Presentation → Domain ← Data。Domain は Foundation 以外に依存しない。
- **ポータブルコア規約**: `PhotoSheet/Domain/`, `PhotoSheet/Data/Persistence/`, `PhotoSheetTests/` は **Linux でコンパイル可能に保つ**（Package.swift に含まれる）。UIKit/SwiftUI/Photos に依存するコードとテストをここに置いてはならない。置くと Linux CI が落ちる（それが検知装置）。
- **WYSIWYG 規約**: レイアウトの寸法・座標は**すべて `SheetLayoutMath`（Domain の純関数）から取得**する。View 側に比率や寸法をハードコードしない。プレビュー・書き出し・サムネイル・将来の動画書き出しが同じ計算を共有するための生命線。
- レイアウト値は幅に対する**比率**で持つ（どの解像度でも相似形）。
- 永続化は `SheetProjectRepository` プロトコル経由。実装詳細（ファイル形式）を Presentation に漏らさない。

## UI/UX ポリシー（オーナー確定事項）

- フローティングバーの項目は**最大 6 個**（現在 4 個: 見た目 / 調整 / タイトル / 書き出し）。新しい設定は既存パネルへ収める。
- 列数のデフォルトは**常に 6**（枚数から自動決定しない）。
- 用紙のデフォルトは **8x10**。
- 背景のデフォルトは **grid=白 / filmStrip=黒**（スタイル既定に追従）。
- 写真の追加は**右上ツールバーの [+]**。
- 操作: タップ = 写真メニュー / 長押しドラッグ = 並べ替え（contextMenu と drag は長押しが競合するため併用禁止）。
- UI 文言は日本語。

## Git / CI 規約

- コミット author は**リポジトリローカルの git config に従う**（設定済み）。実名や勤務先メールアドレスをコミット・コード・設定ファイルに入れない。GitHub の noreply メール推奨。
- コミットメッセージは日本語。AI が作成したコミットには `Co-Authored-By` を付ける。
- Private リポジトリでは macOS ランナーの分数消費が 10 倍。push 1 回 ≈ 課金換算 60 分（無料枠 2,000 分/月）。**細かい push を連発せず、変更をまとめてから push**。

## スナップショットテスト（キャンバス描画の回帰検知）

`PhotoSheetSnapshotTests/SheetCanvasViewSnapshotTests.swift` が `SheetCanvasView` の描画を画像として記録し、CI で自動比較する。

**規約**: スナップショットテストは**可変な `LayoutConfig.default` にレイアウトを依存させない**。テストで検証したい設定（用紙・列数など）は明示的に固定する（`baseLayout()` は用紙を `.flexible` に固定している）。デフォルト値を変えただけで全参照画像が壊れるのを防ぐため。用紙固定モードの検証は専用テスト（`testGrid_fixedPaper_8x10`）で行う。

### 参照画像を初回生成 / 更新する手順

1. **GitHub Actions > Update Snapshots > Run workflow** を対象ブランチを選んで手動実行（`workflow_dispatch`）
2. ワークフローが記録した参照画像を `PhotoSheetSnapshotTests/__Snapshots__/SheetCanvasViewSnapshotTests/` へ**自身でコミット・push**する（差分がなければ何もしない）。人間による artifact のダウンロード・展開・コミットは不要（次の CI からは比較モードで動く）
3. 実行結果は artifact `snapshot-images` としても残るため、確認・監査に使える

### レイアウトを意図的に変えたとき

CI の `Build & Test` が snapshot failure で落ちる → 上記のワークフローを実行すれば参照画像の更新・反映まで完了する。

### ローカル（Mac + Xcode）で確認したいとき

Xcode のスキームに環境変数 `RECORD_SNAPSHOTS = true` を追加して実行 → `__Snapshots__/` に画像が生成される。

## Definition of Done（タスク完了の条件）

- [ ] コア変更なら `scripts/test-core.sh` がローカルで成功
- [ ] 新しいロジックにはテストを追加（Domain カバレッジ 80% ゲートあり）
- [ ] push 後、CI グリーンを確認（Appetize / Device Build は CI 成功後に自動起動。docs のみの変更なら CI はスキップされる）
- [ ] UI 変更なら Appetize/実機での確認ポイントを具体的に提示
- [ ] 規約・構成に影響する変更（規約・構成）は同じコミットで CLAUDE.md / README を更新

## 開発ワークフロー（trunk ベース。photo-layout と同じ運用）

- **動く段階まで仕上げて main へ直接コミット**する（Issue/PR 単位の開発は廃止。大きな設計変更の相談には Issue を使ってもよい）
- push 前の必須条件は「検証ループ」の通り: コアテストグリーン + UI 層差分の型・API 自己レビュー
- push 後は CI を監視し、赤くなったら**即 fix-forward**（revert より前進修正を優先）
- 仕様判断・UX 判断が出たら `docs/product-decisions.md` に**理由ごと**追記する（やらないと決めたことも記録し、復活させない）
- 大きめの機能や相談したい変更は Issue 化して **`flow` ラベル**を付けると issue-driven-flow（shape → 人間の承認 → build → PR）が回る（photo-layout と同じ構成。要 `CLAUDE_CODE_OAUTH_TOKEN` Secret）

## 既知の落とし穴

- Linux XCTest はクラス全体 `@MainActor` の同期テストを呼べない → テストメソッド単位で `async` + `await` にする
- WSL の `/mnt/c` は I/O が遅い → SwiftPM のビルド産物は `--scratch-path ~/.cache/photo-sheet/spm-build`（scripts が設定済み）
- ImageRenderer は Lazy コンテナを完全描画しない → キャンバスは非 Lazy（VStack/HStack）を維持
- Instagram Story 直接連携は Meta App ID が必要（`InstagramStoryService.metaAppID`、未設定時はボタン非表示）
- Appetize の publicKey / API トークンは Secrets 管理。**ドキュメントやコードに書かない**（公開リポジトリ化する際は appetize.yml のサマリー出力も見直すこと）
