# Getting started

## What you need

| Item | Details |
| --- | --- |
| Claude Code | In the terminal, the desktop app's Code tab, or an editor extension. Codex CLI and Antigravity CLI also work (see below). |
| Your computer | macOS or Linux, with `bash` and `jq` installed. On Windows, use Git Bash or WSL. Native PowerShell alone is no longer supported. |
| Search tools | Optional. Fact-checking uses whatever web search or fetch tools your session already has. |
| An account | None. The plugin has no server and needs no sign-in. |

## Install it

**From GitHub.** This fork is published in the `vdw` marketplace. In a Claude Code
session, type:

```
/plugin marketplace add salemaziel/vdw-claude-plugins
/plugin install prompt-sharpener@vdw
```

The first command adds the marketplace, which is a list of plugins Claude Code can
install from. The second installs the plugin from it. From a terminal, the same steps are:

```bash
claude plugin marketplace add salemaziel/vdw-claude-plugins
```

```bash
claude plugin install prompt-sharpener@vdw
```

**In Codex CLI (new).** Add the same marketplace, then install the plugin:

```bash
codex plugin marketplace add salemaziel/vdw-claude-plugins
```

```bash
codex plugin add prompt-sharpener@vdw
```

**In Antigravity CLI, `agy` (new).** The plugin's folder has its own agy manifest
(`plugin.json`) and hooks file (`hooks.json`). Point `agy` at the folder:

```bash
agy plugin install <path-to-plugin-folder>
```

This was checked with agy 1.4.7: it keeps the root `hooks.json` (skills 2, hooks 1).
Antigravity didn't work in 1.1.0 and is fixed in 1.2.0.

![Terminal output of the marketplace add, install and list commands, ending in "Status: enabled"](images/install.png)
*Real install output, October 17, 2026.*

**Then start a new session.** A session that is already running keeps the plugins it
started with.

## Your first message

Type a request the way you normally would. Short is fine.

```
write a blog post about dogs
```

The reply comes in three parts:

1. **The rewritten prompt**, in a code block. It fills in the audience, length, angle,
   tone and structure your request left open.
2. **One Assumptions line.** It lists the guesses Claude made to fill those gaps.
3. **The finished work**, done from the rewritten prompt, not your original words.

![An example reply showing the rewritten prompt, the Assumptions line and the start of the post](images/reply.png)
*Example reply, re-drawn to show the format.*

Here is the same thing for real, in the Claude desktop app's Code tab:

![The Claude desktop app: a one-line request, then Claude's rewritten prompt in a code box and an Assumptions line](images/desktop.png)
*Real screenshot from the Claude desktop app, October 17, 2026, trimmed to the conversation.*

**When a guess is wrong,** say so in your next message, for example "make it for
families with kids". Claude redoes the work with the fix.

**For very short requests,** like "what time is it in Tokyo", the rewrite shrinks to one
line that starts with "Taking this as:".

**For short replies and commands,** like "yes", "continue", "2" or `/compact`, there's no
rewrite at all. See [Using it](using-it.md#when-it-skips-the-rewrite).

Next: [Using it](using-it.md)
