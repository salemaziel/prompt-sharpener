# Changelog

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
