# How it works

The plugin is small: one hook, two skills (the main one and the mode switch), and three
reference guides.

![Flow, top to bottom: you send a message, the hook adds two short directions, Claude rewrites your request, shows the rewrite and Assumptions line, does the task, checks outside facts, marks any it couldn't confirm, and finishes the reply](images/flow.png)
*A flow chart of one message, from you sending it to the finished reply. Read it top to bottom.*

## The parts

| Part | File | What it does |
| --- | --- | --- |
| The hook | `hooks/hooks.json`, `hooks/sharpen.sh`, `hooks/rules*.txt` | A hook is a command Claude Code runs at a set moment. This one runs each time you send a message (a `UserPromptSubmit` hook), and again after `/compact` or `/clear` to reset its count. The script `sharpen.sh` reads your message and decides which rules to add to what Claude sees. The rules are in three text files, one per mode: `rules.txt` (full), `rules-brief.txt` and `rules-ground.txt`. |
| The switch | `skills/sharpen/SKILL.md` | The `/prompt-sharpener:sharpen` command. It changes the mode. See [Control and privacy](control-and-privacy.md#modes). |
| The skill | `skills/prompt-sharpener/SKILL.md` | A skill is a set of instructions Claude loads when it needs them. This one holds the full method: finding what you really want, when to ask instead of guess, rewrite techniques, and how to ground facts. |
| References | `skills/prompt-sharpener/references/` | Longer guides the skill reads when needed: `techniques.md` (prompting techniques), `coding-prompts.md` (coding prompts), and `grounding.md` (the fact-checking checklist and the verify report format). |
| The test | `tests/test-hook.sh` | Checks the hook with no model calls. See below. |

## The hook's exact words

Nothing is hidden. The words the hook adds are plain text in
[`hooks/rules.txt`](../hooks/rules.txt), [`hooks/rules-brief.txt`](../hooks/rules-brief.txt)
and [`hooks/rules-ground.txt`](../hooks/rules-ground.txt). Which one you get depends on
your mode. The hook also adds a one-line reminder or a one-line note for a single
message. Those lines are written out in [`hooks/sharpen.sh`](../hooks/sharpen.sh).

![Terminal running cat hooks/rules.txt and printing the two directions](images/hook.png)
*Real output from the earlier version, which ran `cat` on `rules.txt`. The words are
the same, but the hook is now a script.*

The hook's command is `bash "${CLAUDE_PLUGIN_ROOT}/hooks/sharpen.sh"`. It needs `bash`
and `jq` (a small tool that reads JSON). If `jq` is missing, or anything goes wrong, it
prints the full rules, the way the old hook did.

### What the hook does with your message

- It reads your message text on your own computer, only to decide which rules to send.
- It never sends anything over the network.
- It never stores your message. The one exception is the debug log, which is off unless
  you turn it on (see [Control and privacy](control-and-privacy.md#what-it-reads-and-writes)).
- The only files it writes are one small state file per session. See below.

### The state file

To send the full rules only once, the hook keeps a tiny file for each session at
`~/.local/state/prompt-sharpener/session-<session_id>`. It holds the mode and a counter, and
never any of your message. The hook deletes these files after 7 days.

## The test

Run it from the repository folder:

```bash
bash tests/test-hook.sh
```

It uses a temporary home folder and makes no model calls. It checks:

1. **The commands.** `hooks/hooks.json` must run `sharpen.sh` on each message and
   `sharpen.sh reset` after `/compact` or `/clear`.
2. **The text is plain.** Each rules file must be plain ASCII (basic letters, numbers
   and punctuation), so no shell or Windows setting can garble it.
3. **The words.** The rewrite comes before any tool call, there's an Assumptions line,
   the skill is named in full, the checks stay quiet, fetched pages are treated as data,
   a request to stop is honored, and each rules file stays under 250 words.
4. **It runs.** The test runs the script the way Claude Code does, and checks what it
   prints for each kind of message and mode, once per session, Antigravity, the
   fallback, and the debug log.

Next: [Control and privacy](control-and-privacy.md)
