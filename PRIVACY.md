# Privacy

Prompt Sharpener does not collect or send any personal data, and it never stores your messages
unless you turn on the debug log.

- The hook reads your message on your own computer to decide which directions to add: the
  full rewrite rules, a one-line reminder, or fact-checking only (for commands and short
  replies like "yes"). It makes no network requests.
- The only thing it keeps is one small file per session in `~/.local/state/prompt-sharpener/`
  (or `$XDG_STATE_HOME/prompt-sharpener/`, or `$PROMPT_SHARPENER_STATE_DIR`) with the current
  mode and a counter. It holds no message text and is deleted after 7 days.
- The debug log is off unless you set `PROMPT_SHARPENER_DEBUG_LOG` to a file path. When it's
  on, each message adds a line with the time, the hook decision and the first 80 characters
  of your message. Delete the file and unset the variable to stop it.
- The plugin has no server, no analytics and no telemetry.
- When Claude checks a fact, it uses the search or fetch tools already in your session,
  under your session's own permissions. The plugin adds no tools of its own.

Questions: open an issue on [salemaziel/prompt-sharpener](https://github.com/salemaziel/prompt-sharpener/issues).
