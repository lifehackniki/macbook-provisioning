#!/usr/bin/env bash
# Claude Code / Codex の「使用量（レート上限に対する％）」を tmux ステータス用に1行で出力する。
#   claude[⏳NN% 📅NN% 🎯NN%]   Claude Code: ⏳5時間枠 / 📅週(全体) / 🎯週(スコープ上限)
#   codex[⏳NN% 📅NN%]          Codex: ⏳5時間枠 / 📅週
#
# データ源:
#   Claude … OAuth usage API (api.anthropic.com/api/oauth/usage) が各上限の percent を返す
#   Codex  … ~/.codex/sessions の token_count イベントに rate_limits.*.used_percent がある
# ネットワーク/ログ走査は重いので、キャッシュ + バックグラウンド更新でステータス描画を止めない。

CACHE="${TMPDIR:-/tmp}/tmux-usage.cache"
LOCK="${TMPDIR:-/tmp}/tmux-usage.lock"
TTL=60  # キャッシュ有効秒数

refresh() {
  mkdir "$LOCK" 2>/dev/null || return          # 二重起動防止（mkdirはアトミック）
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT

  # --- Claude Code ---
  local cc="" tok j
  tok=$(jq -r '.claudeAiOauth.accessToken // empty' ~/.claude/.credentials.json 2>/dev/null)
  [ -z "$tok" ] && tok=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
                          | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
  if [ -n "$tok" ]; then
    j=$(curl -s --max-time 8 https://api.anthropic.com/api/oauth/usage \
          -H "Authorization: Bearer $tok" \
          -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)
    cc=$(printf '%s' "$j" | jq -r '
      def p(k): ([.limits[] | select(.kind==k) | .percent] | first) // null;
      def f(v): if v==null then "-" else (v|round|tostring)+"%" end;
      "claude[⏳\(f(p("session"))) 📅\(f(p("weekly_all"))) 🎯\(f(p("weekly_scoped")))]"
    ' 2>/dev/null)
  fi

  # --- Codex ---（複数セッションから最も新しい rate_limits を採用）
  local cx="" line
  line=$(for fp in $(ls -t ~/.codex/sessions/*/*/*/*.jsonl 2>/dev/null | head -12); do
           grep -h "rate_limits" "$fp" 2>/dev/null | tail -1
         done | jq -s 'map(select(.payload.rate_limits)) | sort_by(.timestamp) | last' 2>/dev/null)
  if [ -n "$line" ] && [ "$line" != "null" ]; then
    cx=$(printf '%s' "$line" | jq -r '
      .payload.rate_limits as $r |
      def f(v): if v==null then "-" else (v|round|tostring)+"%" end;
      "codex[⏳\(f($r.primary.used_percent)) 📅\(f($r.secondary.used_percent))]"
    ' 2>/dev/null)
  fi

  local out=""
  [ -n "$cc" ] && out="$cc"
  [ -n "$cx" ] && { [ -n "$out" ] && out+="  "; out+="$cx"; }
  [ -n "$out" ] && printf '%s' "$out" > "$CACHE"
}

# キャッシュが無い or 古ければ裏で更新（結果は次回描画で反映）
if [ ! -f "$CACHE" ] || [ "$(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || echo 0) ))" -ge "$TTL" ]; then
  refresh >/dev/null 2>&1 &
fi

# 今あるキャッシュを即返す（無ければ準備中表示）
if [ -f "$CACHE" ]; then cat "$CACHE"; else printf 'usage…'; fi
