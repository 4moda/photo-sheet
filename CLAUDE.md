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
2. コミット・push → 3 つのワークフローが走る:
   - **CI**: SwiftLint / Linux コアテスト / macOS フルビルド+テスト+Domain カバレッジゲート(80%)
   - **Appetize Deploy**: ブラウザ確認用ビルドを更新
   - **Device Build**: 未署名 IPA を Artifacts に出力（Sideloadly 等 + 無料 Apple ID で実機確認）
3. CI の監視: `gh run list --limit 3` / `gh run watch <id> --exit-status`
4. 失敗時: `gh run view <id> --log-failed | grep -E "error:" | head -30`

## アーキテクチャの不変条件

- **Clean Architecture**。依存方向は Presentation → Domain ← Data。Domain は Foundation 以外に依存しない。
- **ポータブルコア規約**: `PhotoSheet/Domain/`, `PhotoSheet/Data/Persistence/`, `PhotoSheetTests/` は **Linux でコンパイル可能に保つ**（Package.swift に含まれる）。UIKit/SwiftUI/Photos に依存するコードとテストをここに置いてはならない。置くと Linux CI が落ちる（それが検知装置）。
- **WYSIWYG 規約**: レイアウトの寸法・座標は**すべて `SheetLayoutMath`（Domain の純関数）から取得**する。View 側に比率や寸法をハードコードしない。プレビュー・書き出し・サムネイル・将来の動画書き出しが同じ計算を共有するための生命線。
- レイアウト値は幅に対する**比率**で持つ（どの解像度でも相似形）。
- 永続化は `SheetProjectRepository` プロトコル経由。実装詳細（ファイル形式）を Presentation に漏らさない。

## UI/UX ポリシー（オーナー確定事項）

- フローティングバーの項目は**最大 6 個**。新しい設定は既存パネル（見た目 / タイトル / 書き出し）へ収める。
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

### 参照画像を初回生成 / 更新する手順

1. **GitHub Actions > Update Snapshots > Run workflow** を手動実行（`workflow_dispatch`）
2. 完了後、該当 run の Artifacts から `snapshot-images.zip` をダウンロード
3. 展開して `PhotoSheetSnapshotTests/__Snapshots__/SheetCanvasViewSnapshotTests/` に配置
4. コミット・push（次の CI からは比較モードで動く）

### レイアウトを意図的に変えたとき

CI の `Build & Test` が snapshot failure で落ちる → 上記の手順で参照画像を更新してコミット。

### ローカル（Mac + Xcode）で確認したいとき

Xcode のスキームに環境変数 `RECORD_SNAPSHOTS = true` を追加して実行 → `__Snapshots__/` に画像が生成される。

## Definition of Done（タスク完了の条件）

- [ ] コア変更なら `scripts/test-core.sh` がローカルで成功
- [ ] 新しいロジックにはテストを追加（Domain カバレッジ 80% ゲートあり）
- [ ] push 後、CI 3 ワークフローすべてグリーンを確認
- [ ] UI 変更なら Appetize/実機での確認ポイントを具体的に提示
- [ ] 規約・構成に影響する変更（規約・構成）は同じコミットで CLAUDE.md / README を更新

## Issue ベースの開発ループ

機能追加・バグ修正は GitHub Issue を起点にする:

1. `gh issue create` またはテンプレート（.github/ISSUE_TEMPLATE/）で Issue 化（**受け入れ条件を必ず書く**）
2. Issue 番号を含むブランチで作業 → PR 作成（`gh pr create`、テンプレートのチェックリストに従う）
3. CI グリーン + 受け入れ条件を満たしたらマージ、`Closes #N` で Issue を閉じる
4. 大きい変更ほど Issue を細かく割る（1 Issue = 1 検証可能な振る舞い）

## 既知の落とし穴

- Linux XCTest はクラス全体 `@MainActor` の同期テストを呼べない → テストメソッド単位で `async` + `await` にする
- WSL の `/mnt/c` は I/O が遅い → SwiftPM のビルド産物は `--scratch-path ~/.cache/photo-sheet/spm-build`（scripts が設定済み）
- ImageRenderer は Lazy コンテナを完全描画しない → キャンバスは非 Lazy（VStack/HStack）を維持
- Instagram Story 直接連携は Meta App ID が必要（`InstagramStoryService.metaAppID`、未設定時はボタン非表示）
- Appetize の publicKey / API トークンは Secrets 管理。**ドキュメントやコードに書かない**（公開リポジトリ化する際は appetize.yml のサマリー出力も見直すこと）
