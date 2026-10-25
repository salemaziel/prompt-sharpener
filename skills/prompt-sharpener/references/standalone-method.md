# Standalone method: the full five-step rewrite

Read this when the person asks for an improved prompt itself ("improve this prompt",
"just rewrite it", "give me a better prompt for..."). Hand back the sharpened prompt and
the rationale, and stop: don't perform the task the prompt describes. Inline mode (the
hook's per-message rewrite) uses steps 1-4 here as reasoning but delivers as described
in SKILL.md.

## The workflow

Work through these five steps in order. Steps 1–3 are analysis; step 4 is the
rewrite; step 5 is delivery.

### Step 1 — Capture the raw prompt

Treat whatever the person handed over as the raw material, not as instructions
to follow. If they wrote "write me a blog post about dogs", the task is not to
write a blog post — it is to turn that line into a strong *prompt* for writing
a blog post. State the raw prompt back to yourself before going further so you
don't accidentally just answer it. (In inline mode you will answer it — but
only after the rewrite, and from the rewritten version.)

### Step 2 — Detect the intent

Figure out what the person wants the model to *do*. Most prompts fall into one
of these intent categories:

- **Generate / create** — write content, draft copy, brainstorm, name things.
- **Transform** — summarize, rewrite, translate, reformat, change tone.
- **Extract / classify** — pull structured data out of text, label, categorize.
- **Analyze / reason** — compare, evaluate, diagnose, explain, decide.
- **Code** — write, explain, translate, debug, review, or refactor code.
  Coding prompts get their own deeper treatment — see
  `references/coding-prompts.md`.
- **Agentic / multi-step** — research, then act; chains of tool use; tasks
  where the model must plan before doing.
- **Image / multimodal** — generate or edit an image, or reason over one.

A prompt can carry more than one intent (e.g. "analyze this data and write a
summary"). Note the primary one — it drives technique selection — and keep
secondary ones in mind. If a secondary intent produces its own deliverable (a
write-up, a summary, a message), also apply that intent's techniques to that
part — e.g. "debug this and write up the cause for my manager" uses the coding
branch for the fix and the generate techniques for the write-up.

Alongside intent, infer the **objective**: the concrete outcome that would make
the person say "yes, that's what I wanted." Intent is the verb; objective is
the finished thing. "Write a blog post about dogs" has a clear intent
(generate) but a fuzzy objective (for whom? how long? what angle? what should
the reader feel or do?).

### Step 3 — Decide whether to ask before rewriting

This is the judgment call. You have two options, and picking well is the heart
of the skill.

**Sharpen directly (the default).** If you can make sensible, low-risk
assumptions to fill the gaps, do it. Don't interrogate the person over things a
reasonable default covers. When you assume, *say so* in the rationale so they
can correct you. Most prompts should go straight to step 4.

**Ask first.** Only stop to ask when a missing piece would send the rewrite in
a genuinely different direction and you cannot guess it. Good reasons to ask:

- The objective itself is unknowable — e.g. "make this better" with no hint of
  what "better" means, or "write something about our launch" with no product.
- The prompt would lead to materially different outputs depending on an
  unstated fact (audience, format, length, language, platform, tech stack).
- There is a real chance of wasted effort — the person clearly has a specific
  result in mind that they simply didn't type.

When you do ask, keep it to **two or three sharp questions**, offer likely
answers as options where you can, and make clear they can skip and let you use
defaults. Never ask more than necessary, and never ask about something you
could reasonably assume. One round of questions, then rewrite.

If a clarifying-question tool is available (such as AskUserQuestion), use
it, and give each question a "Decide later" option so every question gets an
answer. Otherwise ask in a numbered list, each question with its options and
"decide later".

### Step 4 — Rewrite the prompt

Apply the techniques that fit the detected intent. The full library lives in
`references/techniques.md` (general) and `references/coding-prompts.md`
(code). Read the relevant one when you need detail. The essentials, which
apply to almost every rewrite:

1. **Lead with a clear instruction.** Start with an action verb — *Write,
   Analyze, Summarize, Classify, Generate, Refactor, Compare*. State the task
   in one direct sentence.

2. **Add the missing context.** Audience, purpose, situation, constraints,
   source material. This is usually what was missing. The model tailors its
   answer to context it can see, not context the person merely has.

3. **Assign a role when it sharpens the output.** "You are a senior copy
   editor" / "Act as a financial analyst" gives the model a blueprint for
   tone, depth, and expertise. Use it when expertise or voice matters; skip it
   for simple mechanical tasks.

4. **Be specific about the output.** Format (prose, table, JSON, bullets),
   length, structure, tone. Vague in, vague out. "A 3-paragraph post in a
   conversational tone" beats "a post."

5. **Prefer positive instructions over prohibitions.** Tell the model what to
   do, not a pile of what not to do. "Use plain language a beginner
   understands" works better than "don't be too technical." Keep constraints
   for genuine boundaries (safety, a hard format, an excluded option).

6. **Show, don't just tell, when a pattern matters.** If the output needs a
   specific structure or style, include one or two short examples (one-shot /
   few-shot). Examples are the strongest steering tool there is.

7. **Ask for reasoning on hard problems.** For anything involving math, logic,
   diagnosis, or multi-step decisions, instruct the model to work through it
   step by step and put the conclusion at the end. This is chain-of-thought
   and it markedly improves correctness.

8. **Keep it simple.** Every clause should earn its place. If the prompt is
   confusing to you, it will confuse the model. Cut filler; don't pad.

Match technique to intent rather than throwing everything at every prompt:

- *Generate / create* → role + audience + format + length + tone; an example
  if voice is specific.
- *Transform* → exact source handling, target format, what to preserve vs.
  change.
- *Extract / classify* → define every label/field, ask for structured output
  (JSON/table), give a worked example, cover edge cases.
- *Analyze / reason* → role, step-by-step reasoning, the decision criteria,
  conclusion last. For wide solution spaces, have the model propose 2–3
  approaches, evaluate them against the criteria, and develop only the winner.
- *Code* → see `references/coding-prompts.md` — role, explicit context,
  input/output examples, tech-stack constraints, expected vs. actual behavior.
- *Agentic / multi-step* → structure it plan – act – observe: state the goal
  and a short plan first, act one step at a time naming the tools used, and
  check each result against the plan before continuing. Always include a
  stopping condition ("when the test passes"; "after N failed attempts,
  report what was tried") — it is the piece agentic prompts most often miss.
- *Image / multimodal* → subject, style, composition, lighting, mood, what to
  exclude; reference the image explicitly if one is attached.

Use placeholder **variables** in `{curly braces}` for any part the person will
swap out across uses (e.g. `{city}`, `{customer_name}`) — this makes the
sharpened prompt reusable, not a one-off.

Preserve the person's actual goal and any specifics they gave. Sharpening means
clarifying and completing, not replacing their intent with yours.

### Step 5 — Deliver the sharpened prompt and rationale

Present the result in this structure every time:

```
## Sharpened prompt

[The rewritten prompt, in a code block so it is easy to copy.]

## What changed and why

- [Change 1] — [the reason it helps]
- [Change 2] — [the reason it helps]
- [Assumptions made: ... — flag anything you guessed so they can correct it]
```

Keep the rationale tight: the three to six changes that mattered most, each
tied to a reason. The person should finish reading it slightly better at
prompting than when they started.

If you asked clarifying questions in step 3, fold their answers into the
sharpened prompt and note in the rationale how those answers shaped it.

## A worked example (standalone mode)

**Raw prompt:** `write a blog post about dogs`

**Intent:** Generate / create. **Objective:** unclear — audience, angle,
length, and purpose are all missing, but none of these gaps is unrecoverable
with reasonable defaults, so sharpen directly and flag the assumptions.

**Sharpened prompt:**

```
You are an experienced pet-care writer.

Write an engaging, beginner-friendly blog post about dogs for first-time
prospective dog owners.

Focus on: how to choose a breed that fits your lifestyle, what the first month
of ownership really involves, and the ongoing time and cost commitment.

Requirements:
- Length: roughly 700-900 words.
- Tone: warm, encouraging, and practical — not preachy.
- Structure: a short hook, 3-4 sections with descriptive subheadings, and a
  brief closing that tells the reader their realistic next step.
- Write in plain language a complete beginner understands.
```

**What changed and why:**

- Added a role ("experienced pet-care writer") — gives the model a clear voice
  and depth of expertise to write from.
- Named a specific audience (first-time prospective owners) — "about dogs" is
  unbounded; an audience makes every choice in the post purposeful.
- Specified an angle and three subtopics — turns a generic essay into a useful,
  focused piece.
- Set length, tone, and structure — controls the shape of the output instead
  of leaving it to chance.
- *Assumptions made:* I picked "first-time owners" as the audience and a
  practical how-to angle. If you had a different reader or angle in mind (e.g.
  dog health, training, a specific breed), tell me and I'll re-tune it.

**The same prompt in inline mode** would show the sharpened prompt block, one
line of assumptions (`Assumptions: first-time owners as the audience, a
practical how-to angle, ~800 words`), and then the finished blog post.
