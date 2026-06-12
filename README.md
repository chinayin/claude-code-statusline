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

Colors use the bright ANSI palette 91–97 (clearly visible on dark themes, still driven by your terminal's color scheme, adapts to light themes). On narrow terminals (<100 columns) secondary info such as token counts and the countdown is hidden automatically, and the path truncation length follows `COLUMNS`.

## Install

Requires `jq` and `git` (macOS: `brew install jq`)

One-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/chinayin/claude-code-statusline/master/install.sh | bash
```

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
curl -fsSL https://raw.githubusercontent.com/chinayin/claude-code-statusline/master/install.sh | bash
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

## Security design

- **Zero network requests, zero telemetry**: all data comes from the JSON Claude Code pipes to stdin; never reads `~/.claude/.credentials.json` or any other credentials (some community projects use the OAuth token to call an undocumented usage API — this project deliberately does not).
- **Terminal escape injection protection**: external strings such as directory, branch, and model names are stripped of backslashes and C0 control characters (output goes through `printf '%b'`; unsanitized data could inject ANSI/OSC sequences).
- **PR link allowlist**: only `https://` URLs with safe characters are placed inside OSC 8 hyperlinks.
- **Cache lives in a user-private directory** (`~/.claude/cache`, mode 700) instead of shared `/tmp`, avoiding symlink/tampering attacks on multi-user machines; writes go through a temp file + atomic `mv`; the session_id is allowlist-filtered before being used in a filename.
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
