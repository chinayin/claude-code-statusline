#!/bin/bash
# claude-statusline 测试套件：fixtures 冒烟 + 安全断言
set -uo pipefail
cd "$(dirname "$0")" || exit 1
SCRIPT="../statusline.sh"
FAIL=0

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

echo "== 性能 =="
START=$(date +%s%N 2>/dev/null || echo 0)
CCSL_CACHE_DIR=$(mktemp -d) bash "$SCRIPT" < fixtures/full.json >/dev/null 2>&1
END=$(date +%s%N 2>/dev/null || echo 0)
if [ "$START" != "0" ] && [[ "$END" =~ ^[0-9]+$ ]]; then
  echo "  单次执行: $(((END - START) / 1000000))ms"
fi

if [ "$FAIL" -eq 0 ]; then
  echo "✅ 全部通过"
else
  echo "❌ 有失败项"
  exit 1
fi
