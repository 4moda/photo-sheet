#!/usr/bin/env bash
# Domain + 永続化層のテストをローカル (Linux/macOS) で高速に実行する。Mac 不要。
# ビルド産物は低速なファイルシステム (WSL の /mnt/c 等) を避けてホーム側のキャッシュに置く。
set -euo pipefail
cd "$(dirname "$0")/.."

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

if ! command -v swift >/dev/null 2>&1; then
    echo "error: swift が見つかりません。swift.org のツールチェインを導入し、" >&2
    echo "       SWIFT_TOOLCHAIN_DIR で bin ディレクトリを指定してください。" >&2
    exit 1
fi

exec swift test --scratch-path "$HOME/.cache/photo-sheet/spm-build" "$@"
