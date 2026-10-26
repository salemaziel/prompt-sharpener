# Prompt Sharpener

> **Via Del Web fork** of [DeezleSince74/prompt-sharpener](https://github.com/DeezleSince74/prompt-sharpener)
> by Derek Frempong (MIT). This fork adds a smarter hook that skips commands and short replies,
> sends its rules once per session, has `full`/`brief`/`ground`/`off` modes, and runs in Codex
> and Antigravity too. See [CHANGELOG.md](CHANGELOG.md).

A plugin for Claude Code, Cowork and Claude chat that does two things to your requests.
In Claude Code and Cowork it runs on every message you send. In Claude chat it runs
when your request looks short or vague, or when you ask it to (see [Where it runs](#where-it-runs)).

1. **It rewrites your request into a clear prompt, and shows you that first.** Before
   Claude starts any work, the reply opens with your request rewritten as a complete
   prompt, followed by one line starting "Assumptions:". That line lists what Claude
   guessed, such as the audience, format or scope. If a guess is wrong, you can see it right
   away and correct it, instead of finding out at the end. Then Claude does the
   rewritten task in the same reply.
2. **It checks outside facts quietly.** Before Claude states a fact that lives outside
   your conversation, such as a version number, a price, a command, a limit, an
   application programming interface (API) shape or a rule, it checks it against a current,
   official source. You don't see the checks. You only hear about a fact when it
   couldn't be confirmed: Claude marks it "unverified" where it's used and tells you
   how to check it yourself.

Full guides with pictures are in [docs/](docs/README.md): getting started, the three ways
to use it, how it works, control and privacy, and troubleshooting.

## Example

You type:

```
write a blog post about dogs
```

The reply starts with:

```
Write an engaging, beginner-friendly blog post (700–900 words) for first-time
dog owners: choosing a breed that fits your life, what the first month involves,
and the ongoing time and cost. Warm, practical tone; 3–4 sections with subheadings.
```
Assumptions: first-time owners as the audience, a practical how-to angle, about 800 words.

Then the finished post follows.

## Example prompts

- `plan a 3-day trip to Lisbon` — the reply opens with a fuller prompt (budget, pace,
  interests guessed and listed under Assumptions), then the plan.
- `Improve this prompt: summarize this article` — you get a better prompt and what
  changed, and Claude stops there.
- `Verify this: Python 3.8 still gets security fixes` — you get a claim-by-claim report
  with the source and the date checked.

## Other ways to use it

- **Improve a prompt without running it:** "Improve this prompt: …" or "Just rewrite
  it." You get the better prompt and a short list of what changed and why, and Claude
  stops there.
- **Rebuild a bigger prompt:** for a reusable system or agent prompt, or a prompt for a
  specific model, the skill points to the prompt-brain plugin's
  `/prompt-brain:optimize-prompt [--target <model>]` and
  `/prompt-brain:migrate-prompt <from> <to>`, if you have it installed. Only you can run
  those.
- **Fact-check something on purpose:** "Verify this: …" or "Is this still current?"
  You get a short report for each claim: verified or not, what the source says, the
  link, and the date checked.
- **Turn the rewrite off for one conversation:** ask Claude to stop showing the
  rewrite. Fact-checking keeps running.
- **Change the mode:** `/prompt-sharpener:sharpen brief` (add `--global` for every
  project). It applies from your next message.
- **Turn it off everywhere:** disable Prompt Sharpener with `/plugin`. Turn it back on
  the same way.

## Modes

| Mode | What you see | Fact-checking |
| --- | --- | --- |
| `full` (default) | The rewrite block and Assumptions line. One "Taking this as" line for prompts that are already detailed; nothing for commands and short replies. | yes |
| `brief` | One "Taking this as: ..." line | yes |
| `ground` | No rewrite | yes |
| `off` | Nothing, except one "now off" line if earlier rules are in the session | no |

The mode comes from, highest first: the `PROMPT_SHARPENER_MODE` environment variable
(fixed for the session), `<project>/.claude/prompt-sharpener.local.md`,
`~/.claude/prompt-sharpener.local.md`, then `full`. In a project file `off` acts as `ground`,
so a cloned repository can't switch off fact-checking. Mode names are not case-sensitive
(`Brief` works). An unknown mode uses `full`, and the hook prints a note on stderr. The
project is `CLAUDE_PROJECT_DIR`, else the git root of the hook's working directory, else that
directory (in agy, the first workspace path). The files hold YAML frontmatter:

```markdown
---
mode: brief          # full | brief | ground | off
detail_words: 80     # this many words plus lines, a list or code = "already detailed"
full_every: 25       # re-send the full rules every N messages (0 = never)
---
```

The rewrite is skipped (fact-checking stays) for slash commands, replies made only of
words like "yes", "ok", "continue", "go ahead", menu picks like "2", and automated
messages such as background-task reports. In Codex, `$skill-name` commands count as slash
commands. Requests in other languages and scripts (Russian, Japanese and so on) are
rewritten. Em-dashes, curly quotes and emoji don't count as words, so "ok — thanks" or a
thumbs-up is still a short reply.

If you switch to `off` in the middle of a session, the hook sends one line once ("Prompt
Sharpener is now off: ignore its earlier rules in this session ...") and then nothing.
A session that starts in `off` gets nothing at all.

To see what the hook decided for each message, set `PROMPT_SHARPENER_DEBUG_LOG=/path/to/log`
before starting the session.

## Where it runs

| App | When it rewrites |
| --- | --- |
| Claude Code (terminal, IDE, desktop Code tab) | Every message |
| Cowork | Every message |
| Claude chat (web, desktop, mobile) | When a request looks short or vague, or when you ask: "sharpen this first" |
| Codex CLI | Every message (`UserPromptSubmit` hook) |
| Antigravity CLI (`agy`) | Every message (`PreInvocation` hook) |

Claude chat doesn't run plugin hooks, and the hook is what makes it run on every message.
In chat, Claude uses the skill when it thinks it fits.

In agy, the hook acts once per message, on the first model call. Later calls in the same
message get nothing. The full rules go once per conversation as a lasting system message,
then a one-line reminder per message that lasts that turn. The every-25-messages re-send
lasts one turn too, so copies don't pile up. In a live test with agy 1.4.7,
the model (Gemini 3.8 Flash) once made a tool call before showing the rewrite, so how
strictly "rewrite first" is followed depends on the model.

The JSON `BeforeAgent` output is Gemini CLI's format. It is kept but untested, because
Gemini CLI isn't installed here.

## Installing

This fork is published in the Via Del Web marketplace. In Claude Code:

```
/plugin marketplace add salemaziel/vdw-claude-plugins
/plugin install prompt-sharpener@vdw
```

If you also have the original from the Claude plugin Directory installed, disable it so the
two hooks don't both run.

Codex: `codex plugin marketplace add salemaziel/vdw-claude-plugins`, then
`codex plugin add prompt-sharpener@vdw`. Antigravity: `agy plugin install <path-to-this-folder>`
(checked with agy 1.4.7: it keeps the root `hooks.json`; skills 2, hooks 1).

Start a new session after installing, since a running session keeps the plugins it
started with.

## How it works

| Part | What it does |
| --- | --- |
| `hooks/hooks.json` | Runs `hooks/sharpen.sh` each time you submit a message (`UserPromptSubmit`), and `sharpen.sh reset` after `/compact` or `/clear` (`SessionStart`). |
| `hooks/sharpen.sh` | Reads the message locally, picks the mode, and prints the full rules (first message of a session), a one-line reminder, or a fact-checking-only line. Keeps a tiny per-session counter in `~/.local/state/prompt-sharpener/`. |
| `hooks/rules.txt`, `rules-brief.txt`, `rules-ground.txt` | The directions for `full`, `brief` and `ground` mode, as plain text. |
| `plugin.json`, `hooks.json` (repo root) | The Antigravity (agy) manifest and hooks file. It runs `bash hooks/sharpen.sh agy` on agy's `PreInvocation` event, since agy has no `UserPromptSubmit` event. |
| `skills/prompt-sharpener/SKILL.md` | The core method (about 1,200 words): modes, inline mode, rewrite essentials, and how to ground facts quietly. When a hook is active, it follows the hook's mode instead of rewriting on its own. |
| `skills/prompt-sharpener/references/` | Longer guides: general prompting techniques, coding prompts, and the grounding checklist with the verify-mode report. |
| `skills/prompt-sharpener/references/standalone-method.md` | The full five-step method and its worked example. Read when someone asks for an improved prompt itself. |
| `skills/sharpen/SKILL.md` | `/prompt-sharpener:sharpen`: shows or changes the mode. |
| `.codex-plugin/plugin.json` | The Codex manifest; it uses the same skills and hooks. |
| `tests/test-hook.sh` | Checks the hook's decisions for each kind of message, mode and session state, with no model calls (124 checks). |
| `.github/workflows/test.yml` | Runs the hook tests on Linux and on macOS with its stock bash 3.2. Not run yet; the first run is on the next push. |

The hook needs bash and `jq` (macOS, Linux, or Windows with Git Bash or WSL). Without `jq`,
or if anything goes wrong, it prints the full rules, as the original `cat` hook did.

Fact-checking uses whatever search or fetch tools your session has. With none, Claude
still answers but marks the facts it couldn't check as unverified.

## Privacy

The plugin collects nothing and sends nothing anywhere. See [PRIVACY.md](PRIVACY.md).

## License

MIT. See [LICENSE](LICENSE).
