#!/usr/bin/env bash
#
# Claude Code statusline script
# Reads JSON from stdin (provided by Claude Code) and outputs a formatted status line.
# Requires: jq, git
#

# ANSI color codes
PURPLE=$'\033[1;35m'
GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'
ORANGE=$'\033[38;5;208m'
RED=$'\033[1;31m'
BLUE=$'\033[1;34m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# Read JSON payload from Claude Code
INPUT=$(cat)
jqr() { echo "$INPUT" | jq -r "${1} // empty" 2>/dev/null; }

# ── Model ────────────────────────────────────────────────────────────────────
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // .model.id // "unknown"' 2>/dev/null)
MODEL="${MODEL:-unknown}"

# ── Context usage ─────────────────────────────────────────────────────────────
CONTEXT_PCT_RAW=$(jqr '.context_window.used_percentage')
if [ -n "$CONTEXT_PCT_RAW" ]; then
    CONTEXT_PCT=$(printf "%.0f" "$CONTEXT_PCT_RAW")
else
    TOKENS_USED=$(echo "$INPUT" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
    TOKENS_MAX=$(echo "$INPUT"  | jq -r '.context_window.context_window_size // 200000' 2>/dev/null)
    TOKENS_USED="${TOKENS_USED:-0}"
    TOKENS_MAX="${TOKENS_MAX:-200000}"
    if [ "$TOKENS_MAX" -gt 0 ] 2>/dev/null; then
        CONTEXT_PCT=$(( (TOKENS_USED * 100) / TOKENS_MAX ))
    else
        CONTEXT_PCT=0
    fi
fi
# Clamp to 0-100
[ "$CONTEXT_PCT" -lt 0 ] && CONTEXT_PCT=0
[ "$CONTEXT_PCT" -gt 100 ] && CONTEXT_PCT=100

# Gauge color thresholds: 0-50 green, 51-74 yellow, 75-90 orange, 91+ red
if   [ "$CONTEXT_PCT" -le 50 ]; then GAUGE_COLOR="$GREEN"
elif [ "$CONTEXT_PCT" -le 74 ]; then GAUGE_COLOR="$YELLOW"
elif [ "$CONTEXT_PCT" -le 90 ]; then GAUGE_COLOR="$ORANGE"
else                                  GAUGE_COLOR="$RED"
fi

# Gauge bar (20 blocks)
GAUGE_WIDTH=20
FILLED=$(( (CONTEXT_PCT * GAUGE_WIDTH + 50) / 100 ))
[ "$FILLED" -gt "$GAUGE_WIDTH" ] && FILLED=$GAUGE_WIDTH
EMPTY=$(( GAUGE_WIDTH - FILLED ))
GAUGE_BAR="${GAUGE_COLOR}"
for ((i=0; i<FILLED; i++)); do GAUGE_BAR+="█"; done
for ((i=0; i<EMPTY; i++)); do GAUGE_BAR+="░"; done
GAUGE_BAR+="${RESET}"

# ── Current directory ─────────────────────────────────────────────────────────
REAL_CWD=$(jqr '.cwd')
[ -z "$REAL_CWD" ] && REAL_CWD="$PWD"
DISPLAY_CWD="${REAL_CWD/#$HOME/\~}"

# ── Git branch & status ───────────────────────────────────────────────────────
GIT_INFO=""
if git -C "$REAL_CWD" rev-parse --git-dir &>/dev/null; then
    BRANCH=$(git -C "$REAL_CWD" branch --show-current 2>/dev/null)
    [ -z "$BRANCH" ] && BRANCH=$(git -C "$REAL_CWD" rev-parse --short HEAD 2>/dev/null)

    # Local changes
    GIT_DIRTY=""
    git -C "$REAL_CWD" diff --cached --quiet 2>/dev/null || GIT_DIRTY+="+"  # staged
    git -C "$REAL_CWD" diff --quiet         2>/dev/null || GIT_DIRTY+="!"   # unstaged
    UNTRACKED=$(git -C "$REAL_CWD" ls-files --others --exclude-standard 2>/dev/null | head -1)
    [ -n "$UNTRACKED" ] && GIT_DIRTY+="?"

    # Remote sync (uses locally cached remote refs — no blocking fetch)
    UPSTREAM=$(git -C "$REAL_CWD" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    REMOTE_SYNC=""
    if [ -n "$UPSTREAM" ]; then
        BEHIND=$(git -C "$REAL_CWD" rev-list --count HEAD.."$UPSTREAM" 2>/dev/null || echo 0)
        AHEAD=$(git  -C "$REAL_CWD" rev-list --count "$UPSTREAM"..HEAD 2>/dev/null || echo 0)
        [ "$BEHIND" -gt 0 ] && REMOTE_SYNC+=" ⇣${BEHIND}"
        [ "$AHEAD"  -gt 0 ] && REMOTE_SYNC+=" ⇡${AHEAD}"
    fi

    GIT_INFO=" ${GREEN} ${BRANCH}${GIT_DIRTY}${REMOTE_SYNC}${RESET}"
fi

# ── Session length ────────────────────────────────────────────────────────────
SESSION_ID=$(jqr '.session_id')
SESSION_PART=""
if [ -n "$SESSION_ID" ]; then
    SESSION_FILE="/tmp/claude-statusbar-${SESSION_ID}"
    [ ! -f "$SESSION_FILE" ] && date +%s > "$SESSION_FILE"
    START=$(cat "$SESSION_FILE")
    NOW=$(date +%s)
    ELAPSED=$(( NOW - START ))
    H=$(( ELAPSED / 3600 ))
    M=$(( (ELAPSED % 3600) / 60 ))
    [ "$H" -gt 0 ] && SESSION_PART="${H}h${M}m" || SESSION_PART="${M}m"
fi

# ── Assemble output ───────────────────────────────────────────────────────────
OUT="${PURPLE} ${MODEL}${RESET}"
OUT+="  [${GAUGE_BAR}] ${GAUGE_COLOR}${CONTEXT_PCT}%${RESET}"
OUT+="  ${BLUE} ${DISPLAY_CWD}${RESET}"
OUT+="${GIT_INFO}"
[ -n "$SESSION_PART" ] && OUT+="  ${DIM}⏱ ${SESSION_PART}${RESET}"

printf "%s\n" "$OUT"
