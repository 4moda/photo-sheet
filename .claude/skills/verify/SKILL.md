---
name: verify
description: photo-sheet の変更を検証する。コアはローカル swift test、アプリ全体は CI (macOS)、UI は Appetize/実機。変更をコミット・報告する前に必ず実行する。
---

# photo-sheet の検証手順

Mac なしでも回る 3 層の検証。**確認できていない層のことを「動作確認済み」と言わない**。

## 1. ローカル（数秒・必須）

コア層（Domain / Data/Persistence / PhotoSheetTests）に触れた場合:

```sh
scripts/test-core.sh
```

- 失敗したら修正してから次へ。コンパイルエラーは編集時フックでも検出される。
- コア以外（Presentation 等）は Linux ではコンパイルできない。型名・API の綴りを既存コードと突き合わせて静的に確認する。

## 2. CI（~5 分・push 時）

```sh
git push
gh run list --limit 3                     # 走っている 3 ワークフローを確認
gh run watch <run-id> --exit-status       # 完了待ち
gh run view <run-id> --log-failed | grep -E "error:" | head -30   # 失敗時
```

グリーン条件: SwiftLint / Linux コアテスト / macOS ビルド+テスト / Domain カバレッジ 80%。

## 3. 人間の目（UI 変更時）

- **Appetize**: main push で自動更新。URL は Actions の「Appetize Deploy」実行サマリーを参照
- **実機**: Device Build ワークフローの Artifacts から IPA → Sideloadly 等でインストール
- ユーザーへ「何をどう操作すると何が見えるはずか」を具体的に伝えて確認を依頼する。

## 報告のルール

- ローカル成功 + CI グリーン → 「テスト済み」
- UI の見た目・操作感 → 「Appetize で〜を確認してください」と依頼（自分では断定しない）
- 失敗やスキップがあれば正直にそのまま報告する
