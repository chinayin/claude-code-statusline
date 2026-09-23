# claude-code-statusline

[English](README.md) | 简体中文

Claude Code 双行状态栏：模型 / effort / 上下文 / git / PR / 成本 / 时长 / 订阅限额，一眼全览。

布局参考 [Kiro](https://kiro.dev) 的状态栏风格：`·` 分隔、紫色全路径、白色括号分支、无多余 emoji。

```
Fable 5 · ⚡high ∴ · ~/github/chinayin/claude-statusline · (master ✚2 ●3) · ✓PR#1234 +156/-23
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
| OpenViking | 可选的记忆插件状态，位于第 2 行末尾，如 `OV✓ ↓6 180ms · ↑4.0k/20k 2arch`；仅安装插件后出现。详见 [OpenViking 记忆插件](#openviking-记忆插件可选) |

配色使用 ANSI 亮色系 91–97（深色主题下足够亮，仍跟随终端调色板，浅色主题自适应）。窄终端（<100 列）自动隐藏 token 数、倒计时等次要信息，路径截断长度也随 `COLUMNS` 自适应。

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

### Windows

Windows 上 Claude Code 通过 **Git Bash**（Git for Windows 自带）运行 statusline 脚本，因此同一脚本原样可用。先在 PowerShell 中装好依赖：

```powershell
winget install Git.Git jqlang.jq
```

然后打开 **Git Bash**，执行同一条一行安装命令：

```bash
curl -fsSL https://raw.githubusercontent.com/chinayin/claude-code-statusline/master/install.sh | bash
```

说明：安装器写入的 `~/.claude/statusline.sh` 路径使用正斜杠（反斜杠在 Git Bash 中会被当转义吃掉）；Windows Terminal 下想要可点击链接，可用 `FORCE_HYPERLINK=1 claude` 启动。

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
| `CCSL_SHOW_OV` | 1 | OpenViking 段（未安装插件时自动隐藏；设 `0` 关闭） |
| `CCSL_OV_STATE_DIR` | `$OPENVIKING_HOME/state`，否则 `~/.openviking/state` | OpenViking hook 写状态快照的目录 |

## OpenViking 记忆插件（可选）

如果你在 Claude Code 里使用 [OpenViking 记忆插件](https://github.com/volcengine/OpenViking/tree/main/examples/claude-code-memory-plugin)，它的运行状态会追加在第 2 行末尾。无需任何配置：装了插件就自动出现，没装就不显示。

```
███████░░░ 78% (156k/200k) · $12.3 · ⏱ 1h30m · 5h:64%(↻1h48m) 7d:41% · OV✓ ↓6 180ms · ↑4.0k/20k 2arch
```

| 部分 | 含义 |
|---|---|
| `OV✓` / `OV✗` | OpenViking 服务器健康（绿）/ 连不上（红）。本轮召回在联网前就跳过时（如提问太短）只显示白色 `OV` |
| `↓6 180ms` | 记忆**流入**对话：上一条提问召回并注入了 6 条记忆，耗时 180ms。耗时 ≥1s 标黄。仅在确实注入了记忆时显示 |
| `↑4.0k/20k` | 对话**写回**记忆：距下次归档已累计 4.0k，阈值 20k token。每次归档后归零重新累计 |
| `↑committed` | 本轮刚完成一次归档 |
| `2arch` | 本会话已完成的归档次数 |
| `✗1dropped` | 红色告警：最近一批有 1 轮对话捕获失败。下次捕获成功后自动消失 |

显示条件：插件的状态快照存在、距今不超过 30 分钟、属于当前 Claude Code 会话（多开窗口不会串台），且终端不窄于 100 列。本项目只读这两份本地 JSON 快照，不连接 OpenViking 服务器，也不读插件的配置和 API key。

想隐藏这一段，在 shell profile 中加入下面这行并重启 Claude Code：

```bash
export CCSL_SHOW_OV=0   # CCSL = Claude Code StatusLine；SHOW_OV = 显示 OpenViking 段
```

关闭后连快照文件都不会读取。如果你改过 OpenViking 的主目录，把 `CCSL_OV_STATE_DIR` 指向其中的 `state` 目录即可（默认已跟随 `OPENVIKING_HOME`）。

## 安全设计

- **零网络请求、零数据上报**：所有数据来自 Claude Code 通过 stdin 传入的 JSON；不读 `~/.claude/.credentials.json` 等任何凭证（部分社区项目会拿 OAuth token 调非公开 usage API，本项目刻意不这么做）。
- **终端转义注入防护**：目录名、分支名、模型名等外部字符串统一清洗反斜杠与 C0 控制字符（输出经 `printf '%b'`，未清洗的数据可注入 ANSI/OSC 序列）。
- **PR 链接白名单**：仅 `https://` 且字符合法的 URL 才会进入 OSC 8 超链接。
- **缓存放用户私有目录**（`~/.claude/cache`，700 权限）而非共享 `/tmp`，避免多用户机器上的符号链接/篡改攻击；写入走临时文件 + `mv` 原子替换；session_id 参与文件名前做白名单过滤。
- **OpenViking 快照按不可信输入处理**：只读两份本地 JSON，不读 `ovcli.conf` 及其中的 API key。数字字段必须是整数，reason 字段只做白名单匹配、从不输出，文件损坏时整段丢弃，不影响状态栏其余部分。
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
