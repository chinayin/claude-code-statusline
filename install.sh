#!/bin/bash
# claude-code-statusline 安装脚本
# 用法:
#   一行安装:  curl -fsSL https://raw.githubusercontent.com/chinayin/claude-code-statusline/master/install.sh | bash
#   镜像安装:  curl -fsSL https://cdn.jsdelivr.net/gh/chinayin/claude-code-statusline/install.sh | bash -s -- --mirror
#   本地安装:  git clone git@github.com:chinayin/claude-code-statusline.git && cd claude-code-statusline && bash install.sh
# 参数:
#   --mirror   从 jsDelivr CDN 下载 statusline.sh（无版本地址 = 最新发布标签），适用于访问不了 raw.githubusercontent.com 的网络
#   -h|--help  显示帮助
# 下载源优先级（互斥，不做静默覆盖）:
#   --mirror > CCSL_REPO_RAW_URL（自定义源）> 默认 GitHub raw；--mirror 与 CCSL_REPO_RAW_URL 同时出现时报错退出
#   在仓库目录内运行时直接拷贝同目录的 statusline.sh，不下载，下载源设置不生效
# 退出码: 0 成功 / 1 参数错误或安装失败
set -euo pipefail

DEFAULT_RAW_URL="https://raw.githubusercontent.com/chinayin/claude-code-statusline/master"
MIRROR_URL="https://cdn.jsdelivr.net/gh/chinayin/claude-code-statusline"
TARGET="$HOME/.claude/statusline.sh"
SETTINGS="$HOME/.claude/settings.json"

info()  { printf '\033[32m[ok]\033[0m %s\n' "$1"; }
err()   { printf '\033[31m[error]\033[0m %s\n' "$1" >&2; exit 1; }
# 帮助文本按团队 shell 规范用英文
usage() {
  cat <<'USAGE'
Usage: install.sh [--mirror] [-h|--help]

Install claude-code-statusline to ~/.claude/statusline.sh and enable it in settings.json.

Options:
  --mirror     Download statusline.sh from the jsDelivr CDN (latest release tag),
               for networks where raw.githubusercontent.com is unreachable.
               Cannot be combined with CCSL_REPO_RAW_URL.
  -h, --help   Show this help and exit.

Environment:
  CCSL_REPO_RAW_URL   Custom base URL to download statusline.sh from.

Piped install passes options after "bash -s --":
  curl -fsSL https://cdn.jsdelivr.net/gh/chinayin/claude-code-statusline/install.sh | bash -s -- --mirror

Exit codes: 0 success, 1 usage error or install failure.
USAGE
}

# --- 0. 参数解析（curl | bash 场景用 bash -s -- --mirror 传参） ---
USE_MIRROR=0
while [ $# -gt 0 ]; do
  case "$1" in
    --mirror)  USE_MIRROR=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)         usage >&2; err "unknown option: ${1}" ;;
  esac
done
# 决定下载源：两种显式指定互斥，避免用户以为用了自定义源、实际却走了镜像（或反之）
if [ "$USE_MIRROR" = "1" ]; then
  [ -n "${CCSL_REPO_RAW_URL:-}" ] && err "--mirror cannot be combined with CCSL_REPO_RAW_URL (${CCSL_REPO_RAW_URL}); unset one of them"
  REPO_RAW_URL="$MIRROR_URL"
else
  REPO_RAW_URL="${CCSL_REPO_RAW_URL:-$DEFAULT_RAW_URL}"
fi

# --- 1. 依赖检查 ---
command -v jq  >/dev/null 2>&1 || err "缺少 jq，请先安装: brew install jq (macOS) / sudo apt install jq (Ubuntu)"
command -v git >/dev/null 2>&1 || err "缺少 git"
info "依赖检查通过 (jq, git)"

# --- 2. 获取脚本（优先用仓库内同目录的文件；curl|bash 场景从远端下载） ---
SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || echo "")
mkdir -p "$HOME/.claude"
if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/statusline.sh" ]; then
  cp "$SRC_DIR/statusline.sh" "$TARGET"
elif [ -n "$REPO_RAW_URL" ]; then
  curl -fsSL "$REPO_RAW_URL/statusline.sh" -o "$TARGET" || err "下载 statusline.sh 失败"
else
  err "找不到 statusline.sh（请在仓库目录内运行，或设置 CCSL_REPO_RAW_URL）"
fi
chmod +x "$TARGET"
info "已安装脚本: $TARGET"

# --- 3. 合并 settings.json（先备份，只增改 statusLine 键，不动其他配置） ---
if [ -f "$SETTINGS" ]; then
  jq -e . "$SETTINGS" >/dev/null 2>&1 || err "$SETTINGS 不是合法 JSON，请先手动修复后重试"
  BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  info "已备份 settings.json -> $BACKUP"
else
  echo '{}' > "$SETTINGS"
fi
TMP=$(mktemp)
jq '.statusLine = {"type":"command","command":"~/.claude/statusline.sh"}' "$SETTINGS" > "$TMP" \
  && mv "$TMP" "$SETTINGS"
jq -e '.statusLine.command' "$SETTINGS" >/dev/null || err "settings.json 写入校验失败"
info "已在 settings.json 中启用 statusLine"

# --- 4. 冒烟测试 ---
OUT=$(echo '{"session_id":"install-test","model":{"display_name":"Test"},"workspace":{"current_dir":"'"$HOME"'"}}' | bash "$TARGET")
[ -n "$OUT" ] || err "脚本执行无输出，请检查"
info "冒烟测试通过，输出预览:"
printf '%s\n' "$OUT"

printf '\n🎉 安装完成。Claude Code 配置会自动重载，下一次交互后状态栏即出现（正在运行的会话无需重启）。\n'
printf '   自定义: 在 shell profile 中 export CCSL_* 环境变量，详见 README。\n'
