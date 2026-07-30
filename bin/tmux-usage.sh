#!/usr/bin/env bash
# Claude Code / Codex の「使用量（レート上限に対する％）」を tmux ステータス用に1行で出力する。
#   🟠[⏳NN% 📅NN% 🎯NN% account]   Claude Code(🟠): ⏳5時間枠 / 📅週(全体) / 🎯週(スコープ上限) / アカウント(@前のみ)
#   🔵[⏳NN% 📅NN% account]         Codex(🔵): ⏳5時間枠 / 📅週 / アカウント(@前のみ)
# 記号は文字に見えない色付き絵文字（数字色と対応）。[]・アカウント名は白。
# ％数字だけをツール色（Claude橙 / Codex青）＋太字にして、数字の色でどちらのツールかが分かるようにする。
# tmuxの #[] スタイルを直接出力する。
#
# データ源:
#   Claude … OAuth usage API (api.anthropic.com/api/oauth/usage) が各上限の percent を返す
#   Codex  … ~/.codex/sessions の token_count イベントに rate_limits.*.used_percent がある
# ネットワーク/ログ走査は重いので、キャッシュ + バックグラウンド更新でステータス描画を止めない。

CACHE="${TMPDIR:-/tmp}/tmux-usage.cache"
CACHE_CC="${TMPDIR:-/tmp}/tmux-usage.claude"   # Claude の行だけを別に保持する（後述の理由）
CACHE_CX="${TMPDIR:-/tmp}/tmux-usage.codex"
LOCK="${TMPDIR:-/tmp}/tmux-usage.lock"
LOCK_STALE=120 # ロックがこの秒数以上残っていたら異常終了とみなして除去（更新の空回り防止）
# usage API はレート制限が厳しいが、更新はロック＋共有キャッシュで全ペイン合わせて
# 1プロセスに束ねてあるため、60秒でもリクエストは最大1回/分に収まり実用上429には当たらない。
TTL=60

claude_bin() {
  if [ -x "$HOME/.local/bin/claude" ]; then
    printf '%s\n' "$HOME/.local/bin/claude"
  else
    command -v claude 2>/dev/null
  fi
}

claude_email() {
  local cmd email
  cmd=$(claude_bin) || return 0
  email=$(CMUX_CLAUDE_HOOKS_DISABLED=1 "$cmd" auth status 2>/dev/null | jq -r '.email // empty' 2>/dev/null)
  [ -n "$email" ] && printf '%s\n' "$email"
}

# Codex のアカウント識別子: ~/.codex/auth.json の id_token(JWT) の email クレームから取る
codex_email() {
  local p
  p=$(jq -r '.tokens.id_token // empty' ~/.codex/auth.json 2>/dev/null | cut -d. -f2 | tr '_-' '/+')
  [ -z "$p" ] && return 0
  case $(( ${#p} % 4 )) in 2) p="${p}==" ;; 3) p="${p}=" ;; esac
  printf '%s' "$p" | base64 -D 2>/dev/null | jq -r '.email // empty' 2>/dev/null
}

refresh() {
  # 二重起動防止（mkdirはアトミック）。古いロックは異常終了の残骸として破棄する。
  if ! mkdir "$LOCK" 2>/dev/null; then
    local lock_mtime lock_age
    lock_mtime=$(stat -f %m "$LOCK" 2>/dev/null || echo 0)
    lock_age=$(( $(date +%s) - lock_mtime ))
    if [ "$lock_age" -lt "$LOCK_STALE" ] || ! rmdir "$LOCK" 2>/dev/null; then
      return
    fi
    mkdir "$LOCK" 2>/dev/null || return
  fi
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT

  # --- Claude Code ---
  # percent が取れたときだけ CACHE_CC を書き換える。レート制限や失効トークンで API が
  # error を返したときに「email だけの行」で上書きすると、次に成功するまで％が消えたままになる。
  local cc="" cc_email tok j
  cc_email=$(claude_email)
  tok=$(jq -r '.claudeAiOauth.accessToken // empty' ~/.claude/.credentials.json 2>/dev/null)
  [ -z "$tok" ] && tok=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
                          | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
  if [ -n "$tok" ]; then
    j=$(curl -s --max-time 8 https://api.anthropic.com/api/oauth/usage \
          -H "Authorization: Bearer $tok" \
          -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)
    # limits[] が本命。旧レスポンス互換で five_hour/seven_day にもフォールバックする。
    cc=$(printf '%s' "$j" | jq -r '
      if (.error != null) then empty else
        def p(k): ([.limits[]? | select(.kind==k) | .percent] | first);
        def f(v): if v==null then "#[fg=#6c7086]-#[fg=#cdd6f4]"
          else ((v|round) as $n |
            "#[fg=#fab387,bold]" + ($n|tostring) + "%#[fg=#cdd6f4,nobold]") end;
        (p("session")     // .five_hour.utilization) as $s |
        (p("weekly_all")  // .seven_day.utilization) as $w |
        p("weekly_scoped") as $g |
        if ($s == null and $w == null and $g == null) then empty else
          "⏳\(f($s)) 📅\(f($w)) 🎯\(f($g))"
        end
      end
    ' 2>/dev/null)
  fi
  if [ -n "$cc" ]; then
    # メールは@より前だけ末尾に表示して行を短くする（アカウント判別には十分）
    # 記号・[]・アカウント名は白。ツールの区別は％数字の色（橙）で付く
    printf '%s' "#[fg=#cdd6f4]🟠[${cc}${cc_email:+ ${cc_email%%@*}}]" > "$CACHE_CC"
  fi

  # --- Codex ---（複数セッションから最も新しい rate_limits を採用）
  local cx="" cx_email line
  cx_email=$(codex_email)
  line=$(for fp in $(ls -t ~/.codex/sessions/*/*/*/*.jsonl 2>/dev/null | head -12); do
           grep -h "rate_limits" "$fp" 2>/dev/null | tail -1
         done | jq -s 'map(select(.payload.rate_limits)) | sort_by(.timestamp) | last' 2>/dev/null)
  if [ -n "$line" ] && [ "$line" != "null" ]; then
    cx=$(printf '%s' "$line" | jq -r '
      .payload.rate_limits as $r |
      def f(v): if v==null then "#[fg=#6c7086]-#[fg=#cdd6f4]"
        else ((v|round) as $n |
          "#[fg=#89b4fa,bold]" + ($n|tostring) + "%#[fg=#cdd6f4,nobold]") end;
      "⏳\(f($r.primary.used_percent)) 📅\(f($r.secondary.used_percent))"
    ' 2>/dev/null)
    [ -n "$cx" ] && printf '%s' "#[fg=#cdd6f4]🔵[${cx}${cx_email:+ ${cx_email%%@*}}]" > "$CACHE_CX"
  fi

  # 表示行は「今ある分」を組み立てる（片方の取得に失敗しても、もう片方は前回値で残る）
  local out=""
  [ -f "$CACHE_CC" ] && out=$(cat "$CACHE_CC")
  if [ -f "$CACHE_CX" ]; then
    [ -n "$out" ] && out+="  "
    out+=$(cat "$CACHE_CX")
  fi
  [ -n "$out" ] && printf '%s' "$out" > "$CACHE"

  # 更新が終わったら描画を促す（次のstatus-intervalを待たずに新しい値を反映させる）
  if command -v tmux >/dev/null 2>&1; then
    tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r c; do
      tmux refresh-client -t "$c" 2>/dev/null
    done
  fi
}

# 前回の更新プロセスが異常終了してロックが残っていたら除去（放置すると更新が永久に空回りする）
if [ -d "$LOCK" ] && [ "$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))" -ge "$LOCK_STALE" ]; then
  rmdir "$LOCK" 2>/dev/null
fi

# キャッシュが無い or 古ければ裏で更新（結果は次回描画で反映）
if [ ! -f "$CACHE" ] || [ "$(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || echo 0) ))" -ge "$TTL" ]; then
  refresh >/dev/null 2>&1 &
fi

# 今あるキャッシュを即返す（無ければ準備中表示）
if [ -f "$CACHE" ]; then cat "$CACHE"; else printf 'usage…'; fi
