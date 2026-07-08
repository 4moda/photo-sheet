#!/usr/bin/env bash
# Claude Code の PostToolUse フック。
# コア (Domain / Data/Persistence / PhotoSheetTests) の Swift ファイルが編集されたら
# 即座にコンパイルチェックし、エラーがあれば exit 2 で編集者(AI)に突き返す。
set -uo pipefail

INPUT="$(cat)"
FILE="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"

case "$FILE" in
    */PhotoSheet/Domain/*.swift | */PhotoSheet/Data/Persistence/*.swift | */PhotoSheetTests/*.swift) ;;
    *) exit 0 ;;
esac

# Swift ツールチェインの解決: PATH → $SWIFT_TOOLCHAIN_DIR → ~/toolchains/swift-*/usr/bin
if ! command -v swift >/dev/null 2>&1; then
    TOOLCHAIN="${SWIFT_TOOLCHAIN_DIR:-}"
    if [ -z "$TOOLCHAIN" ]; then
        for dir in "$HOME"/toolchains/swift-*/usr/bin; do
            [ -d "$dir" ] && TOOLCHAIN="$dir"
        done
    fi
    [ -n "$TOOLCHAIN" ] && export PATH="$TOOLCHAIN:$PATH"
fi
command -v swift >/dev/null 2>&1 || exit 0   # ツールチェインがない環境ではスキップ

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

OUT="$(swift build --build-tests --scratch-path "$HOME/.cache/photo-sheet/spm-build" 2>&1)"
STATUS=$?
if [ $STATUS -ne 0 ]; then
    {
        echo "コア (PhotoSheetCore) のコンパイルに失敗しました。修正してください:"
        echo "$OUT" | grep -E "error:" -A 2 | head -50
    } >&2
    exit 2
fi
exit 0
