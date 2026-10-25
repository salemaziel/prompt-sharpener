# How it works

The plugin is small: one hook, two skills (the main one and the mode switch), and four
reference guides.

![Flow, top to bottom: you send a message, the hook adds two short directions, Claude rewrites your request, shows the rewrite and Assumptions line, does the task, checks outside facts, marks any it couldn't confirm, and finishes the reply](images/flow.png)
*A flow chart of one message, from you sending it to the finished reply. Read it top to bottom.*

## The parts

| Part | File | What it does |
| --- | --- | --- |
| The hook | `hooks/hooks.json`, `hooks/sharpen.sh`, `hooks/rules*.txt` | A hook is a command Claude Code runs at a set moment. This one runs each time you send a message (a `UserPromptSubmit` hook), and again after `/compact` or `/clear` to reset its count. The script `sharpen.sh` reads your message and decides which rules to add to what Claude sees. The rules are in three text files, one per mode: `rules.txt` (full), `rules-brief.txt` and `rules-ground.txt`. |
| The Antigravity files | `plugin.json`, `hooks.json` (repo root) | Antigravity (agy) has no `UserPromptSubmit` event, so it has its own manifest and hooks file. They run `bash hooks/sharpen.sh agy` on agy's `PreInvocation` event. Claude Code and Codex keep using `hooks/hooks.json`. |
| The switch | `skills/sharpen/SKILL.md` | The `/prompt-sharpener:sharpen` command. It changes the mode. See [Control and privacy](control-and-privacy.md#modes). |
| The skill | `skills/prompt-sharpener/SKILL.md` | A skill is a set of instructions Claude loads when it needs them. This one holds the core method (about 1,200 words): modes, inline mode, rewrite essentials, and how to ground facts. When a hook is active, it follows the hook's mode instead of rewriting on its own. |
| References | `skills/prompt-sharpener/references/` | Longer guides the skill reads when needed: `techniques.md` (prompting techniques), `coding-prompts.md` (coding prompts), `grounding.md` (the fact-checking checklist and the verify report format), and `standalone-method.md` (the full five-step method and its worked example, read when someone asks for an improved prompt itself). |
| The test | `tests/test-hook.sh` | Checks the hook with no model calls (124 checks). See below. |
| The CI | `.github/workflows/test.yml` | Runs the test on Linux and on macOS with its stock bash 3.2. It hasn't run yet; the first run is on the next push. |

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
prints the full rules, the way the old hook did. On agy and Gemini CLI it prints them as
JSON. The JSON `BeforeAgent` output is Gemini CLI's format; it is kept but untested,
because Gemini CLI isn't installed.

The rules also tell Claude to keep your exact specifics, and that assumptions fill gaps
but never add scope or actions.

If you switch to `off` in the middle of a session, the hook sends one line once ("Prompt
Sharpener is now off: ignore its earlier rules in this session ..."), then nothing.
Before 1.2.0, the earlier rules stayed in context, so Claude kept rewriting.

### What the hook does with your message

- It reads your message text on your own computer, only to decide which rules to send.
- It never sends anything over the network.
- It never stores your message. The one exception is the debug log, which is off unless
  you turn it on (see [Control and privacy](control-and-privacy.md#what-it-reads-and-writes)).
- The only files it writes are one small state file per session. See below.

### The state file

To send the full rules only once, the hook keeps a tiny file for each session at
`~/.local/state/prompt-sharpener/session-<session_id>`. It holds the mode and a counter, and
never any of your message. The hook deletes these files after 7 days. In agy, each
conversation gets a `session-<conversationId>` file in the same folder. Nothing else is
written.

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
   prints for each kind of message and mode, once per session, Antigravity, Codex,
   other-language prompts, switching to `off` mid-session, mode case, the fallback, and
   the debug log.

Next: [Control and privacy](control-and-privacy.md)
