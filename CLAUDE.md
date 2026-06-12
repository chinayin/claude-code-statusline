# CLAUDE.md

Claude Code 双行状态栏（单文件 bash）。**动手前先读 `docs/DESIGN.md`**——视觉/技术/安全准则都在那里，很多约束是历史决策，代码里看不出原因。

## 硬性规则（详见 docs/DESIGN.md）

- 零网络请求、零凭证读取；外部字符串必须过 `sanitize()`；URL 进超链接必须白名单。
- 禁用 ANSI DIM；只用亮色系 91–97 + 中灰 90；不写死 RGB。
- 装饰性 emoji 不加（仅保留 ⚡ ⏱）；分隔符用 `·`。
- 单次 jq 解析；性能预算 < 50ms；字段缺失时段自动隐藏不报错。
- 提交不带 AI 署名尾注；README.md（英）与 README_CN.md（中）同步改。

## 常用命令

```bash
bash tests/run.sh                                          # 测试（必须全绿才能提交）
shellcheck statusline.sh install.sh uninstall.sh tests/run.sh
cp statusline.sh ~/.claude/statusline.sh                   # 本机生效
```
