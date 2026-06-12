# claude-code-statusline

Claude Code 双行状态栏：模型 / effort / 上下文 / git / PR / 成本 / 时长 / 订阅限额，一眼全览。

布局参考 [Kiro](https://kiro.dev) 的状态栏风格：`·` 分隔、紫色全路径、白色括号分支、无多余 emoji。

```
Fable 5 · ⚡high ∴ · ~/Sites/uhomes/uhomes-ai-apps/browser-copilot · (master ✚2 ●3) · ✓PR#1234 +156/-23
███████░░░ 78% (156k/200k) · $12.3 · ⏱ 1h30m · 5h:64%(↻1h48m) 7d:41%
```

## 特性

| 段位 | 说明 |
|---|---|
| 模型 + effort | 模型亮青色加粗；`⚡`+推理档位加粗变色（high 黄 / xhigh·max 红 / medium 绿）；extended thinking 开启时显示亮白 `∴` |
| 目录全路径 | 紫色，`$HOME` 缩写为 `~`，超过终端宽度一半才从目录边界截断为 `…/`；**可点击**（OSC 8，Cmd+点击在 Finder 打开） |
| (git 分支) | 亮白色括号样式 `(master)`，detached HEAD 显示短 commit；worktree 标识 / ✚暂存 ●修改 …未跟踪 |
| PR | 当前分支的 open PR，**可点击跳转**，✓已批准 ✗需修改 ◌待审 ○草稿 |
| +/-行数 | 本次会话代码增删 |
| 进度条 | 上下文用量，<70% 绿 / <90% 黄 / ≥90% 红，附 token 数 |
| 成本 | <$10 绿 / <$100 黄 / ≥$100 红 |
| 5h/7d 限额 | Pro/Max 订阅限额 + 5h 窗口重置倒计时（直接读 stdin，**零 API 调用**） |

配色使用 ANSI 亮色系 91–96（深色主题下足够亮，仍跟随终端调色板，浅色主题自适应）。窄终端（<100 列）自动隐藏 token 数、倒计时等次要信息，路径截断长度也随 `COLUMNS` 自适应。

## 安装

依赖：`jq`、`git`（macOS: `brew install jq`）

一行安装：

```bash
curl -fsSL https://raw.githubusercontent.com/chinayin/claude-code-statusline/master/install.sh | bash
```

或克隆安装：

```bash
git clone git@github.com:chinayin/claude-code-statusline.git
cd claude-code-statusline && bash install.sh
```

安装脚本会：检查依赖 → 复制脚本到 `~/.claude/statusline.sh` → **备份后**用 jq 合并 `settings.json`（只动 `statusLine` 键）→ 冒烟测试。正在运行的 Claude Code 会话无需重启，下一次交互后生效。

手动安装：复制 `statusline.sh` 到 `~/.claude/` 并 `chmod +x`，然后在 `~/.claude/settings.json` 中加入：

```json
{ "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }
```

## 配置

在 shell profile 中 export 环境变量（重启 Claude Code 生效）：

| 变量 | 默认 | 说明 |
|---|---|---|
| `CCSL_BAR_WIDTH` | 10 | 进度条宽度 |
| `CCSL_GIT_CACHE_TTL` | 5 | git 信息缓存秒数，大仓库可调大 |
| `CCSL_SHOW_TOKENS` | 1 | token 数 (156k/200k) |
| `CCSL_SHOW_RATE` | 1 | 5h/7d 限额 |
| `CCSL_SHOW_PR` | 1 | PR 段 |
| `CCSL_SHOW_LINES` | 1 | 增删行数 |
| `CCSL_CACHE_DIR` | `~/.claude/cache/statusline` | 缓存目录 |

## 安全设计

- **零网络请求、零数据上报**：所有数据来自 Claude Code 通过 stdin 传入的 JSON；不读 `~/.claude/.credentials.json` 等任何凭证（部分社区项目会拿 OAuth token 调非公开 usage API，本项目刻意不这么做）。
- **终端转义注入防护**：目录名、分支名、模型名等外部字符串统一清洗反斜杠与 C0 控制字符（输出经 `printf '%b'`，未清洗的数据可注入 ANSI/OSC 序列）。
- **PR 链接白名单**：仅 `https://` 且字符合法的 URL 才会进入 OSC 8 超链接。
- **缓存放用户私有目录**（`~/.claude/cache`，700 权限）而非共享 `/tmp`，避免多用户机器上的符号链接/篡改攻击；写入走临时文件 + `mv` 原子替换；session_id 参与文件名前做白名单过滤。
- **git 加固**：`-c core.fsmonitor=false` 防不可信仓库借 git 配置执行任意命令；`--no-optional-locks` 不与用户的 git 操作争抢 index 锁。
- 性能约 15–40ms（单次 jq 解析全部字段 + git 信息 5 秒缓存），不阻塞状态栏刷新。

## 测试

```bash
bash tests/run.sh    # fixtures 冒烟 + 安全断言（OSC 注入、URL 白名单、无网络访问）
shellcheck statusline.sh install.sh uninstall.sh
```

## 卸载

```bash
bash uninstall.sh
```

## FAQ

- **状态栏不显示**：`chmod +x ~/.claude/statusline.sh`；`claude --debug` 看首次调用日志；确认 settings 没有 `disableAllHooks: true`；新目录需接受工作区信任提示后重启。
- **限额段不显示**：`rate_limits` 仅 Claude Pro/Max 订阅有，API key 计费无此字段，属正常。
- **目录/PR 点不动**：需支持 OSC 8 的终端（iTerm2 / WezTerm / Kitty）；macOS 自带 Terminal.app 不支持。受支持但无效时可 `FORCE_HYPERLINK=1 claude` 启动。
- **Windows**：需 Git Bash 环境，settings.json 中路径用正斜杠。
- 建议 Claude Code ≥ 2.1.x；旧版缺字段时对应段自动隐藏，不报错。

## License

Apache-2.0
