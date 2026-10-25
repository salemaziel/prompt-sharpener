#!/usr/bin/env bash
# Prompt Sharpener hook. Reads the hook's JSON on stdin and prints the rules this
# prompt needs. Claude Code and Codex run it on UserPromptSubmit (hooks/hooks.json),
# Antigravity (agy) on PreInvocation (the root hooks.json), Gemini CLI on BeforeAgent
# (untested); `sharpen.sh reset` runs on SessionStart after a compact or clear.
#
# What it prints:
#   - the mode's full rules once per session (again every `full_every` prompts,
#     after a compact/clear, or when the mode changes), else a one-line reminder;
#   - a per-prompt line when this prompt needs less than a full rewrite:
#     ground-only for slash commands, short acknowledgements and automated
#     messages; a one-line "Taking this as" for prompts that are already detailed;
#   - one "now off" line when the mode changes to off mid-session.
#
# Settings, highest first: PROMPT_SHARPENER_MODE, then the project's
# .claude/prompt-sharpener.local.md, then ~/.claude/prompt-sharpener.local.md (YAML
# frontmatter: mode, detail_words, full_every). The project is CLAUDE_PROJECT_DIR, else
# the git root of the hook's working directory, else that directory. A project file
# can't set `off`; it gets `ground`, so a cloned repo can't drop grounding.
#
# Any failure prints the full rules, as the old `cat rules.txt` hook did.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input="$(cat)"

# The calling host. agy's hooks.json says so (`sharpen.sh agy`); the others share
# hooks/hooks.json, so they're told apart by the shape of their JSON. Quotes inside a
# prompt are escaped, so a prompt that mentions these keys can't match.
if [[ "${1:-}" == agy ]]; then host=agy
elif [[ "$input" =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"BeforeAgent\" ]]; then host=gemini
elif [[ "$input" =~ \"turn_id\"[[:space:]]*: ]]; then host=codex
else host=claude
fi

# JSON string body for plain ASCII text (the rules files are ASCII-only).
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"; s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

# Prints text the way the calling host expects: JSON for Gemini CLI and agy, plain
# for the rest. `kind` is session for text that should last the conversation (rules,
# the now-off line) and turn for the rest; `more` is a line for this prompt only.
# agy keeps a systemMessage for the whole conversation and an ephemeralMessage for one
# turn, so each part goes in its own step there; elsewhere they're joined.
emit() {
  local text="$1" kind="${2:-turn}" more="${3:-}" joined="$1" steps=""
  [[ -n "$more" ]] && joined="${joined:+$joined$'\n'}$more"
  case "$host" in
    gemini)
      if [[ -n "$joined" ]]; then
        printf '{"hookSpecificOutput":{"hookEventName":"BeforeAgent","additionalContext":"%s"}}\n' "$(json_escape "$joined")"
      else echo '{}'; fi ;;
    agy)
      if [[ -n "$text" && "$kind" == session ]]; then
        steps="{\"systemMessage\":{\"systemMessage\":\"$(json_escape "$text")\"}}"
      elif [[ -n "$text" ]]; then
        steps="{\"ephemeralMessage\":\"$(json_escape "$text")\"}"
      fi
      [[ -n "$more" ]] && steps="${steps:+$steps,}{\"ephemeralMessage\":\"$(json_escape "$more")\"}"
      if [[ -n "$steps" ]]; then printf '{"injectSteps":[%s]}\n' "$steps"; else echo '{}'; fi ;;
    *) [[ -n "$joined" ]] && printf '%s\n' "$joined" ;;
  esac
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
line_off="Prompt Sharpener is now off: ignore its earlier rules in this session (no rewrite block, no Assumptions line, no Taking-this-as line)."
line_replaces="(These rules replace any earlier Prompt Sharpener rules in this conversation.)"

lower() { tr '[:upper:]' '[:lower:]' <<<"$1"; }

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
  # Slash commands, as typed: /name or /plugin:name, then a space or the end. Codex
  # also invokes skills as $name. "/tmp is full" names a path, not a command.
  local first="${trimmed%%[[:space:]]*}"
  if [[ "$first" =~ ^/[A-Za-z][A-Za-z0-9_.:-]*$ && ! -e "$first" ]] ||
     [[ "$host" == codex && "$first" =~ ^\$[a-z][a-z0-9_-]*(:[a-z0-9_-]+)?$ ]]; then
    echo ground; return
  fi
  # Short replies made only of acknowledgement words, or a menu pick like "2" or "b".
  # Byte-wise from here, for bash and for tr (BSD tr counts characters in a UTF-8
  # locale): UTF-8 punctuation, symbols and emoji (E2 xx xx, F0-F4 xx xx xx) and the
  # no-break space become spaces, so "ok — thanks" is still a short reply; letters
  # from other scripts stay and count as words, so a Russian or Japanese request is
  # never an acknowledgement.
  local LC_ALL=C; export LC_ALL
  local s="${trimmed:0:200}" lower words
  s="${s//$'\xc2\xa0'/ }"
  s="${s//$'\xe2'??/ }"
  s="${s//[$'\xf0'-$'\xf4']???/ }"
  lower="$(tr 'A-Z' 'a-z' <<<"$s" | tr -c 'a-z0-9\n\200-\377' ' ')"
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

# Prints "<kind>\t<text>": kind is session (full rules) or turn (a line).
main() {
  command -v jq >/dev/null || return 1
  local event prompt has_prompt sid cwd
  if [[ "$host" == agy ]]; then
    event=PreInvocation
    has_prompt="$(jq -r 'has("lastUserInput")' <<<"$input" 2>/dev/null)" || return 1
    prompt="$(jq -r '(.lastUserInput // "") | tostring | .[0:20000]' <<<"$input" 2>/dev/null)" || return 1
    sid="$(jq -r '.conversationId // ""' <<<"$input" 2>/dev/null)" || return 1
    cwd="$(jq -r '.workspacePaths[0] // ""' <<<"$input" 2>/dev/null)" || return 1
  else
    event="$(jq -r '.hook_event_name // "UserPromptSubmit"' <<<"$input" 2>/dev/null)" || return 1
    has_prompt="$(jq -r 'has("prompt")' <<<"$input" 2>/dev/null)" || return 1
    # Classification only needs the start of a prompt; capping keeps huge pastes fast.
    prompt="$(jq -r '(.prompt // "") | tostring | .[0:20000]' <<<"$input" 2>/dev/null)" || return 1
    sid="$(jq -r '.session_id // ""' <<<"$input" 2>/dev/null)" || return 1
    cwd="$(jq -r '.cwd // ""' <<<"$input" 2>/dev/null)" || return 1
  fi
  project_dir="${CLAUDE_PROJECT_DIR:-}"
  if [[ -z "$project_dir" && -n "$cwd" ]]; then
    command -v git >/dev/null && project_dir="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
    [[ -n "$project_dir" ]] || project_dir="$cwd"
  fi

  local mode detail_words full_every
  mode="$(lower "${PROMPT_SHARPENER_MODE:-}")"
  if [[ -z "$mode" ]]; then
    mode="$(lower "$(setting mode)")"
    # Only the user (env var or user file) can turn grounding off.
    [[ "$mode" == off && "$(lower "$(setting mode user)")" != off ]] && mode=ground
  fi
  if [[ -n "$mode" && ! "$mode" =~ ^(full|brief|ground|off)$ ]]; then
    echo "prompt-sharpener: unknown mode '$mode'; using full (choose full, brief, ground or off)" >&2
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

  # Full rules or a reminder. Gemini CLI adds hook context to one turn only, so it
  # always gets the full rules; elsewhere the context stays in the conversation.
  local send_full=1 marker="" count=0 last_mode=""
  if [[ "$host" != gemini && -n "$state_dir" && "$sid" =~ $sid_re ]]; then
    marker="$state_dir/session-$sid"
    if [[ -f "$marker" ]]; then
      read -r last_mode count <"$marker" || true
      [[ "$count" =~ ^[0-9]{1,6}$ ]] && count=$((10#$count)) || count=0
      if [[ "$last_mode" == "$mode" ]] && (( full_every == 0 || count < full_every )); then
        send_full=0
      fi
    fi
  fi

  # Off: nothing, except one line when earlier rules in this session are still in context.
  # The rules last the conversation (kind session) when they're new or the mode changed;
  # the every-`full_every` resend is for one turn, so agy doesn't pile up copies.
  local out="" kind=turn more=""
  if [[ "$mode" == off ]]; then
    send_full=0
    [[ -n "$last_mode" && "$last_mode" != off ]] && { out="$line_off"; kind=session; }
  elif (( send_full )); then
    out="$(cat "$rules_file")" || return 1
    [[ -n "$last_mode" && "$last_mode" != "$mode" ]] && out+=$'\n'"$line_replaces"
    [[ "$last_mode" != "$mode" ]] && kind=session
    [[ -n "$extra" ]] && more="For this prompt: $extra"
  else
    out="${extra:-$reminder}"
  fi

  if [[ -n "$marker" ]] && mkdir -p "$state_dir" 2>/dev/null; then
    if [[ "$mode" == off ]]; then
      # Remember off only for a session that had rules, so turning on again re-sends them.
      [[ -n "$last_mode" ]] && echo "off 0" 2>/dev/null >"$marker"
    elif (( send_full )); then
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
  printf '%s\t%s\t%s' "$kind" "$more" "$out"
}

[[ "${1:-}" == reset ]] && reset_session
# agy runs PreInvocation before every model call; invocationNum is 0 on the first call of
# a user turn. Later calls in the turn, and SessionStart (no invocationNum), get nothing.
if [[ "$host" == agy && ! "$input" =~ \"invocationNum\"[[:space:]]*:[[:space:]]*0[^0-9] ]]; then
  emit ""; exit 0
fi
result="$(main)" || fallback
# "<kind>\t<more>\t<text>": kind and more never hold a tab; the rules text might.
rest="${result#*$'\t'}"
emit "${rest#*$'\t'}" "${result%%$'\t'*}" "${rest%%$'\t'*}"
exit 0
