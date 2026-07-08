#!/usr/bin/env bash
# CI (macOS) 用: xcresult から Domain 層のラインカバレッジを算出し、基準未満なら fail させる。
set -euo pipefail
RESULT="${1:-TestResults.xcresult}"
THRESHOLD="${2:-80}"

JSON="$(xcrun xccov view --report --json "$RESULT")"

read -r COVERED EXECUTABLE <<< "$(echo "$JSON" | jq -r '
    [.targets[].files[] | select(.path | contains("/Domain/"))]
    | "\(map(.coveredLines) | add // 0) \(map(.executableLines) | add // 0)"
')"

if [ "$EXECUTABLE" -eq 0 ]; then
    echo "::error::Domain 層のカバレッジ対象が見つかりません"
    exit 1
fi

PCT=$(( COVERED * 100 / EXECUTABLE ))
echo "Domain coverage: ${PCT}% (${COVERED}/${EXECUTABLE} lines, threshold ${THRESHOLD}%)"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "### Domain カバレッジ: ${PCT}%（基準 ${THRESHOLD}%）" >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$PCT" -lt "$THRESHOLD" ]; then
    echo "::error::Domain 層のカバレッジ ${PCT}% が基準 ${THRESHOLD}% を下回っています。テストを追加してください。"
    exit 1
fi
