# Development Guide

## 変更時の基本ループ

1. コア変更時は `scripts/test-core.sh`
2. push 後に GitHub Actions を確認
3. UI 変更は Appetize / 実機で目視確認

```sh
scripts/test-core.sh
gh run list --limit 3
gh run watch <run-id> --exit-status
gh run view <run-id> --log-failed | grep -E "error:" | head -30
```

## ワークフロー

- `CI`: SwiftLint / Linux コアテスト / macOS Build & Test / Domain coverage gate
- `Appetize Deploy`: シミュレータ向けビルドを Appetize にアップロード
- `Device Build (unsigned IPA)`: 未署名 IPA を Artifact 出力

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
