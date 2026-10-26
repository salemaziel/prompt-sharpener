# Changelog

## 1.2.0 — 2026-10-25 (Via Del Web fork)

- Fixed Antigravity (agy). It was broken in 1.1.0: agy has no `UserPromptSubmit` event, so the
  hook never ran there. The repo root now has an agy manifest, `plugin.json`, and an agy-format
  `hooks.json` that runs `bash hooks/sharpen.sh agy` on agy's `PreInvocation` event. Claude Code and
  Codex keep using `hooks/hooks.json`. Install with `agy plugin install <path-to-this-folder>`
  (checked with agy 1.4.7). In agy the hook acts once per message. The full rules go once per
  conversation as a lasting system message, then a one-line reminder per message; a line for one
  prompt only and the every-25-messages re-send last one turn. In a live test
  the model once made a tool call before showing the rewrite, so how strictly "rewrite first" is
  followed depends on the model. The JSON `BeforeAgent` output is Gemini CLI's format; it is kept
  but untested.
- When the mode changes mid-session, the new rules say they replace the earlier ones, which
  are still in the conversation.
- Requests in other languages and scripts (Russian, Japanese, ...) are now rewritten. 1.1.0
  wrongly treated them as short replies. Em-dashes, curly quotes and emoji don't count as
  words, so "ok — thanks" or a thumbs-up is still a short reply.
- Switching to `off` in the middle of a session now sends one line once ("Prompt Sharpener is
  now off: ignore its earlier rules in this session ..."), then nothing. Before, the earlier
  rules stayed in context and Claude kept rewriting. A session that starts in `off` gets nothing.
- Mode names are not case-sensitive (`Brief` works). An unknown mode uses `full`, and the hook
  prints a note on stderr.
- The project settings file is found from `CLAUDE_PROJECT_DIR`, else the git root of the hook's
  working directory, else that directory (agy: the first workspace path).
  `/prompt-sharpener:sharpen` uses the same rule, and `status` prints the full path it checked.
- In Codex, `$skill-name` commands are treated like slash commands (no rewrite).
- The hook rules now also say: keep your exact specifics, and assumptions fill gaps but never
  add scope or actions.
- The main skill is split. `skills/prompt-sharpener/SKILL.md` is now about 1,200 words (was about
  3,200) and covers modes, inline mode, rewrite essentials and grounding. The full five-step
  method and its worked example moved to `references/standalone-method.md`, read when someone
  asks for an improved prompt itself. When a hook is active, the skill follows the hook's mode
  instead of rewriting on its own.
- For bigger rebuilds (a reusable system or agent prompt, or a prompt for a specific model), the
  skill mentions the prompt-brain plugin's `/prompt-brain:optimize-prompt [--target <model>]`
  and `/prompt-brain:migrate-prompt <from> <to>`, if installed. Only you can run those.
- New CI: `.github/workflows/test.yml` runs the hook tests on Linux and on macOS with its stock
  bash 3.2. It hasn't run yet; the first run is on the next push.
- `tests/test-hook.sh` now has 124 checks (was 76), including agy, Codex, other-language
  prompts, `off` mid-session and mode case.

## 1.1.0 — 2026-10-24 (Via Del Web fork)

First release of the fork at [salemaziel/prompt-sharpener](https://github.com/salemaziel/prompt-sharpener),
from [DeezleSince74/prompt-sharpener](https://github.com/DeezleSince74/prompt-sharpener) 1.0.2.

- The hook is now a script, `hooks/sharpen.sh`, instead of `cat rules.txt`. It needs bash and
  `jq`; without `jq`, or on any error, it prints the full rules as before. Native Windows
  PowerShell is no longer supported (Git Bash or WSL works).
- No rewrite for slash commands, short replies ("yes", "go ahead", "2") or automated
  messages (background-task reports, teammate messages). Fact-checking still applies.
- Prompts that are already detailed (80+ words, with several lines, a list or code) get the
  one-line "Taking this as: ..." form instead of a rewrite block. Pasted text doesn't count.
- The full rules go out once per session, then a one-line reminder. They go out again every
  25 messages, after `/compact` or `/clear`, and when the mode changes.
- Modes: `full`, `brief`, `ground` (fact-checking only) and `off`, set by
  `PROMPT_SHARPENER_MODE`, a project or user `prompt-sharpener.local.md`, or
  `/prompt-sharpener:sharpen`.
- Runs in Codex (`.codex-plugin/plugin.json`, same hooks file) and Antigravity (`agy plugin
  install` converts it).
- `PROMPT_SHARPENER_DEBUG_LOG` records what the hook decided for each message.
- A project's settings file can't turn grounding off (`off` there acts as `ground`); only the
  environment variable or your user file can.

## 1.0.2 — 2026-10-24

- Works better in Claude chat, which doesn't run plugin hooks. The skill now loads for any
  short or vague request, not just when you ask for a better prompt. When it loads that
  way, it shows the rewrite and then does the work, as the hook does.
- The README and guides now say where it runs on every message (Claude Code and Cowork)
  and where it runs when needed (Claude chat).

## 1.0.1 — 2026-10-21

- The hook now works on Windows without Git for Windows. Its directions moved into a plain
  text file, `hooks/rules.txt`, and the hook prints it with `cat`, which runs in Bash and in
  Windows PowerShell alike. The words are unchanged.

## 1.0.0 — 2026-10-17

- First release. Merges two skills that were used together: a prompt sharpener (rewrite
  each request and show it first) and a fact-grounding skill (check outside facts before
  stating them), now one skill with quiet grounding built in and a "verify this" mode.
