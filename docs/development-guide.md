# Development Guide

## 変更時の基本ループ（trunk ベース）

1. コア変更時は `scripts/test-core.sh`
2. push 前に UI 層差分の型・API 自己レビュー（macOS CI の往復は高コスト）
3. 動く段階まで仕上げて main へ直接コミット・push
4. push 後に GitHub Actions を確認。赤くなったら即 fix-forward
5. UI 変更は Appetize / 実機で目視確認

```sh
scripts/test-core.sh
gh run list --limit 3
gh run watch <run-id> --exit-status
gh run view <run-id> --log-failed | grep -E "error:" | head -30
```

## ツールチェーン（CI）

- macOS ランナー: `macos-26`、Xcode は `DEVELOPER_DIR` で **26.6 固定**（photo-layout と同じ）
- シミュレータ: iPhone 17
- Linux コアテスト: `swift:6.3-noble`（Xcode 26.6 = Swift 6.3 に整合）

## ワークフロー

- `CI`: SwiftLint / Linux コアテスト / macOS Build & Test / Domain coverage gate / スクショ撮影（fastlane snapshot）+ Cloudflare Pages デプロイ。docs・Markdown のみの変更ではスキップ（paths-ignore）
  - スクショの見方: `docs/screens.md`（画面ID・機能ID）。人間は `https://main-latest.photosheet-screenshots.pages.dev`、AI は `gh run download -n screenshots`
  - 必要な Secrets: `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID`（Pages プロジェクト `photosheet-screenshots` と Zero Trust Access は事前に人間が作成。未設定の間はデプロイを静かにスキップ）
- `Appetize Deploy`: シミュレータ向けビルドを Appetize にアップロード。**CI が main で成功した後にだけ** workflow_run で起動（手動実行も可）
- `Device Build (unsigned IPA)`: 未署名 IPA を Artifact 出力。同じく CI 成功後にだけ起動（手動実行も可）
- `actionlint`: `.github/workflows/` 変更時のみ、ワークフロー定義を静的検査（shellcheck 込み）

## スナップショット更新

`PhotoSheetSnapshotTests` が意図通りに変わった場合のみ参照画像を更新する。

1. Actions の `Update Snapshots` を手動実行
2. `snapshot-images.zip` を取得
3. `PhotoSheetSnapshotTests/__Snapshots__/...` に反映
4. コミットして CI で比較モードに戻す

## 既知の注意点

- Linux XCTest: クラス全体 `@MainActor` は避け、テストメソッド単位で `async/await` を使う
- WSL: `/mnt/c` は I/O が遅いので SwiftPM scratch path を使う
- Appetize の API トークン / publicKey は Secrets で管理し、ログやドキュメントへ露出しない
