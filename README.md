# claude-code-statusline

English | [简体中文](README_CN.md)

A two-line status line for Claude Code: model / effort / context / git / PR / cost / duration / subscription limits — all at a glance.

Layout inspired by [Kiro](https://kiro.dev)'s status bar: `·` separators, purple full path, white parenthesized branch, no decorative emojis.

```
Fable 5 · ⚡high ∴ · ~/github/chinayin/claude-statusline · (master ✚2 ●3) · ✓PR#1234 +156/-23
███████░░░ 78% (156k/200k) · $12.3 · ⏱ 1h30m · 5h:64%(↻1h48m) 7d:41%
```

## Features

| Segment | Description |
|---|---|
| Model + effort | Model in bold bright cyan; `⚡` + reasoning effort, bold and color-coded (high yellow / xhigh·max red / medium green); bright white `∴` when extended thinking is on |
| Full directory path | Purple, `$HOME` abbreviated to `~`, truncated at a directory boundary (`…/`) only when longer than half the terminal width; **clickable** (OSC 8, Cmd+click opens in Finder) |
| (git branch) | Bright white parenthesized style `(master)`, short commit on detached HEAD; worktree marker / ✚staged ●modified …untracked |
| PR | Open PR for the current branch, **clickable**, ✓approved ✗changes requested ◌pending ○draft |
| +/- lines | Lines of code added/removed this session |
| Progress bar | Context window usage, <70% green / <90% yellow / ≥90% red, with token counts |
| Cost | <$10 green / <$100 yellow / ≥$100 red |
| 5h/7d limits | Pro/Max subscription limits + 5h window reset countdown (read straight from stdin, **zero API calls**) |
| OpenViking | Optional memory-plugin status at the end of line 2, e.g. `OV✓ ↓6 180ms · ↑4.0k/20k 2arch`; appears only when the plugin is installed. See [OpenViking memory plugin](#openviking-memory-plugin-optional) |

Colors use the bright ANSI palette 91–97 (clearly visible on dark themes, still driven by your terminal's color scheme, adapts to light themes). On narrow terminals (<100 columns) secondary info such as token counts and the countdown is hidden automatically, and the path truncation length follows `COLUMNS`.

## Install

Requires `jq` and `git` (macOS: `brew install jq`)

One-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/chinayin/claude-code-statusline/main/install.sh | bash
```

Mirror (jsDelivr CDN, for networks where `raw.githubusercontent.com` is unreachable):

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/chinayin/claude-code-statusline/install.sh | bash -s -- --mirror
```

To download from your own source instead, set `CCSL_REPO_RAW_URL` to its base URL. It cannot be combined with `--mirror`; the installer exits with an error rather than silently picking one. Run `install.sh --help` for all options.

Behind a proxy instead, `export https_proxy=http://127.0.0.1:7890` first and use the one-liner above; the export makes the second download inside install.sh go through the proxy too, which `curl -x` would not.

Or clone and install:

```bash
git clone git@github.com:chinayin/claude-code-statusline.git
cd claude-code-statusline && bash install.sh
```

The installer: checks dependencies → copies the script to `~/.claude/statusline.sh` → merges `settings.json` with jq (**after backing it up**, touching only the `statusLine` key) → runs a smoke test. No restart needed for running Claude Code sessions — the status line appears after your next interaction.

Manual install: copy `statusline.sh` to `~/.claude/`, `chmod +x` it, then add to `~/.claude/settings.json`:

```json
{ "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }
```

### Windows

On Windows, Claude Code runs status line scripts through **Git Bash** (bundled with Git for Windows), so the same script works as-is. In PowerShell, install the dependencies once:

```powershell
winget install Git.Git jqlang.jq
```

Then open **Git Bash** and run the same one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/chinayin/claude-code-statusline/main/install.sh | bash
```

Notes: the installer writes the `~/.claude/statusline.sh` path with forward slashes (backslashes break in Git Bash); for clickable links in Windows Terminal you may need to launch with `FORCE_HYPERLINK=1 claude`.

## Configuration

Export environment variables in your shell profile (takes effect after restarting Claude Code):

| Variable | Default | Description |
|---|---|---|
| `CCSL_BAR_WIDTH` | 10 | Progress bar width |
| `CCSL_GIT_CACHE_TTL` | 5 | Git info cache in seconds; raise for large repos |
| `CCSL_SHOW_TOKENS` | 1 | Token counts (156k/200k) |
| `CCSL_SHOW_RATE` | 1 | 5h/7d limits |
| `CCSL_SHOW_PR` | 1 | PR segment |
| `CCSL_SHOW_LINES` | 1 | Lines added/removed |
| `CCSL_CACHE_DIR` | `~/.claude/cache/statusline` | Cache directory |
| `CCSL_SHOW_OV` | 1 | OpenViking segment (auto-hidden when the plugin is absent; `0` turns it off) |
| `CCSL_OV_STATE_DIR` | `$OPENVIKING_HOME/state`, else `~/.openviking/state` | Where the OpenViking hooks write their state snapshots |

## OpenViking memory plugin (optional)

If you use the [OpenViking memory plugin](https://github.com/volcengine/OpenViking/tree/main/examples/claude-code-memory-plugin) for Claude Code, its status is appended to the end of line 2. Nothing to configure: the segment shows up by itself when the plugin is installed and stays hidden otherwise.

```
███████░░░ 78% (156k/200k) · $12.3 · ⏱ 1h30m · 5h:64%(↻1h48m) 7d:41% · OV✓ ↓6 180ms · ↑4.0k/20k 2arch
```

| Part | Meaning |
|---|---|
| `OV✓` / `OV✗` | OpenViking server healthy (green) / unreachable (red). Plain `OV` when this turn's recall was skipped before contacting the server, e.g. a very short prompt |
| `↓6 180ms` | Memories flowing **into** the conversation: 6 memories were recalled and injected for your last prompt, taking 180ms. The latency turns yellow at 1s or more. Shown only when something was actually injected |
| `↑4.0k/20k` | The conversation being written **back** to memory: 4.0k of the 20k tokens needed before the next archive. Resets to 0 after each archive |
| `↑committed` | This turn just produced an archive |
| `2arch` | Archives produced in this session so far |
| `✗1dropped` | Red alert: capturing failed for 1 turn in the latest batch. Clears itself after the next successful capture |

When the segment is shown: the plugin's state snapshots exist, are fresher than 30 minutes, belong to the current Claude Code session (other windows never leak in), and the terminal is at least 100 columns wide. This project only reads those two local JSON snapshots; it never contacts the OpenViking server and never reads the plugin's config or API key.

To hide it, add this to your shell profile and restart Claude Code:

```bash
export CCSL_SHOW_OV=0   # CCSL = Claude Code StatusLine; SHOW_OV = show the OpenViking segment
```

With the switch off, the snapshot files are not read at all. If you moved OpenViking's home directory, point `CCSL_OV_STATE_DIR` at its `state` folder (it follows `OPENVIKING_HOME` automatically).

## Security design

- **Zero network requests, zero telemetry**: all data comes from the JSON Claude Code pipes to stdin; never reads `~/.claude/.credentials.json` or any other credentials (some community projects use the OAuth token to call an undocumented usage API — this project deliberately does not).
- **Terminal escape injection protection**: external strings such as directory, branch, and model names are stripped of backslashes and C0 control characters (output goes through `printf '%b'`; unsanitized data could inject ANSI/OSC sequences).
- **PR link allowlist**: only `https://` URLs with safe characters are placed inside OSC 8 hyperlinks.
- **Cache lives in a user-private directory** (`~/.claude/cache`, mode 700) instead of shared `/tmp`, avoiding symlink/tampering attacks on multi-user machines; writes go through a temp file + atomic `mv`; the session_id is allowlist-filtered before being used in a filename.
- **OpenViking snapshots are treated as untrusted input**: only two local JSON files are read, never `ovcli.conf` or its API key. Numeric fields must be integers, the reason field is only matched against an allowlist and never printed, and a corrupt file is dropped without affecting the rest of the line.
- **Git hardening**: `-c core.fsmonitor=false` prevents untrusted repos from executing arbitrary commands via git config; `--no-optional-locks` avoids contending with your own git operations for the index lock.
- Runs in roughly 15–40ms (a single jq pass for all fields + 5-second git info cache), never blocking status line refreshes.

## Tests

```bash
bash tests/run.sh    # fixture smoke tests + security assertions (OSC injection, URL allowlist, no network access)
shellcheck statusline.sh install.sh uninstall.sh
```

## Uninstall

```bash
bash uninstall.sh
```

## FAQ

- **Status line not showing**: `chmod +x ~/.claude/statusline.sh`; run `claude --debug` to see the first invocation's log; make sure settings don't contain `disableAllHooks: true`; new directories need the workspace trust prompt accepted, then restart.
- **Limits segment missing**: `rate_limits` only exists for Claude Pro/Max subscriptions; API-key billing has no such field — this is normal.
- **Directory/PR not clickable**: requires an OSC 8-capable terminal (iTerm2 / WezTerm / Kitty); macOS's built-in Terminal.app does not support it. If your terminal supports it but links don't work, launch with `FORCE_HYPERLINK=1 claude`.
- **Windows**: requires a Git Bash environment; use forward slashes for paths in settings.json.
- Claude Code ≥ 2.1.x recommended; on older versions, segments with missing fields hide themselves without errors.

## License

Apache-2.0
