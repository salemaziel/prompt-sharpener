#!/usr/bin/env bash
# Prompt Sharpener hook. Reads the hook's JSON on stdin and prints the rules this
# prompt needs. Claude Code and Codex run it on UserPromptSubmit, Antigravity on
# BeforeAgent; `sharpen.sh reset` runs on SessionStart after a compact or clear.
#
# What it prints:
#   - the mode's full rules once per session (again every `full_every` prompts,
#     after a compact/clear, or when the mode changes), else a one-line reminder;
#   - a per-prompt line when this prompt needs less than a full rewrite:
#     ground-only for slash commands, short acknowledgements and automated
#     messages; a one-line "Taking this as" for prompts that are already detailed.
#
# Settings, highest first: PROMPT_SHARPENER_MODE, then the project's
# .claude/prompt-sharpener.local.md (CLAUDE_PROJECT_DIR, else the hook's cwd), then
# ~/.claude/prompt-sharpener.local.md (YAML frontmatter: mode, detail_words, full_every).
# A project file can't set `off`; it gets `ground`, so a cloned repo can't drop grounding.
#
# Any failure prints the full rules, as the old `cat rules.txt` hook did.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input="$(cat)"

# JSON string body for plain ASCII text (the rules files are ASCII-only).
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"; s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

# Prints text the way the calling host expects: JSON for Antigravity, plain for the rest.
emit() {
  local text="$1" event_re='"hook_event_name"[[:space:]]*:[[:space:]]*"BeforeAgent"'
  if [[ "$input" =~ $event_re ]]; then
    if [[ -n "$text" ]]; then
      printf '{"hookSpecificOutput":{"hookEventName":"BeforeAgent","additionalContext":"%s"}}\n' "$(json_escape "$text")"
    else
      echo '{}'
    fi
  elif [[ -n "$text" ]]; then
    printf '%s\n' "$text"
  fi
}

fallback() { emit "$(cat "$here/rules.txt")"; exit 0; }

if [[ -n "${PROMPT_SHARPENER_STATE_DIR:-}" ]]; then state_dir="$PROMPT_SHARPENER_STATE_DIR"
elif [[ -n "${XDG_STATE_HOME:-}" ]]; then state_dir="$XDG_STATE_HOME/prompt-sharpener"
elif [[ -n "${HOME:-}" ]]; then state_dir="$HOME/.local/state/prompt-sharpener"
else state_dir=""
fi
sid_re='^[A-Za-z0-9_-]{1,128}$'

line_ground="Prompt Sharpener: no rewrite for this prompt (a command, a short reply or an automated message). Still ground any outside fact quietly."
line_detailed='Prompt Sharpener: this prompt is already detailed, so use the one-line "Taking this as: ..." form instead of a rewrite block, then do the task. Ground outside facts quietly.'
line_brief='Prompt Sharpener (brief mode): start with one line "Taking this as: ...", then do the task. Ground outside facts quietly.'
line_full="Prompt Sharpener: rewrite block and Assumptions line first, then the task; ground outside facts quietly (full rules given earlier in this session)."
line_ground_mode="Prompt Sharpener (ground mode): no rewrite; ground outside facts quietly (rules given earlier in this session)."

# Reads one key from a settings file's YAML frontmatter.
frontmatter_value() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  awk -v key="$key" '
    NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR > 1 && /^---[[:space:]]*$/ { exit }
    NR > 1 {
      if (match($0, "^" key ":[[:space:]]*")) {
        v = substr($0, RLENGTH + 1)
        sub(/[[:space:]]+#.*$/, "", v); gsub(/^["'\'']|["'\'']$/, "", v); sub(/[[:space:]]+$/, "", v)
        print v; exit
      }
    }' "$file"
}

# Echoes a setting from the project file, then the user file; nothing if neither has it.
# With `user`, skips the project file.
setting() {
  local key="$1" v=""
  [[ "${2:-}" != user && -n "$project_dir" ]] && v="$(frontmatter_value "$project_dir/.claude/prompt-sharpener.local.md" "$key")"
  [[ -z "$v" && -n "${HOME:-}" ]] && v="$(frontmatter_value "$HOME/.claude/prompt-sharpener.local.md" "$key")"
  echo "$v"
}

# Echoes a whole-number setting, or the default if it isn't one.
number_setting() {
  local v; v="$(setting "$1")"
  if [[ "$v" =~ ^[0-9]{1,6}$ ]]; then echo $((10#$v)); else echo "$2"; fi
}

# Echoes ground, detailed or normal for the prompt text.
classify() {
  local text="$1" detail_words="$2"
  # Pasted blocks don't count: "fix this" plus a paste is still a thin prompt.
  text="$(awk '/^<pasted_content id=/ { skip = 1; next } /^<\/pasted_content id=/ { skip = 0; next } !skip' <<<"$text")"
  local trimmed
  trimmed="$(awk 'started { print; next } /[^[:space:]]/ { sub(/^[[:space:]]+/, ""); started = 1; print }' <<<"$text")"

  # Automated input: subagent and background-task reports, teammate and system messages.
  # They may come after a "[SYSTEM NOTIFICATION ...]" preamble, so also check line starts.
  local nl=$'\n' head="${trimmed:0:500}"
  local auto_re='^<(task-notification|teammate-message|system-reminder|local-command-[a-z]+|command-name|command-message|bash-input|bash-stdout|fork-boilerplate)[[:space:]>]'
  local auto_line_re="${nl}<(task-notification|teammate-message)[[:space:]>]"
  if [[ "$trimmed" =~ $auto_re || "$trimmed" == "[SYSTEM NOTIFICATION"* || "$head" =~ $auto_line_re ]]; then
    echo ground; return
  fi
  # Slash commands, as typed: /name or /plugin:name, then a space or the end.
  # "/tmp is full" names a path, not a command.
  local first="${trimmed%%[[:space:]]*}"
  if [[ "$first" =~ ^/[A-Za-z][A-Za-z0-9_.:-]*$ && ! -e "$first" ]]; then
    echo ground; return
  fi
  # Short replies made only of acknowledgement words, or a menu pick like "2" or "b".
  local lower words
  lower="$(tr '[:upper:]' '[:lower:]' <<<"${trimmed:0:200}" | tr -c 'a-z0-9\n' ' ')"
  read -r -a words <<<"$(tr '\n' ' ' <<<"$lower")"
  if (( ${#words[@]} == 0 )); then echo ground; return; fi
  if (( ${#words[@]} == 1 )) && [[ "${words[0]}" =~ ^([0-9]{1,2}|[a-d])$ ]]; then echo ground; return; fi
  if (( ${#words[@]} <= 4 )) && [[ "${#trimmed}" -le 200 ]]; then
    local w ack=1
    for w in "${words[@]}"; do
      case "$w" in
        y|yes|yep|yeah|yup|ok|okay|k|sure|continue|go|ahead|on|proceed|do|it|lgtm|sounds|good|great|perfect|cool|nice|thanks|thank|you|ty|no|nope|n|stop|next|done|approve|approved|ship|please|pls|keep|going) ;;
        *) ack=0; break ;;
      esac
    done
    (( ack )) && { echo ground; return; }
  fi
  # Already detailed: long and structured (several lines, a list or a code block).
  local nwords nlines
  nwords="$(wc -w <<<"$text")"
  nlines="$(grep -c '[^[:space:]]' <<<"$text")"
  if (( nwords >= detail_words )) && { (( nlines >= 3 )) || grep -qE '^[[:space:]]*([-*]|[0-9]+[.)])[[:space:]]|```' <<<"$text"; }; then
    echo detailed; return
  fi
  echo normal
}

reset_session() {
  local sid
  sid="$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)" || exit 0
  [[ -n "$state_dir" && "$sid" =~ $sid_re ]] && rm -f "$state_dir/session-$sid"
  exit 0
}

main() {
  command -v jq >/dev/null || return 1
  local event prompt has_prompt sid cwd
  event="$(jq -r '.hook_event_name // "UserPromptSubmit"' <<<"$input" 2>/dev/null)" || return 1
  has_prompt="$(jq -r 'has("prompt")' <<<"$input" 2>/dev/null)" || return 1
  # Classification only needs the start of a prompt; capping keeps huge pastes fast.
  prompt="$(jq -r '(.prompt // "") | tostring | .[0:20000]' <<<"$input" 2>/dev/null)" || return 1
  sid="$(jq -r '.session_id // ""' <<<"$input" 2>/dev/null)" || return 1
  cwd="$(jq -r '.cwd // ""' <<<"$input" 2>/dev/null)" || return 1
  project_dir="${CLAUDE_PROJECT_DIR:-$cwd}"

  local mode detail_words full_every
  mode="${PROMPT_SHARPENER_MODE:-}"
  if [[ -z "$mode" ]]; then
    mode="$(setting mode)"
    # Only the user (env var or user file) can turn grounding off.
    [[ "$mode" == off && "$(setting mode user)" != off ]] && mode=ground
  fi
  [[ "$mode" =~ ^(full|brief|ground|off)$ ]] || mode=full
  detail_words="$(number_setting detail_words 80)"
  full_every="$(number_setting full_every 25)"

  # No prompt field means an input shape this script doesn't know: send the full rules.
  local class=normal
  [[ "$mode" != off && "$has_prompt" == true ]] && class="$(classify "$prompt" "$detail_words")"

  # The per-prompt line, when this prompt differs from the mode's standing rules.
  local extra=""
  case "$mode:$class" in
    off:*|ground:*|*:normal) ;;
    *:ground) extra="$line_ground" ;;
    full:detailed) extra="$line_detailed" ;;
  esac
  local rules_file="$here/rules.txt" reminder="$line_full"
  case "$mode" in
    brief) rules_file="$here/rules-brief.txt"; reminder="$line_brief" ;;
    ground) rules_file="$here/rules-ground.txt"; reminder="$line_ground_mode" ;;
  esac

  # Full rules or a reminder. Antigravity adds hook context to one turn only, so it
  # always gets the full rules; elsewhere the context stays in the conversation.
  local send_full=1 marker="" count=0 last_mode=""
  if [[ "$mode" != off && "$event" != BeforeAgent && -n "$state_dir" && "$sid" =~ $sid_re ]]; then
    marker="$state_dir/session-$sid"
    if [[ -f "$marker" ]]; then
      read -r last_mode count <"$marker" || true
      [[ "$count" =~ ^[0-9]{1,6}$ ]] && count=$((10#$count)) || count=0
      if [[ "$last_mode" == "$mode" ]] && (( full_every == 0 || count < full_every )); then
        send_full=0
      fi
    fi
  fi

  local out=""
  if [[ "$mode" != off ]]; then
    if (( send_full )); then
      out="$(cat "$rules_file")" || return 1
      [[ -n "$extra" ]] && out+=$'\n'"For this prompt: $extra"
    else
      out="${extra:-$reminder}"
    fi
  fi

  if [[ -n "$marker" ]] && mkdir -p "$state_dir" 2>/dev/null; then
    if (( send_full )); then
      echo "$mode 1" 2>/dev/null >"$marker"
      find "$state_dir" -maxdepth 1 -type f -name 'session-*' -mtime +7 -delete 2>/dev/null
    else
      echo "$mode $((count + 1))" 2>/dev/null >"$marker"
    fi
  fi

  if [[ -n "${PROMPT_SHARPENER_DEBUG_LOG:-}" ]]; then
    printf '%s\t%s\t%s\t%s\tfull=%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$event" "$mode" "$class" "$send_full" \
      "$(tr '\n\t' '  ' <<<"${prompt:0:80}")" 2>/dev/null >>"$PROMPT_SHARPENER_DEBUG_LOG"
  fi
  printf '%s' "$out"
}

[[ "${1:-}" == reset ]] && reset_session
result="$(main)" || fallback
emit "$result"
exit 0
