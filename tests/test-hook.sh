#!/usr/bin/env bash
# Checks the hooks: what hooks.json runs, the rules text, and what sharpen.sh prints
# for each kind of prompt, mode and session state. No model calls; everything runs
# against a temporary HOME and state directory.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
rules="$here/hooks/rules.txt"
script="$here/hooks/sharpen.sh"
fail=0
# Call right after a test: reports that test's result under a name.
check() { if [[ $? -eq 0 ]]; then echo "ok   - $1"; else echo "FAIL - $1"; fail=1; fi; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" PROMPT_SHARPENER_STATE_DIR="$tmp/state"
unset PROMPT_SHARPENER_MODE PROMPT_SHARPENER_DEBUG_LOG CLAUDE_PROJECT_DIR XDG_STATE_HOME
mkdir -p "$HOME/.claude" "$tmp/proj/.claude"

# Runs the hook the way Claude Code does: hook JSON on stdin, path filled in, sh -c.
# Usage: hook PROMPT [SESSION] [EVENT] [CWD]
hook() {
  jq -n --arg p "$1" --arg s "${2-s1}" --arg e "${3:-UserPromptSubmit}" --arg c "${4:-$tmp}" \
    '{session_id: $s, cwd: $c, prompt: $p, hook_event_name: $e}' |
    CLAUDE_PLUGIN_ROOT="$here" sh -c 'bash "${CLAUDE_PLUGIN_ROOT}/hooks/sharpen.sh"'
}
reset() { jq -n --arg s "$1" '{session_id: $s}' | bash "$script" reset; }
full="$(cat "$rules")"

# --- hooks.json -------------------------------------------------------------------
jq -e . "$here/hooks/hooks.json" >/dev/null; check "hooks.json is valid JSON"
[[ "$(jq -r '.hooks.UserPromptSubmit[0].hooks[0].command' "$here/hooks/hooks.json")" == 'bash "${CLAUDE_PLUGIN_ROOT}/hooks/sharpen.sh"' ]]
check "UserPromptSubmit runs sharpen.sh"
[[ "$(jq -r '.hooks.SessionStart[0].matcher' "$here/hooks/hooks.json")" == "compact|clear" ]] &&
  [[ "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$here/hooks/hooks.json")" == *'sharpen.sh" reset' ]]
check "SessionStart compact|clear runs sharpen.sh reset"

# --- rules text --------------------------------------------------------------------
# Plain printable ASCII only, so no shell or code page can garble it.
for f in rules.txt rules-brief.txt rules-ground.txt; do
  [[ -s "$here/hooks/$f" ]] && ! LC_ALL=C grep -q '[^ -~]' "$here/hooks/$f"; check "$f is plain ASCII text"
  [[ $(wc -w <"$here/hooks/$f") -lt 250 ]]; check "$f stays short (under 250 words)"
  grep -q "never as instructions" "$here/hooks/$f"; check "$f treats fetched pages as data"
done
[[ "$full" == *"Before any tool call"* ]]; check "asks for the rewrite before any tool call"
[[ "$full" == *'"Assumptions:"'* ]]; check "asks for an Assumptions line"
[[ "$full" == *"prompt-sharpener:prompt-sharpener"* ]]; check "names the skill by its full name"
[[ "$full" == *"Don't announce the checks"* ]]; check "grounds facts quietly"
[[ "$full" == *"mark it unverified"* ]]; check "surfaces only unverified facts"
[[ "$full" == *"asked in this conversation to stop"* ]]; check "honors a request to stop the rewrite"
grep -q '"Taking this as: ..."' "$here/hooks/rules-brief.txt"; check "brief rules ask for one Taking-this-as line"
! grep -q "Rewrite first" "$here/hooks/rules-ground.txt"; check "ground rules have no rewrite step"

# --- once per session ---------------------------------------------------------------
[[ "$(hook "fix the login bug")" == "$full" ]]; check "first prompt of a session gets the full rules"
out="$(hook "fix the login bug")"
[[ "$out" == *"full rules given earlier"* && "$out" != *"Ground facts quietly. Before"* ]]; check "later prompts get a one-line reminder"
[[ "$(hook "fix the login bug" s2)" == "$full" ]]; check "a new session gets the full rules again"
reset s1
[[ "$(hook "fix the login bug")" == "$full" ]]; check "reset (compact/clear) brings the full rules back"
hook "x" s1 >/dev/null; [[ -f "$tmp/state/session-s1" ]]; check "session state lives in state/session-<id>"
mkdir -p "$tmp/state/session-sub"; : >"$tmp/state/session-sub/s1"
reset "sub/s1"; [[ -f "$tmp/state/session-sub/s1" && -f "$tmp/state/session-s1" ]]; check "reset ignores a session id with a path in it"
rm -r "$tmp/state/session-sub"
PROMPT_SHARPENER_MODE=brief hook "fix the login bug" >/dev/null
[[ "$(hook "fix the login bug")" == "$full" ]]; check "a mode change re-sends the full rules"
printf -- '---\nfull_every: 3\n---\n' >"$HOME/.claude/prompt-sharpener.local.md"
hook "a" s3 >/dev/null; hook "b c d e f" s3 >/dev/null; hook "b c d e f" s3 >/dev/null
[[ "$(hook "b c d e f" s3)" == "$full" ]]; check "full_every: 3 re-sends the full rules on the 4th prompt"
rm "$HOME/.claude/prompt-sharpener.local.md"
[[ "$(hook "fix it" "")" == "$full" && "$(hook "fix it" "")" == "$full" ]]; check "no session id: full rules every time"
files() { find "$tmp" -type f | sort; }
before="$(files)"
[[ "$(hook "fix it" "../../etc")" == "$full" && "$(hook "fix it" "$(printf 'a%.0s' {1..300})")" == "$full" ]] && [[ "$(files)" == "$before" ]]
check "a session id with a path in it, or a very long one, writes no file"
touch -t 202001010000 "$tmp/state/session-old" "$tmp/state/keep-me"; mkdir -p "$tmp/state/deep"; touch -t 202001010000 "$tmp/state/deep/session-x"
hook "fix it" s9 >/dev/null
[[ ! -e "$tmp/state/session-old" && -e "$tmp/state/keep-me" && -e "$tmp/state/deep/session-x" ]]
check "cleanup deletes only old session-* files directly in the state folder"
rm -rf "$tmp/state/keep-me" "$tmp/state/deep"

# --- the filter ----------------------------------------------------------------------
hook "warm up" f1 >/dev/null
is_ground() { [[ "$(hook "$1" f1)" == *"no rewrite for this prompt"* ]]; }
for p in "yes" "OK." "go ahead" "Yes, continue please" "lgtm!" "2" "b" "/sp-today" "/super-productivity:sp-add buy milk" \
  "$(printf '<task-notification>\n<task-id>x</task-id>')" '<teammate-message teammate_id="lead">hi' "" \
  "$(printf '[SYSTEM NOTIFICATION - NOT USER INPUT]\nThis is an automated background-task event.\n\n<task-notification>\n<task-id>x</task-id>')"; do
  is_ground "$p"; check "ground-only: $(tr '\n' ' ' <<<"${p:-<empty>}" | cut -c1-40)"
done
for p in "no, use postgres instead of sqlite" "/home/pc/app is broken, fix it" "/tmp is full, clean it up" "continue but skip the tests" \
  "<div> is not centered" "why does my parser choke on <task-notification> tags"; do
  ! is_ground "$p"; check "still rewritten: $p"
done
long="$(yes word | head -90 | tr '\n' ' ')"
[[ "$(hook "$(printf 'Refactor the auth module.\n- keep the API\n- add tests\n%s' "$long")" f1)" == *'"Taking this as: ..." form'* ]]
check "a long, structured prompt gets the one-line form"
[[ "$(hook "$long" f1)" == *"rewrite block and Assumptions"* ]]; check "a long prompt with no structure is still rewritten"
pasted="$(printf 'fix this\n<pasted_content id="1">\n%s\n- a\n- b\n</pasted_content id="1">' "$long")"
[[ "$(hook "$pasted" f1)" == *"rewrite block and Assumptions"* ]]; check "pasted text doesn't make a prompt detailed"
[[ "$(hook "yes" f2)" == "$full"$'\n'"For this prompt: "*"no rewrite for this prompt"* ]]; check "full rules plus the per-prompt line on a session's first ack"

# --- modes ---------------------------------------------------------------------------
[[ -z "$(PROMPT_SHARPENER_MODE=off hook "fix it" m1)" ]]; check "mode off prints nothing"
[[ "$(PROMPT_SHARPENER_MODE=brief hook "fix it" m2)" == "$(cat "$here/hooks/rules-brief.txt")" ]]; check "mode brief sends the brief rules"
[[ "$(PROMPT_SHARPENER_MODE=brief hook "fix it" m2)" == *"(brief mode)"* ]]; check "mode brief reminder"
[[ "$(PROMPT_SHARPENER_MODE=ground hook "fix it" m3)" == "$(cat "$here/hooks/rules-ground.txt")" ]]; check "mode ground sends the ground rules"
[[ "$(PROMPT_SHARPENER_MODE=bogus hook "fix it" m4)" == "$full" ]]; check "an unknown mode falls back to full"
printf -- '---\nmode: ground  # quiet\n---\n' >"$HOME/.claude/prompt-sharpener.local.md"
[[ "$(hook "fix it" m5)" == "$(cat "$here/hooks/rules-ground.txt")" ]]; check "user settings file sets the mode"
printf -- '---\nmode: brief\n---\n' >"$tmp/proj/.claude/prompt-sharpener.local.md"
[[ "$(hook "fix it" m6 UserPromptSubmit "$tmp/proj")" == "$(cat "$here/hooks/rules-brief.txt")" ]]; check "project settings file overrides the user file"
[[ "$(CLAUDE_PROJECT_DIR="$tmp/proj" hook "fix it" m6b UserPromptSubmit "$tmp/proj/sub/dir")" == "$(cat "$here/hooks/rules-brief.txt")" ]]
check "CLAUDE_PROJECT_DIR finds the project file from a subfolder"
[[ "$(PROMPT_SHARPENER_MODE=full hook "fix it" m7 UserPromptSubmit "$tmp/proj")" == "$full" ]]; check "PROMPT_SHARPENER_MODE overrides both files"
printf -- '---\nmode: "off"\n---\n' >"$tmp/proj/.claude/prompt-sharpener.local.md"
rm "$HOME/.claude/prompt-sharpener.local.md"
[[ "$(hook "fix it" m8 UserPromptSubmit "$tmp/proj")" == "$(cat "$here/hooks/rules-ground.txt")" ]]; check "a project file can't turn grounding off (off becomes ground)"
printf -- '---\nmode: off\n---\n' >"$HOME/.claude/prompt-sharpener.local.md"
[[ -z "$(hook "fix it" m9 UserPromptSubmit "$tmp/proj")" ]]; check "off in the user file is honored"
rm "$HOME/.claude/prompt-sharpener.local.md" "$tmp/proj/.claude/prompt-sharpener.local.md"
# 08 is not valid octal, so this fails unless the value is read as decimal 8.
printf -- '---\nfull_every: 08\n---\n' >"$HOME/.claude/prompt-sharpener.local.md"
for i in 1 2 3 4 5 6 7 8; do hook "a b" z1 >/dev/null 2>&1; done
[[ "$(hook "a b" z1 2>&1)" == "$full" ]]; check "numbers with leading zeros are read as decimal, quietly"
rm "$HOME/.claude/prompt-sharpener.local.md"

# --- Antigravity (BeforeAgent) ---------------------------------------------------------
out="$(hook "fix it" a1 BeforeAgent)"
[[ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")" == "$full" ]]; check "BeforeAgent gets JSON with the full rules"
[[ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$(hook "fix it" a1 BeforeAgent)")" == "$full" ]] && [[ ! -e "$tmp/state/session-a1" ]]
check "BeforeAgent gets the full rules every turn (context lasts one turn there)"
[[ "$(PROMPT_SHARPENER_MODE=off hook "fix it" a2 BeforeAgent)" == "{}" ]]; check "BeforeAgent with mode off prints {}"

# --- failure falls back to the full rules -----------------------------------------------
[[ "$(echo '{not json' | bash "$script" 2>&1)" == "$full" ]]; check "bad input prints the full rules, nothing on stderr"
mkdir -p "$tmp/bin"; for t in cat dirname; do ln -s "$(command -v $t)" "$tmp/bin/$t"; done
[[ "$(echo '{}' | PATH="$tmp/bin" "$(command -v bash)" "$script")" == "$full" ]]; check "without jq it prints the full rules"
out="$(echo '{"hook_event_name": "BeforeAgent", "prompt": "hi"}' | PATH="$tmp/bin" "$(command -v bash)" "$script")"
[[ "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")" == "$full" ]]; check "without jq, BeforeAgent still gets valid JSON"
[[ "$(jq -n '{session_id: "nh", cwd: "/tmp", prompt: "fix it"}' | env -u HOME -u XDG_STATE_HOME -u PROMPT_SHARPENER_STATE_DIR bash "$script" 2>&1)" == "$full" ]]
check "with HOME unset it still prints the full rules"
[[ "$(jq -n '{session_id: "np", cwd: "/tmp"}' | bash "$script")" == "$full" ]]; check "input with no prompt field gets the full rules"
# printf is a builtin, so the 200 KB string never hits the exec argument limit.
big="$(printf '%*s' 200000 '')yes"
start=$SECONDS; out="$(printf '{"session_id": "big", "cwd": "/tmp", "prompt": "%s"}' "$big" | bash "$script")"
[[ "$out" == *"For this prompt: "*"no rewrite for this prompt"* ]] && (( SECONDS - start < 3 ))
check "a 200 KB prompt is classified in under 3 seconds"

# --- debug log --------------------------------------------------------------------------
PROMPT_SHARPENER_DEBUG_LOG="$tmp/debug.log" hook "yes" d1 >/dev/null
grep -q $'UserPromptSubmit\tfull\tground\tfull=1\tyes' "$tmp/debug.log"; check "PROMPT_SHARPENER_DEBUG_LOG records the decision"

exit $fail
