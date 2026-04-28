#!/usr/bin/env bash

# Read JSON input from stdin
input=$(cat)

MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
DIR_NAME="${CURRENT_DIR##*/}"

# Get git branch
GIT_BRANCH=""
if git rev-parse &>/dev/null; then
  BRANCH=$(git branch --show-current)
  if [ -n "$BRANCH" ]; then
    GIT_BRANCH="$BRANCH"
  else
    GIT_BRANCH="HEAD ($(git rev-parse --short HEAD 2>/dev/null))"
  fi
fi

# Get context_window information
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
USAGE=$(echo "$input" | jq '.context_window.current_usage // null')

if [ "$USAGE" != "null" ]; then
  current_tokens=$(echo "$USAGE" | jq '(.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)')
else
  current_tokens=0
fi

ctx_percentage=$((current_tokens * 100 / CONTEXT_SIZE))

# ANSI colors
reset="\033[0m"
dim="\033[2m"
bold="\033[1m"
red="\033[31m"
yellow="\033[33m"
green="\033[32m"
cyan="\033[36m"

# Color by percentage
color_for_pct() {
  local pct=$1
  if [ "$pct" -ge 80 ]; then echo "$red"
  elif [ "$pct" -ge 50 ]; then echo "$yellow"
  else echo "$green"; fi
}

# Format token count (e.g. 45000 -> 45k, 200000 -> 200k)
format_tokens() {
  local t=$1
  if [ "$t" -ge 1000 ]; then
    echo "$((t / 1000))k"
  else
    echo "$t"
  fi
}

current_fmt=$(format_tokens "$current_tokens")
total_fmt=$(format_tokens "$CONTEXT_SIZE")

# Get git diff stats against main
GIT_DIFF_STR=""
if [ -n "$GIT_BRANCH" ] && git rev-parse &>/dev/null; then
  diff_stat=$(git diff main --shortstat 2>/dev/null)
  if [ -n "$diff_stat" ]; then
    files_changed=$(echo "$diff_stat" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+')
    insertions=$(echo "$diff_stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
    deletions=$(echo "$diff_stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')
    [ -z "$insertions" ] && insertions=0
    [ -z "$deletions" ] && deletions=0
    GIT_DIFF_STR="  ${dim}${files_changed}files${reset} ${green}+${insertions}${reset}${red}-${deletions}${reset}"
  fi
fi

# --- Line 1: repo / branch + diff ---
LINE1="📁 ${bold}${DIR_NAME}${reset}"
[ -n "$GIT_BRANCH" ] && LINE1="${LINE1}  🌿 ${bold}${GIT_BRANCH}${reset}${GIT_DIFF_STR}"

# --- Line 2: model, effort, context, usage ---
ctx_color=$(color_for_pct "$ctx_percentage")

# Effort level: env var > user settings > (unknown)
EFFORT_LEVEL="${CLAUDE_CODE_EFFORT_LEVEL:-}"
if [ -z "$EFFORT_LEVEL" ] && [ -f "$HOME/.claude/settings.json" ]; then
  EFFORT_LEVEL=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi

EFFORT_STR=""
if [ -n "$EFFORT_LEVEL" ]; then
  case "$EFFORT_LEVEL" in
    low)    effort_color="$green" ;;
    medium) effort_color="$cyan" ;;
    high)   effort_color="$yellow" ;;
    xhigh)  effort_color="$red" ;;
    *)      effort_color="$dim" ;;
  esac
  EFFORT_STR="  ⚡ ${effort_color}${EFFORT_LEVEL}${reset}"
fi

LINE_INFO="🤖 ${dim}${MODEL_DISPLAY}${reset}${EFFORT_STR}  ${ctx_color}${current_fmt}/${total_fmt} (${ctx_percentage}%)${reset}"

# --- Lines 3-4: API Usage (5h / 7d) with caching ---
CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_TTL=360

fetch_usage() {
  local token
  token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty')
  [ -z "$token" ] && return 1

  local response
  response=$(curl -s --max-time 5 \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "User-Agent: claude-code/2.1.69" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

  # Check for error
  if echo "$response" | jq -e '.error' &>/dev/null; then
    return 1
  fi

  # Save cache with timestamp
  echo "$response" | jq --arg ts "$(date +%s)" '. + {cached_at: ($ts | tonumber)}' > "$CACHE_FILE" 2>/dev/null
  return 0
}

get_usage() {
  local now
  now=$(date +%s)

  # Check cache
  if [ -f "$CACHE_FILE" ]; then
    local cached_at
    cached_at=$(jq -r '.cached_at // 0' "$CACHE_FILE" 2>/dev/null)
    local age=$(( now - cached_at ))
    if [ "$age" -lt "$CACHE_TTL" ]; then
      cat "$CACHE_FILE"
      return 0
    fi
  fi

  # Fetch in background to avoid blocking statusline
  fetch_usage &
  # Return cached data if available (even if stale)
  if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    return 0
  fi
  return 1
}

# Parse ISO 8601 datetime to epoch
parse_iso_date() {
  local iso_str="$1"
  local cleaned="${iso_str%%.*}"
  date -j -f "%Y-%m-%dT%H:%M:%S%z" "${cleaned}+0000" "+%s" 2>/dev/null || \
  date -j -f "%Y-%m-%dT%H:%M:%S" "$cleaned" "+%s" 2>/dev/null || echo ""
}

format_reset_time() {
  local reset_at=$1
  local now
  now=$(date +%s)
  local diff=$(( reset_at - now ))

  if [ "$diff" -le 0 ]; then
    echo "now"
    return
  fi

  if [ "$diff" -lt 3600 ]; then
    echo "$((diff / 60))m"
  elif [ "$diff" -lt 86400 ]; then
    local h=$((diff / 3600))
    local m=$(( (diff % 3600) / 60 ))
    echo "${h}h${m}m"
  else
    date -r "$reset_at" "+%b %-d at %-I%p"
  fi
}

LINE2=""

usage_data=$(get_usage)
if [ -n "$usage_data" ] && [ "$usage_data" != "null" ]; then
  five_hour_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0 | floor')
  five_hour_reset=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')
  seven_day_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0 | floor')
  seven_day_reset=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')

  five_color=$(color_for_pct "$five_hour_pct")
  seven_color=$(color_for_pct "$seven_day_pct")

  five_reset_str=""
  if [ -n "$five_hour_reset" ]; then
    five_reset_ts=$(parse_iso_date "$five_hour_reset")
    [ -n "$five_reset_ts" ] && five_reset_str="${dim}↻$(format_reset_time "$five_reset_ts")${reset}"
  fi

  seven_reset_str=""
  if [ -n "$seven_day_reset" ]; then
    seven_reset_ts=$(parse_iso_date "$seven_day_reset")
    [ -n "$seven_reset_ts" ] && seven_reset_str="${dim}↻$(format_reset_time "$seven_reset_ts")${reset}"
  fi

  LINE_INFO="${LINE_INFO}  ⏳ ${dim}5h${reset} ${five_color}${five_hour_pct}%${reset} ${five_reset_str} ${dim}│${reset} 📅 ${dim}7d${reset} ${seven_color}${seven_day_pct}%${reset} ${seven_reset_str}"
fi

# Output
echo -e "$LINE1"
echo -e "$LINE_INFO"
