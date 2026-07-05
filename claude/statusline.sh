#!/usr/bin/env bash

input=$(cat)

MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
DIR_NAME="${CURRENT_DIR##*/}"

GIT_BRANCH=""
if git rev-parse &>/dev/null; then
  BRANCH=$(git branch --show-current)
  if [ -n "$BRANCH" ]; then
    GIT_BRANCH="$BRANCH"
  else
    GIT_BRANCH="$(git rev-parse --short HEAD 2>/dev/null)"
  fi
fi

CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
USAGE=$(echo "$input" | jq '.context_window.current_usage // null')
if [ "$USAGE" != "null" ]; then
  current_tokens=$(echo "$USAGE" | jq '(.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)')
else
  current_tokens=0
fi
ctx_percentage=$((current_tokens * 100 / CONTEXT_SIZE))

reset="\033[0m"
dim="\033[2m"
bold="\033[1m"
# 役割ごとに色を割り当て、要素を色で判別できるようにする（256色）
red="\033[38;5;203m"       # 危険値・削除行
yellow="\033[38;5;214m"    # 警告値
green="\033[38;5;114m"     # 正常値・追加行
cyan="\033[38;5;81m"       # ctx ラベル
orange="\033[38;5;208m"    # ディレクトリ名
blue="\033[38;5;75m"       # 5h ラベル
violet="\033[38;5;141m"    # 7d ラベル・ホストラベル
pink="\033[38;5;205m"      # Fable ラベル
teal="\033[38;5;43m"       # git ブランチ

color_for_pct() {
  local pct=$1
  if [ "$pct" -ge 80 ]; then echo "$red"
  elif [ "$pct" -ge 50 ]; then echo "$yellow"
  else echo "$green"; fi
}

# Visible length (ANSI 除去)。マルチバイトは wc -m 換算。
vlen() {
  local s
  s=$(echo -en "$1" | sed $'s/\033\\[[0-9;]*m//g')
  echo -n "$s" | wc -m | tr -d ' '
}

# 端末幅: JSON > tput > 120
TERM_WIDTH=$(echo "$input" | jq -r '.terminal.width // .terminal.columns // empty' 2>/dev/null)
[ -z "$TERM_WIDTH" ] && TERM_WIDTH=$(tput cols 2>/dev/null || echo 120)
# プロンプト表示分のマージン
BUDGET=$(( TERM_WIDTH - 4 ))

# 区切り
SEP=" ${dim}·${reset} "
SEP_W=3

# ----- Line 1 segments: [host, dir, branch, diff] -----
# zshプロンプトと同じホスト判定（絵文字 + 略称ラベル）
HOST_LC=$(hostname | tr '[:upper:]' '[:lower:]')
case "$HOST_LC" in
  *macbook*|*mba*|*air*)       HOST_SEG="${bold}${violet}MBA${reset} 💻" ;;
  *macmini*|*mac-mini*|*mini*) HOST_SEG="${bold}${violet}Mini${reset} 🖥️" ;;
  *)                           HOST_SEG="${bold}${violet}${HOST_LC}${reset}" ;;
esac

SEG1_DIR="${bold}${orange}${DIR_NAME}${reset}"
SEG1_BRANCH=""
[ -n "$GIT_BRANCH" ] && SEG1_BRANCH="${teal}${GIT_BRANCH}${reset}"

SEG1_DIFF=""
if [ -n "$GIT_BRANCH" ] && git rev-parse &>/dev/null; then
  diff_stat=$(git diff main --shortstat 2>/dev/null)
  if [ -n "$diff_stat" ]; then
    insertions=$(echo "$diff_stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
    deletions=$(echo "$diff_stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')
    [ -z "$insertions" ] && insertions=0
    [ -z "$deletions" ] && deletions=0
    SEG1_DIFF="${green}+${insertions}${reset}${dim}/${reset}${red}-${deletions}${reset}"
  fi
fi

# 貪欲に組み立て（host + dir 必須、以降は budget 内で追加）
LINE1="${HOST_SEG} ${SEG1_DIR}"
LINE1_LEN=$(vlen "$LINE1")

try_append() {
  local seg="$1"
  [ -z "$seg" ] && return
  local seg_len
  seg_len=$(vlen "$seg")
  local need=$(( seg_len + SEP_W ))
  if [ $(( LINE1_LEN + need )) -le "$BUDGET" ]; then
    LINE1="${LINE1}${SEP}${seg}"
    LINE1_LEN=$(( LINE1_LEN + need ))
  fi
}
try_append "$SEG1_BRANCH"
try_append "$SEG1_DIFF"

# ----- Line 2 segments: [ctx, effort, 5h, 7d] -----
ctx_color=$(color_for_pct "$ctx_percentage")
fmt_t() {
  local t=$1
  if [ "$t" -ge 1000 ]; then echo "$((t/1000))k"; else echo "$t"; fi
}
SEG2_CTX="${cyan}ctx${reset} ${ctx_color}${ctx_percentage}%${reset}${dim} ($(fmt_t $current_tokens))${reset}"

EFFORT_LEVEL="${CLAUDE_CODE_EFFORT_LEVEL:-}"
if [ -z "$EFFORT_LEVEL" ] && [ -f "$HOME/.claude/settings.json" ]; then
  EFFORT_LEVEL=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi
SEG2_EFFORT=""
if [ -n "$EFFORT_LEVEL" ]; then
  case "$EFFORT_LEVEL" in
    low)    effort_color="$green" ;;
    medium) effort_color="$cyan" ;;
    high)   effort_color="$yellow" ;;
    xhigh)  effort_color="$red" ;;
    *)      effort_color="$dim" ;;
  esac
  SEG2_EFFORT="${effort_color}${EFFORT_LEVEL}${reset}"
fi

# ----- API usage (cached) -----
CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_TTL=360

fetch_usage() {
  local token
  token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty')
  [ -z "$token" ] && token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)
  [ -z "$token" ] && return 1
  local response
  response=$(curl -s --max-time 5 \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "User-Agent: claude-code/2.1.69" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
  if echo "$response" | jq -e '.error' &>/dev/null; then
    return 1
  fi
  echo "$response" | jq --arg ts "$(date +%s)" '. + {cached_at: ($ts | tonumber)}' > "$CACHE_FILE" 2>/dev/null
  return 0
}

get_usage() {
  local now
  now=$(date +%s)
  if [ -f "$CACHE_FILE" ]; then
    local cached_at
    cached_at=$(jq -r '.cached_at // 0' "$CACHE_FILE" 2>/dev/null)
    local age=$(( now - cached_at ))
    if [ "$age" -lt "$CACHE_TTL" ]; then
      cat "$CACHE_FILE"
      return 0
    fi
  fi
  fetch_usage &
  if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    return 0
  fi
  return 1
}

SEG2_5H=""
SEG2_7D=""
SEG2_FABLE=""
usage_data=$(get_usage)
if [ -n "$usage_data" ] && [ "$usage_data" != "null" ]; then
  five_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0 | floor')
  seven_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0 | floor')
  five_color=$(color_for_pct "$five_pct")
  seven_color=$(color_for_pct "$seven_pct")
  SEG2_5H="${blue}5h${reset} ${five_color}${five_pct}%${reset}"
  SEG2_7D="${violet}7d${reset} ${seven_color}${seven_pct}%${reset}"
  # モデル別週次上限（Fable など weekly_scoped）
  fable_pct=$(echo "$usage_data" | jq -r '[.limits[]? | select(.kind == "weekly_scoped").percent][0] // empty')
  if [ -n "$fable_pct" ]; then
    fable_color=$(color_for_pct "$fable_pct")
    SEG2_FABLE="${pink}F${reset} ${fable_color}${fable_pct}%${reset}"
  fi
fi

# 貪欲に組み立て（ctx 必須、effort > 5h > 7d の順で追加）
LINE2="$SEG2_CTX"
LINE2_LEN=$(vlen "$SEG2_CTX")

try_append2() {
  local seg="$1"
  [ -z "$seg" ] && return
  local seg_len
  seg_len=$(vlen "$seg")
  local need=$(( seg_len + SEP_W ))
  if [ $(( LINE2_LEN + need )) -le "$BUDGET" ]; then
    LINE2="${LINE2}${SEP}${seg}"
    LINE2_LEN=$(( LINE2_LEN + need ))
  fi
}
try_append2 "$SEG2_EFFORT"
try_append2 "$SEG2_5H"
try_append2 "$SEG2_7D"
try_append2 "$SEG2_FABLE"

echo -e "$LINE1"
echo -e "$LINE2"
