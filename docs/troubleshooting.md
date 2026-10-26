# Troubleshooting and FAQ

## Troubleshooting

### I installed it, but replies don't start with a rewrite

- In Claude chat (web, desktop or mobile), this is expected. Chat doesn't run plugin
  hooks, so it rewrites only when a request looks vague or you ask. Start with
  "Sharpen this first:" to be sure. Claude Code and Cowork run it on every message.
- Start a new session. Running sessions keep the plugins they started with.
- Run `/plugin` and check that Prompt Sharpener is enabled.
- Check that you didn't ask Claude to stop the rewrite earlier in this conversation.
- Check that `bash` and `jq` are installed. The hook needs both. On Windows, use Git Bash
  or WSL. Native PowerShell alone isn't supported. If `jq` is missing, the hook still
  prints the full rules, but install it to get the smart filter and the once-per-session
  behavior.
- Check your mode with `/vdw-prompt-sharpener:sharpen status`. In `ground` and `off` mode,
  there's no rewrite.

### The rewrite doesn't show for short replies or commands

That's by design. The hook skips the rewrite for slash commands (in Codex, also
`$skill-name` commands), short replies like "yes" or "continue", single menu picks like
"2", and automated messages. Em-dashes, curly quotes and emoji don't count as words, so
"ok — thanks" or a thumbs-up is still a short reply. Claude still checks facts. To see the rewrite on everything, set the mode with
`/vdw-prompt-sharpener:sharpen full`. See [Modes](control-and-privacy.md#modes).

### I want to see what the hook decided

Set `PROMPT_SHARPENER_DEBUG_LOG=<path>` before you start your CLI, for example
`PROMPT_SHARPENER_DEBUG_LOG=/tmp/sharpener.log`. The hook adds one line to that file for
each message: the time, the event, the mode, what it decided, and the first 80
characters of your message. It's off unless you set it. Delete the file when you're done.

### I asked for a better prompt, and Claude ran it instead

Say it plainly, like "Improve this prompt, don't run it: …". The words "improve this
prompt" or "just rewrite it" tell Claude to hand the prompt back and stop.

### Facts are marked unverified a lot

Your session probably has no web search or fetch tool. Turn one on, and Claude can check
facts instead of flagging them.

### The rewrite feels like too much for quick questions

For a short request, the rewrite is a single "Taking this as: …" line. If you'd rather
not see it at all for a while, ask Claude to stop showing it for this conversation. To
change it for good, use `/vdw-prompt-sharpener:sharpen brief` or `ground`. Very short
replies and commands already skip it.

### Another plugin also asks for a rewrite

Use one prompt-rewriting plugin at a time. Two will both ask for a rewrite block, and
you'll see two.

## FAQ

**Does it slow Claude down?**
The hook only reads your message and prints a short block of text, so it adds almost no
time. After the first message of a session, it usually prints just one line. The
rewrite adds a few lines to the start of each reply. Fact-checks take time only when a
reply depends on an outside fact.

**Does it change what Claude does, or only how the reply starts?**
Both, a little. Claude works from the rewritten prompt instead of your original words,
so the result matches the rewrite you can see.

**Can I use it with my own `CLAUDE.md` rules?**
Yes. The plugin never overrides what you or your organization tell Claude.

**Does it work in the desktop app and editor extensions?**
It works anywhere Claude Code runs plugins: the terminal, the desktop app's Code tab,
and the editor extensions. It also works in Codex CLI and Antigravity CLI, which is new
(see [Getting started](getting-started.md#install-it)). Antigravity didn't work in 1.1.0
and is fixed in 1.2.0. In Antigravity, how strictly the model shows the rewrite before
any tool call depends on the model.

**Where do I report a bug?**
Open an issue at
[github.com/salemaziel/prompt-sharpener/issues](https://github.com/salemaziel/prompt-sharpener/issues).
For a security problem, use the **Security** tab instead.
