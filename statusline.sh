#!/bin/bash
# =============================================================================
# claude-statusline — Claude Code 双行状态栏（布局参考 Kiro）
# Version: 2.1.0
#
# 第 1 行: 模型 · effort · 目录全路径(紫色,可点击) · (git分支/状态) · PR · 增删行数
# 第 2 行: 上下文进度条 · token 数 · 成本 · ⏱时长 · 5h/7d 订阅限额
#
# 依赖: jq (macOS: brew install jq / Ubuntu: sudo apt install jq)
# 数据全部来自 Claude Code 通过 stdin 传入的 JSON。
# 安全声明: 本脚本零网络请求、不读任何凭证文件、不上报任何数据。
# =============================================================================

# ===== 可配置项（在 shell profile 中 export 同名环境变量即可覆盖） =====
: "${CCSL_BAR_WIDTH:=10}"        # 上下文进度条宽度
: "${CCSL_GIT_CACHE_TTL:=5}"     # git 信息缓存秒数，大仓库可调大
: "${CCSL_SHOW_TOKENS:=1}"       # 显示 token 数 (156k/200k)
: "${CCSL_SHOW_RATE:=1}"         # 显示 5h/7d 订阅限额
: "${CCSL_SHOW_PR:=1}"           # 显示当前分支的 PR（可点击）
: "${CCSL_SHOW_LINES:=1}"        # 显示本次会话代码增删行数
: "${CCSL_CACHE_DIR:=$HOME/.claude/cache/statusline}"  # 缓存目录（用户私有，避免共享 /tmp 被篡改）

input=$(cat)

# ===== 一次 jq 调用解析全部字段 =====
# 分隔符用 \u001f（单元分隔符）：tab 属于空白字符，bash read 会折叠连续 tab 导致空字段错位。
# DIR_URI 在 jq 里按路径段做 @uri 编码，保证 file:// 链接对特殊字符安全。
IFS=$'\x1f' read -r MODEL DIR DIR_URI PCT CTX_USED CTX_SIZE COST DURATION_MS \
  LINES_ADD LINES_DEL EFFORT THINKING SESSION_ID WORKTREE \
  PR_NUM PR_URL PR_STATE FIVE_H FIVE_H_RESET WEEK \
  < <(jq -r '[
    (.model.display_name // "Claude"),
    (.workspace.current_dir // .cwd // ""),
    (.workspace.current_dir // .cwd // "" | split("/") | map(@uri) | join("/")),
    ((.context_window.used_percentage // 0) | floor),
    (.context_window.total_input_tokens // 0),
    (.context_window.context_window_size // 200000),
    (.cost.total_cost_usd // 0),
    (.cost.total_duration_ms // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.effort.level // ""),
    (.thinking.enabled // false),
    (.session_id // "nosession"),
    (.workspace.git_worktree // ""),
    (.pr.number // ""),
    (.pr.url // ""),
    (.pr.review_state // ""),
    (.rate_limits.five_hour.used_percentage // "-"),
    (.rate_limits.five_hour.resets_at // "-"),
    (.rate_limits.seven_day.used_percentage // "-")
  ] | map(tostring) | join("\u001f")' <<<"$input")

# jq 解析失败时的兜底，保证脚本不会因空值报错
MODEL=${MODEL:-Claude}; PCT=${PCT:-0}; COST=${COST:-0}
DURATION_MS=${DURATION_MS:-0}; SESSION_ID=${SESSION_ID:-nosession}
CTX_USED=${CTX_USED:-0}; CTX_SIZE=${CTX_SIZE:-200000}

# ===== 安全处理 =====
# 1) 输出经 printf '%b' 渲染，数据里的反斜杠会被当转义解释；目录/分支名理论上可携带
#    控制字符做终端转义注入。统一清洗外部字符串：去反斜杠 + 去 C0 控制字符（保留 UTF-8 多字节）。
sanitize() {
  local s=${1//\\/}
  printf '%s' "$s" | tr -d '\000-\037\177'
}
# 2) SESSION_ID 参与缓存文件名，白名单过滤防路径注入
SESSION_ID=${SESSION_ID//[^a-zA-Z0-9_-]/}
MODEL=$(sanitize "$MODEL")
WORKTREE=$(sanitize "$WORKTREE")

# 颜色：用 ANSI 亮色系 91-96（仍属 16 色调色板，跟随终端主题），深色主题下比标准
# 30 系明显更亮；不用 \033[2m (DIM)——过浅；次要信息用中灰 90。分隔符学 Kiro 用 ·
CYAN='\033[96m'; GREEN='\033[92m'; YELLOW='\033[93m'; RED='\033[91m'
MAGENTA='\033[95m'; GRAY='\033[90m'; WHITE='\033[97m'; BOLD='\033[1m'; RESET='\033[0m'
SEP="${GRAY}·${RESET}"

# 窄终端自适应：Claude Code ≥2.1.153 会注入 COLUMNS
NARROW=0
[ -n "${COLUMNS:-}" ] && [ "${COLUMNS:-120}" -lt 100 ] 2>/dev/null && NARROW=1

# ===== git 信息（带缓存，官方推荐做法） =====
# 缓存放用户私有目录而非共享 /tmp：多用户 Linux 上 /tmp 可被他人预建同名文件/软链接。
mkdir -p "$CCSL_CACHE_DIR" 2>/dev/null && chmod 700 "$CCSL_CACHE_DIR" 2>/dev/null
CACHE_FILE="$CCSL_CACHE_DIR/git-${SESSION_ID}"
NOW=$(date +%s)
MTIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
if [ $((NOW - MTIME)) -gt "$CCSL_GIT_CACHE_TTL" ]; then
  # --no-optional-locks: 避免与用户并发的 git 操作争抢 index 锁
  # core.fsmonitor=false: 防不可信仓库通过该配置在 git diff/status 时执行任意命令
  GIT=(git --no-optional-locks -c core.fsmonitor=false -C "$DIR")
  if "${GIT[@]}" rev-parse --git-dir >/dev/null 2>&1; then
    BRANCH=$("${GIT[@]}" branch --show-current 2>/dev/null)
    # detached HEAD 时显示短 commit
    [ -z "$BRANCH" ] && BRANCH=$("${GIT[@]}" rev-parse --short HEAD 2>/dev/null)
    STAGED=$("${GIT[@]}" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$("${GIT[@]}" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    UNTRACKED=$("${GIT[@]}" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  else
    BRANCH=""; STAGED=0; MODIFIED=0; UNTRACKED=0
  fi
  # 原子写入（临时文件+mv），避免并发读到半截内容；顺手清理 1 天前的旧会话缓存
  printf '%s|%s|%s|%s\n' "$BRANCH" "$STAGED" "$MODIFIED" "$UNTRACKED" > "$CACHE_FILE.$$" \
    && mv -f "$CACHE_FILE.$$" "$CACHE_FILE"
  find "$CCSL_CACHE_DIR" -name 'git-*' -mmin +1440 -delete 2>/dev/null
fi
IFS='|' read -r BRANCH STAGED MODIFIED UNTRACKED < "$CACHE_FILE" 2>/dev/null
BRANCH=$(sanitize "$BRANCH")

# 分支样式学 Kiro：亮白色括号 (master)，状态计数跟在分支名后
GIT_SEG=""
if [ -n "$BRANCH" ]; then
  GIT_SEG=" ${SEP} ${WHITE}(${BRANCH}${RESET}"
  [ -n "$WORKTREE" ] && GIT_SEG="${GIT_SEG} ${GRAY}wt:${WORKTREE}${RESET}"
  [ "${STAGED:-0}" -gt 0 ] 2>/dev/null && GIT_SEG="${GIT_SEG} ${GREEN}✚${STAGED}${RESET}"
  [ "${MODIFIED:-0}" -gt 0 ] 2>/dev/null && GIT_SEG="${GIT_SEG} ${YELLOW}●${MODIFIED}${RESET}"
  [ "${UNTRACKED:-0}" -gt 0 ] 2>/dev/null && GIT_SEG="${GIT_SEG} ${GRAY}…${UNTRACKED}${RESET}"
  GIT_SEG="${GIT_SEG}${WHITE})${RESET}"
fi

# ===== PR（可点击跳转，仅当前分支有 open PR 时显示） =====
PR_SEG=""
if [ "$CCSL_SHOW_PR" = "1" ] && [ -n "$PR_NUM" ]; then
  case "$PR_STATE" in
    approved)          PR_ICON="${GREEN}✓" ;;
    changes_requested) PR_ICON="${RED}✗" ;;
    draft)             PR_ICON="${GRAY}○" ;;
    *)                 PR_ICON="${YELLOW}◌" ;;
  esac
  # PR_URL 来自 Claude Code（gh 解析），仅作超链接目标；按白名单字符校验一道
  if [[ "$PR_URL" =~ ^https://[a-zA-Z0-9./_-]+$ ]]; then
    PR_SEG=" ${SEP} \033]8;;${PR_URL}\a${PR_ICON}PR#${PR_NUM}${RESET}\033]8;;\a"
  else
    PR_SEG=" ${SEP} ${PR_ICON}PR#${PR_NUM}${RESET}"
  fi
fi

# ===== 本次会话的代码增删行数 =====
LINES_SEG=""
if [ "$CCSL_SHOW_LINES" = "1" ] && { [ "${LINES_ADD:-0}" -gt 0 ] || [ "${LINES_DEL:-0}" -gt 0 ]; }; then
  LINES_SEG=" ${GREEN}+${LINES_ADD}${RESET}${GRAY}/${RESET}${RED}-${LINES_DEL}${RESET}"
fi

# ===== effort 档位 + thinking（effort.level 来自 stdin JSON，模型不支持时为空） =====
# 加粗亮色（参考 Kiro 的 High 观感）；thinking 开启时显示亮白 ∴（表示深度思考中）
EFFORT_SEG=""
if [ -n "$EFFORT" ]; then
  case "$EFFORT" in
    max|xhigh) EFFORT_COLOR="$RED" ;;
    high)      EFFORT_COLOR="$YELLOW" ;;
    low)       EFFORT_COLOR="$GRAY" ;;
    *)         EFFORT_COLOR="$GREEN" ;;
  esac
  EFFORT_SEG=" ${SEP} ${BOLD}${EFFORT_COLOR}⚡${EFFORT}${RESET}"
fi
[ "$THINKING" = "true" ] && EFFORT_SEG="${EFFORT_SEG} ${WHITE}∴${RESET}"

# ===== 上下文进度条（绿 <70% / 黄 70-89% / 红 >=90%；实槽阈值色、空槽灰色） =====
if   [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT * CCSL_BAR_WIDTH / 100)); EMPTY=$((CCSL_BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${BAR_COLOR}${FILL// /█}${RESET}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${GRAY}${PAD// /░}${RESET}"

TOKENS_SEG=""
[ "$CCSL_SHOW_TOKENS" = "1" ] && [ "$NARROW" = "0" ] \
  && TOKENS_SEG=" ${GRAY}($((CTX_USED / 1000))k/$((CTX_SIZE / 1000))k)${RESET}"

# ===== 成本（绿 <$10 / 黄 <$100 / 红 >=$100） =====
COST_INT=$(printf '%.0f' "$COST" 2>/dev/null || echo 0)
if   [ "$COST_INT" -ge 100 ]; then COST_FMT="\$${COST_INT}"; COST_COLOR="$RED"
elif [ "$COST_INT" -ge 10 ];  then COST_FMT=$(printf '$%.1f' "$COST"); COST_COLOR="$YELLOW"
else COST_FMT=$(printf '$%.2f' "$COST"); COST_COLOR="$GREEN"; fi

# ===== 会话时长 =====
TOTAL_SECS=$((DURATION_MS / 1000))
HOURS=$((TOTAL_SECS / 3600)); MINS=$(((TOTAL_SECS % 3600) / 60)); SECS=$((TOTAL_SECS % 60))
if   [ "$HOURS" -gt 0 ]; then TIME_FMT="${HOURS}h${MINS}m"
elif [ "$MINS" -gt 0 ];  then TIME_FMT="${MINS}m${SECS}s"
else TIME_FMT="${SECS}s"; fi

# ===== 5h/7d 订阅限额（仅 Pro/Max 订阅、首次 API 响应后才有；API key 计费无此字段） =====
rate_color() {  # $1: 0-100 的百分比
  local p; p=$(printf '%.0f' "$1" 2>/dev/null || echo 0)
  if   [ "$p" -ge 80 ]; then printf '%s' "$RED"
  elif [ "$p" -ge 50 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}
RATE_SEG=""
if [ "$CCSL_SHOW_RATE" = "1" ] && [ "$FIVE_H" != "-" ] && [ -n "$FIVE_H" ]; then
  RATE_SEG=" ${SEP} $(rate_color "$FIVE_H")5h:$(printf '%.0f' "$FIVE_H")%${RESET}"
  # 距离 5 小时窗口重置的倒计时（窄终端下省略）
  if [ "$NARROW" = "0" ] && [ "$FIVE_H_RESET" != "-" ] && [ "$FIVE_H_RESET" -gt "$NOW" ] 2>/dev/null; then
    REM=$((FIVE_H_RESET - NOW))
    RATE_SEG="${RATE_SEG}${GRAY}(↻$((REM / 3600))h$(((REM % 3600) / 60))m)${RESET}"
  fi
  if [ "$WEEK" != "-" ] && [ -n "$WEEK" ]; then
    RATE_SEG="${RATE_SEG} $(rate_color "$WEEK")7d:$(printf '%.0f' "$WEEK")%${RESET}"
  fi
fi

# ===== 目录：全路径（$HOME 缩写为 ~），紫色（参考 Kiro），超长才从目录边界截断；
#       OSC 8 超链接包裹，Cmd/Ctrl+点击在文件管理器打开（需 iTerm2/WezTerm/Kitty 等） =====
DIR_SEG=""
if [ -n "$DIR" ]; then
  PATH_DISP=$(sanitize "${DIR/#$HOME/\~}")
  MAXLEN=$(( ${COLUMNS:-160} / 2 )); [ "$MAXLEN" -lt 24 ] && MAXLEN=24
  if [ ${#PATH_DISP} -gt "$MAXLEN" ]; then
    TAIL=${PATH_DISP: -$MAXLEN}
    PATH_DISP="…/${TAIL#*/}"
  fi
  DIR_SEG=" ${SEP} \033]8;;file://${DIR_URI}\a${MAGENTA}${PATH_DISP}${RESET}\033]8;;\a"
fi

# ===== 输出（printf '%b' 比 echo -e 跨 shell 更可靠，官方推荐） =====
printf '%b\n' "${CYAN}${BOLD}${MODEL}${RESET}${EFFORT_SEG}${DIR_SEG}${GIT_SEG}${PR_SEG}${LINES_SEG}"
printf '%b\n' "${BAR} ${BAR_COLOR}${BOLD}${PCT}%${RESET}${TOKENS_SEG} ${SEP} ${COST_COLOR}${COST_FMT}${RESET} ${SEP} ⏱ ${TIME_FMT}${RATE_SEG}"
