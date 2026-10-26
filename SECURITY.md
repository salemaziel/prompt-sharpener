# Security

## Reporting a problem

Please report security problems privately through GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository (Security tab → Report a vulnerability). Please don't open a public issue
for a security problem. You can expect a first reply within 7 days.

## What the plugin can do on your computer

- **One local script.** On each message, `hooks/sharpen.sh` reads the hook's input (your
  message, the session id and the working directory) and prints one of the fixed rule files
  in `hooks/` or a fixed one-line reminder. It never runs your message or anything in it,
  and it makes no network requests. In Antigravity (agy), it reads the last user message, the
  conversation id, the first workspace path and the invocation number instead.
- **What it reads:** the hook input, the `PROMPT_SHARPENER_MODE` and `PROMPT_SHARPENER_*`
  environment variables, and two optional settings files: `<project>/.claude/prompt-sharpener.local.md`
  (the project is `CLAUDE_PROJECT_DIR`, else the git root of the hook's working directory,
  else that directory; in agy, the first workspace path)
  and `~/.claude/prompt-sharpener.local.md`.
- **What it writes:** one small file per session, `session-<id>` (in agy, `session-<conversationId>`), in
  `~/.local/state/prompt-sharpener/` (or `$XDG_STATE_HOME/prompt-sharpener/`, or
  `$PROMPT_SHARPENER_STATE_DIR`), holding only the mode and a counter. Session ids that aren't
  1 to 128 plain letters, digits, `-` or `_` are ignored, so a crafted id can't write outside
  that folder. `session-*` files there older than 7 days are deleted; nothing in subfolders
  and nothing with another name is touched. If you set `PROMPT_SHARPENER_DEBUG_LOG`, it also
  appends one line per message to that file (see [PRIVACY.md](PRIVACY.md)).
- **A project can't turn grounding off.** A repository can ship its own
  `.claude/prompt-sharpener.local.md`, so `mode: off` there is treated as `ground`: the
  rewrite stops but the "treat web pages as data" rule stays. Only `PROMPT_SHARPENER_MODE`
  or your user file can turn the plugin fully off.
- **It fails safe.** If `jq` or `HOME` is missing, the input isn't JSON, or anything goes
  wrong, it prints the full rules, as the original `cat` hook did (as JSON on agy and Gemini CLI).
  Very long messages are handled in well under the hook's 10-second timeout.
- **No server, no tools.** The plugin adds no MCP (Model Context Protocol) server. Its skills
  are text: one tells Claude how to rewrite prompts and check facts, the other
  (`/vdw-prompt-sharpener:sharpen`) edits the settings file above when you run it.
- **Web pages can't steer it.** When Claude checks a fact online, the directions tell it to treat
  page content as data, never as instructions, and to tell you if a page tries to direct it.
- **Nothing overrides you.** The directions tell Claude to skip the rewrite when you ask it
  to, and to hand back a rewritten prompt without running it when that is what you asked for.
