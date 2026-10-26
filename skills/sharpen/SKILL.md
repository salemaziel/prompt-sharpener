---
name: sharpen
description: "Show or switch the Prompt Sharpener mode (full, brief, ground, off) for this project, or for every project with --global."
argument-hint: "[full|brief|ground|off|status|reset] [--global]"
disable-model-invocation: true
---

# Switch the Prompt Sharpener mode

The Prompt Sharpener hook reads its mode on every prompt, so a change here applies
from the user's **next** message. Do not rewrite this request itself; just do it.

## Where the mode lives (highest wins)

1. `PROMPT_SHARPENER_MODE` environment variable. It is fixed for the whole session
   (hooks inherit the environment the CLI started with), so this skill can't change it.
2. Project file: `<project root>/.claude/prompt-sharpener.local.md`. `mode: off` here
   acts as `ground`, so a cloned repo can't switch off fact-checking.
3. User file: `~/.claude/prompt-sharpener.local.md`. The only file that can set `off`.
4. Default: `full`

**The project root** is found the same way the hook finds it, so both use the same file:
`$CLAUDE_PROJECT_DIR` if set (check with `printenv CLAUDE_PROJECT_DIR`); otherwise the
git root of the directory the session started in (`git -C <dir> rev-parse
--show-toplevel`); otherwise that directory itself. Use the session's starting
directory, not wherever a later `cd` left the shell.

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

1. Read the arguments case-insensitively. If the first one isn't `full`, `brief`,
   `ground`, `off`, `status` or `reset` (or is missing), treat it as `status`, and
   for an unknown word say which values are accepted. Pick the file: the user file if
   `--global` is given, otherwise the project file at the project root above.
2. **status**: read `PROMPT_SHARPENER_MODE`, then both files. Report the mode in
   effect, which of the four sources set it, and the full path of the project file
   you checked.
3. **full / brief / ground / off**: write `mode: <value>` into the chosen file's
   frontmatter. Keep any other keys and comments already there. If the file is
   missing, create it (and `.claude/`). If it exists without frontmatter, add a
   frontmatter block at the top and keep the rest below it. If
   `PROMPT_SHARPENER_MODE` is set, say that it still wins until the CLI is restarted
   without it. For `off` without `--global`, write the project file anyway but say
   it will act as `ground` there, and that `/prompt-sharpener:sharpen off --global`
   turns it fully off.
4. **reset**: remove the `mode:` line from the chosen file. Delete the file only if
   its frontmatter is then empty and nothing follows it.
5. Reply in one or two lines: the new mode, the file changed (full path), and that it
   applies from the next message. For a project file, mention that `*.local.md` files
   are usually git-ignored, and offer to add `.claude/*.local.md` to `.gitignore` if
   it isn't covered.

What each mode does:

| Mode | Rewrite | Fact-checking |
| --- | --- | --- |
| full | Rewrite block + Assumptions line; one line for detailed prompts; none for commands and short replies | yes |
| brief | One "Taking this as: ..." line | yes |
| ground | none | yes |
| off | none; one "now off" line if earlier rules are still in the session | no |
