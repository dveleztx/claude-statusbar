# Claude Code Statusline

A shell script that plugs into Claude Code's **status line hook** to display a rich, color-coded status bar showing model, context usage, working directory, git branch, and session duration.

![example status bar](https://github.com/user-attachments/assets/placeholder)

```
 Claude Sonnet 4.6 | [████████████░░░░░░░░] 62% |  ~/projects/myapp |  main+! ⇡2 | 14m 32s
```

---

## Features

| Segment | What it shows |
|---|---|
| **Model** | Display name of the active Claude model |
| **Context gauge** | 20-block bar + percentage; color shifts green → yellow → orange → red as context fills |
| **Directory** | Current working directory (`~`-abbreviated) |
| **Git branch** | Branch name with dirty-state indicators (`+` staged, `!` unstaged, `?` untracked) and remote sync arrows (`⇣` behind, `⇡` ahead) |
| **Session timer** | Elapsed time since the session started (s / m s / h m / d h) |

---

## Requirements

- **bash** (or any bash-compatible shell)
- **jq** — JSON processor
- **git** — for branch/status info
- **Claude Code** CLI

Install `jq` if you don't have it:

```bash
# macOS
brew install jq

# Ubuntu / Debian
sudo apt install jq

# Fedora / RHEL
sudo dnf install jq
```

---

## Installation

### 1. Clone this repo (or just copy the script)

```bash
git clone https://github.com/YOUR_USERNAME/claude-statusbar.git
# or simply download statusline.sh somewhere on your PATH
```

### 2. Make the script executable

```bash
chmod +x /path/to/statusline.sh
```

### 3. Register the hook in Claude Code settings

Open (or create) `~/.claude/settings.json` and add a `PostToolUse` → `stop` hook that points to the script:

```json
{
  "statusline": {
    "enabled": true,
    "script": "/path/to/statusline.sh"
  }
}
```

> **Note:** The exact settings key may vary as Claude Code evolves. The script reads JSON piped to stdin, so any hook mechanism that pipes the session JSON to an external script will work.

---

## How it works

Claude Code pipes a JSON payload to the script on stdin. The script extracts:

- `.model.display_name` / `.model.id` — model name
- `.context_window.used_percentage` (or `.context_window.total_input_tokens` / `.context_window.context_window_size`) — context usage
- `.cwd` — working directory
- `.session_id` — used to track elapsed time via a temp file in `/tmp/`
- `~/.claude/settings.json` `.theme` — switches session-timer color for light vs. dark terminal themes

It then writes a single formatted line with ANSI color codes to stdout, which Claude Code renders in the status bar.

---

## Customization

### Context gauge thresholds

Edit these lines in `statusline.sh` to change when the gauge color changes:

```bash
# Gauge color thresholds: 0-50 green, 51-74 yellow, 75-90 orange, 91+ red
if   [ "$CONTEXT_PCT" -le 50 ]; then GAUGE_COLOR="$GREEN"
elif [ "$CONTEXT_PCT" -le 74 ]; then GAUGE_COLOR="$YELLOW"
elif [ "$CONTEXT_PCT" -le 90 ]; then GAUGE_COLOR="$ORANGE"
else                                  GAUGE_COLOR="$RED"
fi
```

### Gauge width

Change `GAUGE_WIDTH=20` to any number of blocks you prefer.

### Light theme session timer

The script reads `~/.claude/settings.json` to detect your theme. If you use a light terminal, set `"theme": "light"` in that file and the session timer will render in black instead of dim gray.

### Disabling segments

Comment out or remove the relevant `OUT+=` lines near the bottom of the script:

```bash
# Remove git info:   comment out the GIT_INFO block and its OUT+= line
# Remove session:    comment out the SESSION_PART block and its OUT+= line
```

---

## Troubleshooting

**Nothing appears / garbled output**
- Confirm `jq` is installed and on your `PATH`.
- Run the script manually with a sample payload to test it:
  ```bash
  echo '{"model":{"display_name":"Claude Sonnet 4.6"},"context_window":{"used_percentage":42},"cwd":"/tmp","session_id":"test123"}' | bash statusline.sh
  ```

**Git info missing**
- The script only shows git info if the `.cwd` directory is inside a git repo.
- It uses locally cached remote refs (no network call), so remote sync counts may lag until you `git fetch`.

**Session timer resets unexpectedly**
- The timer is stored in `/tmp/claude-statusbar-<session_id>`. If `/tmp` is cleared (e.g., on reboot), the timer resets. This is intentional — each new machine session starts fresh.

---

## License

MIT
