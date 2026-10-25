---
name: sharpen
description: "Switches Prompt Sharpener's mode for this project or for every project: full (rewrite block every request), brief (one 'Taking this as' line), ground (no rewrite, quiet fact-checking only) or off. Use only when the user runs it or asks to change, check or reset the Prompt Sharpener mode."
argument-hint: "[full|brief|ground|off|status|reset] [--global]"
disable-model-invocation: true
---

# Switch the Prompt Sharpener mode

The Prompt Sharpener hook reads its mode on every prompt, so a change here applies
from the user's **next** message. Do not rewrite this request itself; just do it.

## Where the mode lives (highest wins)

1. `PROMPT_SHARPENER_MODE` environment variable. It is fixed for the whole session
   (hooks inherit the environment the CLI started with), so this skill can't change it.
2. Project file: `<project root>/.claude/prompt-sharpener.local.md`. The hook finds the
   project root from `CLAUDE_PROJECT_DIR`, else its working directory. `mode: off` here
   acts as `ground`, so a cloned repo can't switch off fact-checking.
3. User file: `~/.claude/prompt-sharpener.local.md`. The only file that can set `off`.
4. Default: `full`

Both files hold YAML frontmatter only:

```markdown
---
mode: brief          # full | brief | ground | off
detail_words: 80     # prompts this long and structured get the one-line form
full_every: 25       # re-send the full rules every N prompts (0 = never)
---
```

## Steps

Arguments: `$ARGUMENTS`

1. Pick the file: the user file if `--global` is given, otherwise the project file in
   the current working directory.
2. **status** (or no argument): read `PROMPT_SHARPENER_MODE` (`printenv`), then both
   files, and report the mode in effect and which of the four sources set it.
3. **full / brief / ground / off**: write `mode: <value>` into the chosen file's
   frontmatter. Keep any other keys already there; create the file (and `.claude/`)
   if missing. If `PROMPT_SHARPENER_MODE` is set, say that it still wins until the
   CLI is restarted without it. For `off` without `--global`, write the project file
   anyway but tell the user it will act as `ground` there, and that
   `/prompt-sharpener:sharpen off --global` turns it fully off.
4. **reset**: remove the `mode:` line from the chosen file, and delete the file if
   nothing else is left in it.
5. Reply in one or two lines: the new mode, the file changed, and that it applies
   from the next message. For a project file, mention that `*.local.md` files are
   usually git-ignored, and offer to add `.claude/*.local.md` to `.gitignore` if it
   isn't covered.

What each mode does:

| Mode | Rewrite | Fact-checking |
| --- | --- | --- |
| full | Rewrite block + Assumptions line; one line for detailed prompts; none for commands and short replies | yes |
| brief | One "Taking this as: ..." line | yes |
| ground | none | yes |
| off | none | no (the hook adds nothing) |
