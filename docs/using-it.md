# Using it

In Claude Code and Cowork you won't think about it, because it runs on most messages. Two
more ways to use it are one phrase away.

| Way | How to start it | What you get |
| --- | --- | --- |
| Every message | Nothing. It's automatic. | The rewrite, the Assumptions line, then the work. |
| Improve a prompt | "Improve this prompt: …" or "Just rewrite it." | A better prompt and a short list of what changed and why. Claude stops there and doesn't run it. |
| Verify a claim | "Verify this: …" or "Is this still current?" | A short report for each claim, with the source and the date it was checked. |

## Every message

### Where it runs

| App | When it rewrites |
| --- | --- |
| Claude Code (terminal, IDE, desktop Code tab) | Every message, except the ones listed below |
| Cowork | Every message, except the ones listed below |
| Codex CLI (new) | Every message, except the ones listed below |
| Antigravity CLI, `agy` (new) | Every message, except the ones listed below |
| Claude chat (web, desktop, mobile) | When a request looks short or vague, or when you ask |

Claude chat doesn't run plugin hooks, and the hook is what makes it run on every message.
In chat, Claude uses the skill when it thinks it fits. To be sure, start with "Sharpen this
first:".

See [Getting started](getting-started.md#your-first-message) for what a normal reply
looks like.

### When it skips the rewrite

The hook looks at your message and decides how much to ask for. Claude still checks
outside facts every time.

| Your message | What happens |
| --- | --- |
| A slash command, like `/compact` | No rewrite. |
| A short reply made of words like "yes", "ok", "continue", "go ahead" or "lgtm" | No rewrite. |
| A single menu pick, like "2" or "b" | No rewrite. |
| An automated message, like a background-task report or a teammate message | No rewrite. |
| A long, structured prompt: 80 words or more, and several lines, a list or a code block | One "Taking this as: …" line instead of the rewrite block. |
| Anything else | The full rewrite and Assumptions line. |

Text you paste in a block doesn't count toward the length. "Fix this" plus a big paste
is still a short prompt.

Requests in other languages and scripts, like Russian or Japanese, get the rewrite.
Em-dashes, curly quotes and emoji don't count as words, so "ok — thanks" or a thumbs-up
is still a short reply. In Codex, a `$skill-name` command is treated like a slash command,
so there's no rewrite.

The hook also doesn't send its full rules every time. You get them on the first message
of a session. After that, Claude gets a one-line reminder. The full rules come back every
25 messages, after `/compact` or `/clear`, and when you change the mode.

In Antigravity CLI, the hook acts once per message, on the first model call. Later calls
in the same message get nothing. The full rules go once per conversation as a lasting
system message, then a one-line reminder per message that lasts that turn. The
every-25-messages re-send lasts one turn too, so copies don't pile up. In a live
test, the model once made a tool call before showing the rewrite, so how strictly it
"rewrites first" depends on the model.

To change how much it does, see [Control and privacy](control-and-privacy.md#modes).

## Improve a prompt without running it

Use this when you're writing a prompt to reuse, share, or put in a tool. Parts you'll
swap out each time show up in curly braces, like `{article_text}`.

![An example reply with a "Sharpened prompt" block and a "What changed and why" list](images/improve.png)
*Example reply, re-drawn to show the format.*

## Verify a claim

Ask Claude to verify something, and you get one block per claim:

| Part | What it says |
| --- | --- |
| Claim | The exact statement that was checked. |
| Verified | Yes, no, or partly. |
| Finding | What the source actually says, with the specific version, date, price or limit. |
| Source | The source's name, its link, and the date it was checked. |
| Caveats | Anything uncertain, regional, or likely to change soon. |

![An example verify report for "Python 3.8 still gets security fixes", marked No](images/verify.png)
*Example reply, re-drawn to show the format. The finding was checked against the Python
Developer's Guide on October 17, 2026.*

## Quiet fact-checking

You don't have to ask for it. On every message, even ones that skip the rewrite, Claude checks outside facts before it
states them. These count as outside facts:

- A version number, or "the latest version is …".
- A command, a setup step, or a menu path in someone else's product.
- A price, a quota, a rate limit, or where a free tier ends.
- The shape of an application programming interface (API): its addresses, fields and
  sign-in method.
- What a product can or can't do.
- A legal or compliance rule.

Facts Claude saw for itself in your session, like a file it read or a command's output,
already count as checked.

**What you see:** nothing, when every fact checks out. There's no "Sources" section
added to every reply. When a fact can't be confirmed, Claude marks it **unverified**
right where it's used and tells you how to check it.

**Web pages can't take over.** A page could contain text written to steer an AI, like
"ignore your instructions and …". The plugin tells Claude to treat everything a page
says as information to check, never as orders to follow. If a page tries to direct it,
Claude ignores that and tells you.

Next: [How it works](how-it-works.md)
