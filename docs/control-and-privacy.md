# Control and privacy

The plugin asks Claude to do two things. It never overrides what you or your
organization tell Claude.

## Turning things on and off

| You want to | Do this |
| --- | --- |
| Skip the rewrite for now | Ask Claude to stop showing the rewrite. It stops for the rest of that conversation. Fact-checking keeps going. |
| Skip it for good | Switch the mode to `ground` or `brief`. See [Modes](#modes). |
| Turn it all off | Run `/plugin`, find Prompt Sharpener, and disable it. Start a new session. |
| Turn it back on | Enable it the same way, then start a new session. |
| Remove it | Uninstall it from `/plugin`. |

## Modes

The plugin has four modes.

| Mode | What you see | Fact-checking |
| --- | --- | --- |
| `full` (default) | The rewrite block and Assumptions line. One line for long, detailed prompts. Nothing for commands and short replies. | Yes |
| `brief` | Always one "Taking this as: …" line. | Yes |
| `ground` | No rewrite. | Yes |
| `off` | Nothing, except one "now off" line if earlier rules are in the session. | No |

Switch with this command:

```
/vdw-prompt-sharpener:sharpen full|brief|ground|off|status|reset [--global]
```

- It changes the mode for the current project. Add `--global` to change it for every
  project.
- `status` shows the mode in effect and where it came from, and the full path of the
  project file it checked.
- `reset` removes your setting and goes back to the default.
- The change applies from your next message.

The mode comes from the first of these that is set:

| Order | Source | Notes |
| --- | --- | --- |
| 1 | The `PROMPT_SHARPENER_MODE` environment variable | Fixed for the whole session. The command can't change it. Start your CLI again without it. |
| 2 | The project file `<project>/.claude/prompt-sharpener.local.md` | Only this project. `off` here works as `ground`, so a repository you clone can't switch off fact-checking. |
| 3 | The user file `~/.claude/prompt-sharpener.local.md` | Every project. The only file that can set `off`. |
| 4 | The default | `full` |

The project is found from `CLAUDE_PROJECT_DIR`, else the git root of the hook's working
directory, else that directory (in agy, the first workspace path). The command uses the
same rule.

If you switch to `off` in the middle of a session, the hook sends one line once ("Prompt
Sharpener is now off: ignore its earlier rules in this session ..."), then nothing.
A session that starts in `off` gets nothing at all.

Both files hold only settings at the top, between two `---` lines:

```markdown
---
mode: brief
detail_words: 80
full_every: 25
---
```

`mode` is one of the four modes. Names are not case-sensitive (`Brief` works). An unknown
mode uses `full`, and the hook prints a note on stderr. `detail_words` is how long a structured prompt must be
to get the one-line form. `full_every` is how many messages pass before the full rules
are sent again. Use `0` to never repeat them.

## What it reads and writes

The plugin's hook reads your message text to decide which rules to send. It does this on
your computer only. It never sends your message anywhere and never stores it.

The only files it writes are the per-session state files in
`~/.local/state/prompt-sharpener/`. Each holds the mode and a counter, never any of your
message. They're deleted after 7 days. In agy, each conversation gets a
`session-<conversationId>` file in the same folder. Nothing else is written.

There's one optional exception. If you set `PROMPT_SHARPENER_DEBUG_LOG=<path>`, the hook
adds one line to that file for each message: the time, the event, the mode, what it
decided, and the first 80 characters of your message. It's off unless you set it. Delete
the file when you're done.

Fact-checks use your session's own search and fetch tools, under the same permissions
as everything else Claude does for you. The plugin adds no tools of its own.

## Privacy

The plugin collects nothing and sends nothing anywhere. It never stores your message
(except in the optional debug log). There's no server, no telemetry
(automatic usage reporting) and no account. The full policy is
[PRIVACY.md](../PRIVACY.md).

## Security

The hook runs one script, `hooks/sharpen.sh`, and its test checks what it prints (see
[How it works](how-it-works.md#the-test)). To report a
security problem privately, use this repository's **Security** tab on GitHub.
[SECURITY.md](../SECURITY.md) has the details.

## License

MIT. You can use, change and share it, including at work. See [LICENSE](../LICENSE).

Next: [Troubleshooting and FAQ](troubleshooting.md)
