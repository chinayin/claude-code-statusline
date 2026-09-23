# 设计准则（Design Principles）

本文档记录项目的设计决策与不可破坏的约束，供后续维护时参考。改代码前先读这里。

## 项目定位

为 Claude Code 提供一个**快、安全、零依赖网络**的双行状态栏，面向团队分发（一行命令安装）。不做的事：不调任何 API、不读凭证、不做成需要构建工具链的大项目（单文件 bash 是特性，不是债务）。

## 视觉准则

布局参考 Kiro 的状态栏风格，已和实际使用反馈多轮校准，**改动前先确认是否违反以下结论**：

1. **禁用 ANSI DIM（`\033[2m`）**——深色主题下过浅，这是历史上被用户明确否决过的。
2. 配色只用 **ANSI 亮色系 91–97**（仍属 16 色调色板，跟随终端主题，深浅主题自适应）；**不写死 RGB/256 色**。
3. 中灰 `\033[90m` 只用于纯次要信息（分隔符 `·`、token 数、倒计时）；**需要被看见的标识用亮白 97**（分支名、thinking 的 `∴`）。
4. **emoji 政策**：装饰性 emoji 不要（📁🌿🧠 都被移除过）；仅保留语义明确的 ⚡（effort）和 ⏱（时长）。状态标识优先用文本符号（✓ ✗ ◌ ○ ✚ ● … ∴）。
5. 目录显示**全路径**（`$HOME` → `~`），紫色（95），超过终端宽度一半才从目录边界截断为 `…/`；不靠右对齐。
6. 分支用亮白括号样式 `(master)`，git 状态计数放括号内。
7. 主要文本加粗；分隔符用 `·` 不用 `|`。

## 技术准则

1. **单次 jq 调用**解析全部字段——多次起 jq 进程是常见性能坑。新增字段时加进同一个 jq 数组。
2. 字段分隔符用 `\u001f`（写成 jq 转义，**不要写字面控制字符**——分享/复制时会丢）；tab 是空白字符，bash `read` 会折叠连续 tab 导致空字段错位。
3. 输出用 `printf '%b'`，不用 `echo -e`（官方推荐，跨 shell 更可靠）。
4. **性能预算 < 50ms**；git 信息走 5 秒缓存（TTL 可配）；慢脚本会阻塞状态栏刷新。
5. 所有字段缺失/为 null 时**对应段自动隐藏，不报错**——兼容旧版 Claude Code 与 API key 计费用户（无 `rate_limits`）。
6. 可配置项一律 `CCSL_*` 环境变量 + 脚本顶部默认值（`: "${VAR:=default}"`）。
7. 窄终端（COLUMNS < 100）自动隐藏次要信息；路径截断阈值随 COLUMNS 自适应。
8. 数据来源是 Claude Code 经 stdin 传入的 JSON，字段清单见[官方 statusline 文档](https://code.claude.com/docs/en/statusline#available-data)。

## 安全红线（不可妥协）

1. **零网络请求、零数据上报、不读任何凭证文件**（`~/.claude/.credentials.json` 等）。不学某些社区项目拿 OAuth token 调非公开 usage API。
2. 所有进入输出的外部字符串（目录、分支、模型名等）必须过 `sanitize()`：去反斜杠 + 去 C0 控制字符——`printf '%b'` 会解释数据里的转义，未清洗可被注入 ANSI/OSC 序列。
3. 进入 OSC 8 超链接的 URL 必须白名单校验（仅 `https://` + 合法字符）；`file://` 路径按段 `@uri` 编码。
4. 缓存只放用户私有目录（`~/.claude/cache/statusline`，700），**不放共享 `/tmp`**；写入走临时文件 + `mv` 原子替换；session_id 参与文件名前做 `[a-zA-Z0-9_-]` 白名单过滤。
5. git 调用必须带 `-c core.fsmonitor=false`（防不可信仓库借配置执行命令）和 `--no-optional-locks`（不抢 index 锁）。
6. 第三方插件数据（目前仅 OpenViking）**只读其本地状态快照**，不读其配置/凭证（如 `ovcli.conf` 的 API key），不替它探测服务器。快照按不可信输入处理：数字字段整数校验、枚举字段只匹配不输出、文件损坏时整段丢弃且不影响主状态栏。

## 第三方段位集成（OpenViking）

- **位置与样式**：追加在第 2 行末尾 `· OV✓ ↓6 180ms · ↑4.0k/20k 2arch`；不单开第 3 行（项目定位是双行，压缩后只有约 30 字符）。**不加括号**（第 2 行已有 `(84k/200k)` `(↻…)` 两组，再加显得堆砌）、**不加粗**（整体观感更轻）；OV 在行尾，左侧 `·` + `OV✓` 标签即可界定边界，召回组与捕获组之间一个 `·`。
- **图标**：召回 `↓`（记忆流入对话）、捕获 `↑`（对话写回记忆），成对自解释。弃用 `✎`/`↩`：`✎` 属 Dingbats 区，多数等宽字体未收录，回退字体渲染发虚；饼图 `◔` 与 git 段 `●` 同族易混。
- **解耦**：模块分两块——「数据接入」把 jq 片段 `def ov` 并入唯一一次 jq 调用，对主流程只暴露一个不透明字段 `OV_RAW`（内部 `\u001e` 分隔）；「渲染」由 `ov_render` 独立完成。删掉这两块和 `OV_RAW`/`OV_SEG` 两处引用即可整体移除。
- **取舍**：只保留召回条数/耗时、待归档进度、归档次数、失败告警、健康态；丢弃 OV 自带的模型/ctx（与第 2 行重复）、`🔗 resumed`（emoji 且只活 1 分钟）、`+N today`（跨会话统计，与当前工作弱相关）。
- **健康态推断**：不发网络请求，从 `last-recall.json` 的 reason 推断——`ok/no_results/filtered_out` 发生在 OV 健康检查通过之后记 ✓，`offline` 记 ✗，其余（如 `short_query` 在联网前就跳过）不打标记。

## 修改流程

1. 改 `statusline.sh`（或其他脚本）。
2. 跑 `bash tests/run.sh`（fixtures 冒烟 + 安全断言）和 `shellcheck statusline.sh install.sh uninstall.sh tests/run.sh`，必须全绿。
3. 新增行为先补 fixture/断言再改代码；涉及安全面的改动必须新增对应安全断言。
4. README.md（英文，默认）与 README_CN.md（中文）**同步更新**，两版内容保持对齐。
5. 本机验证：`cp statusline.sh ~/.claude/statusline.sh`，下一次交互生效。
6. 提交信息用 conventional commits（feat/fix/chore/docs），不带 AI 署名尾注。
7. 发版：更新脚本头部 `Version:`，打 `vX.Y.Z` 标签推送。**README 的镜像安装走 jsDelivr 无版本地址，它解析到最新的语义化版本标签而不是 main 分支**——只推 main 不打标签，镜像用户拿不到新版本。标签推送后可请求 `https://purge.jsdelivr.net/gh/chinayin/claude-code-statusline/install.sh` 与 `.../statusline.sh` 立即刷新 CDN 缓存（否则最多等 12 小时）。GitHub Release 不是必需的，jsDelivr 只认 git 标签。

## 测试速查

```bash
bash tests/run.sh        # 全部测试
echo '{"model":{"display_name":"T"},"workspace":{"current_dir":"'$PWD'"},"context_window":{"used_percentage":42},"session_id":"t"}' | bash statusline.sh   # 手动冒烟
COLUMNS=80 bash statusline.sh < tests/fixtures/full.json   # 窄终端
```
