#!/bin/bash
# claude-statusline 测试套件：fixtures 冒烟 + 安全断言
set -uo pipefail
cd "$(dirname "$0")" || exit 1
SCRIPT="../statusline.sh"
FAIL=0
# 隔离本机真实的 ~/.openviking 快照，保证测试结果与机器无关
CCSL_OV_STATE_DIR=$(mktemp -d); export CCSL_OV_STATE_DIR

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=1; }

echo "== fixtures 冒烟测试 =="
for f in fixtures/*.json; do
  OUT=$(CCSL_CACHE_DIR=$(mktemp -d) bash "$SCRIPT" < "$f" 2>/dev/null)
  RC=$?
  LINES=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
  echo "[$f]"
  if [ "$RC" -eq 0 ];    then pass "退出码为 0"; else fail "退出码为 0 (got $RC)"; fi
  if [ "$LINES" -eq 2 ]; then pass "输出 2 行";  else fail "输出 2 行 (got $LINES)"; fi
  if [ -n "$OUT" ];      then pass "输出非空";   else fail "输出非空"; fi
done

echo "== 安全断言 =="
# 1. 脚本不应包含任何网络/凭证访问
if ! grep -qE 'curl|wget|nc |/dev/tcp|credentials' "$SCRIPT"; then
  pass "无网络请求与凭证读取"
else
  fail "无网络请求与凭证读取"
fi

# 2. 敌意输入：目录/模型名里的 ESC 必须被清洗，输出不应含真实 OSC 0 标题注入序列
OUT=$(CCSL_CACHE_DIR=$(mktemp -d) bash "$SCRIPT" < fixtures/hostile.json 2>/dev/null)
if ! printf '%s' "$OUT" | grep -q $'\033]0;'; then
  pass "敌意目录名的 OSC 注入被清洗"
else
  fail "敌意目录名的 OSC 注入被清洗"
fi

# 3. 敌意 PR URL（非 https 白名单）不应进入超链接
if ! printf '%s' "$OUT" | grep -q 'javascript:'; then
  pass "非法 PR URL 不进超链接"
else
  fail "非法 PR URL 不进超链接"
fi

# 4. 不应使用过浅的 DIM 属性
OUT2=$(CCSL_CACHE_DIR=$(mktemp -d) bash "$SCRIPT" < fixtures/full.json 2>/dev/null)
if ! printf '%s' "$OUT2" | grep -q $'\033\[2m'; then
  pass "输出不含 DIM(\\033[2m)"
else
  fail "输出不含 DIM(\\033[2m)"
fi

# 5. 花括号规则：$VAR 后紧跟非 ASCII 字节会被 bash 吞进变量名
if ! LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' "$SCRIPT"; then
  pass "无裸 \$VAR 紧跟非 ASCII 字符"
else
  fail "无裸 \$VAR 紧跟非 ASCII 字符（改用 \${VAR}）"
fi

echo "== OpenViking 段 =="
OVD=$(mktemp -d)
TS=$(($(date +%s) * 1000)); OLD=$((TS - 31 * 60 * 1000))
R_OK='{"reason":"ok","count":6,"latency_ms":180,"cc_session_id":"fix-full","ts":'"${TS}"'}'
C_OK='{"pending_tokens":4004,"commit_threshold":20000,"committed":false,"commit_count":2,"turns_failed":0,"cc_session_id":"fix-full","ts":'"${TS}"'}'
ov_state() { printf '%s' "$1" > "$OVD/last-recall.json"; printf '%s' "$2" > "$OVD/last-capture.json"; }
ov_raw() {  # 参数为额外的环境变量赋值（后者覆盖前者）；输出保留 ANSI
  env CCSL_OV_STATE_DIR="$OVD" CCSL_CACHE_DIR="$(mktemp -d)" COLUMNS=160 "$@" \
    bash "$SCRIPT" < fixtures/full.json 2>/dev/null
}
ov_run() { ov_raw "$@" | sed $'s/\033\\[[0-9;]*m//g'; }
has()   { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3 (got: $1)" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3 (got: $1)" ;; *) pass "$3" ;; esac; }

ov_state "$R_OK" "$C_OK"
has   "$(ov_run)" "7d:41% · OV✓ ↓6 180ms · ↑4.0k/20k 2arch" "正常态显示召回+捕获进度"
# OV 段不加粗：取第 2 行 "OV" 之后的原始输出，不应出现 \033[1m
OUT=$(ov_raw | tail -1)
lacks "${OUT#*7d:}" $'\033[1m' "OV 段不使用粗体"
lacks "$(ov_run CCSL_SHOW_OV=0)" "OV" "CCSL_SHOW_OV=0 关闭"
lacks "$(ov_run COLUMNS=80)" "OV" "窄终端自动隐藏"

ov_state "${R_OK/\"ts\":${TS}/\"ts\":${OLD}}" "${C_OK/\"ts\":${TS}/\"ts\":${OLD}}"
lacks "$(ov_run)" "OV" "快照超过 30 分钟视为过期"

ov_state "${R_OK/fix-full/other}" "${C_OK/fix-full/other}"
lacks "$(ov_run)" "OV" "其他会话的快照不显示"

ov_state "${R_OK/\"ok\"/\"offline\"}" "$C_OK"
has   "$(ov_run)" "· OV✗ ↑4.0k/20k 2arch" "离线态红叉，捕获进度仍显示（无召回组时不出现内部 ·）"

ov_state "${R_OK/180/2388}" "${C_OK/\"committed\":false/\"committed\":true}"
has   "$(ov_raw)" $'\033[93m2388ms' "召回耗时 ≥1s 标黄"
ov_state "$R_OK" '{"committed":true,"commit_count":3,"turns_failed":1,"cc_session_id":"fix-full","ts":'"${TS}"'}'
has   "$(ov_run)" "· OV✓ ↓6 180ms · ↑committed 3arch ✗1dropped" "刚归档 + 失败告警"

ov_state '{not json' "$C_OK"
OUT=$(ov_run)
if [ "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" -eq 2 ] && [[ "$OUT" == *"Fable 5"* ]]; then
  pass "快照损坏时主状态栏不受影响"
else
  fail "快照损坏时主状态栏不受影响 (got: $OUT)"
fi

# 敌意快照：reason/count 夹带 OSC 标题注入与字段分隔符，企图串位或注入终端序列
ov_state '{"reason":"ok\u001b]0;pwn\u0007\u001f","count":"6\u001b]0;x","latency_ms":1,"cc_session_id":"fix-full","ts":'"${TS}"'}' "$C_OK"
OUT=$(ov_raw)
if ! printf '%s' "$OUT" | grep -q $'\033]0;' && [[ "$OUT" != *pwn* ]] && [[ "$OUT" == *"7d:41%"* ]]; then
  pass "敌意快照不注入、不串位"
else
  fail "敌意快照不注入、不串位 (got: $OUT)"
fi

echo "== 性能 =="
perf() {  # $1: OV 快照目录；跑 20 次取平均
  local s e _
  s=$(date +%s%N 2>/dev/null || echo 0)
  for _ in $(seq 20); do
    CCSL_OV_STATE_DIR="$1" CCSL_CACHE_DIR="$OVD" bash "$SCRIPT" < fixtures/full.json >/dev/null 2>&1
  done
  e=$(date +%s%N 2>/dev/null || echo 0)
  if [ "$s" != "0" ] && [[ "$e" =~ ^[0-9]+$ ]]; then echo "$(((e - s) / 20000000))ms"; else echo "n/a"; fi
}
ov_state "$R_OK" "$C_OK"
echo "  平均单次（无 OV 快照）: $(perf "$(mktemp -d)")"
echo "  平均单次（有 OV 快照）: $(perf "$OVD")"

if [ "$FAIL" -eq 0 ]; then
  echo "✅ 全部通过"
else
  echo "❌ 有失败项"
  exit 1
fi
