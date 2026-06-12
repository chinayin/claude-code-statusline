#!/bin/bash
# claude-statusline 卸载脚本：移除脚本、settings.json 中的 statusLine 键和缓存
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"

if [ -f "$SETTINGS" ] && jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  TMP=$(mktemp)
  jq 'del(.statusLine)' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  echo "[ok] 已从 settings.json 移除 statusLine（已备份）"
fi

rm -f "$HOME/.claude/statusline.sh"
rm -rf "$HOME/.claude/cache/statusline"
echo "[ok] 已删除脚本与缓存。卸载完成。"
