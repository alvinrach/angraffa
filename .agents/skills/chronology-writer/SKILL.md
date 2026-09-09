---
name: chronology-writer
description: Record what was built in this phase. Reads git history for the facts and the current conversation for the reasoning, then appends a dated entry to docs/CHRONOLOGY.md.
---

# Chronology writer

Append one entry to `docs/CHRONOLOGY.md` covering work since the last entry.

## Step 1: find the range

Read `docs/CHRONOLOGY.md`. Each entry ends with a line `since: <sha>`.
Take the sha from the LAST entry in the file.

- File exists with a sha: the range is `<sha>..HEAD`
- File missing or empty: the range is all history

## Step 2: read the git record

Run these and actually read the output. Do not skip this because you
think you remember what happened.

```bash
git log --reverse --date=short --pretty=format:'%h %ad %s' <range>
git log --reverse --stat <range>
git status --short
```

`git status` matters. Uncommitted work is real work and will not
appear in the log. Record it in its own section.

## Step 3: recover the reasoning from this conversation

Git tells you what changed. It cannot tell you why. Go back through
the current conversation and extract:

- decisions made, and which options were rejected
- things that turned out differently than expected
- constraints discovered (API limits, library behaviour, platform quirks)
- anything the user corrected you on
- gaps left deliberately

If the conversation was compacted or you cannot actually recall a
decision, write `[reasoning not recovered]`. A gap is honest. A
plausible-sounding guess is worse than nothing, because a future
session will treat it as fact.

## Step 4: append

Append to the END of `docs/CHRONOLOGY.md`. Never edit earlier entries.
Never reorder.

```markdown
## <YYYY-MM-DD>: <short phase name>

**Built**
- `[me|agent|forced]` <what exists now>, because <trigger>

Origin tag: [me] you asked for it. [agent] it proposed this and you
accepted. [forced] an error, limit, or library behaviour left no choice.

Omit "because" when the reason is obvious from the item itself.
Do not write tautologies. If the reason is a real choice between
options, it belongs in Decisions, not here.

**Commits**
- `<sha>` <subject>

**Uncommitted**
- <file>: <what it is>    (omit this section if the tree is clean)

**Decisions**
- <decision>: chose X over Y because Z

**Surprises**
- <expected vs what actually happened>

**Open**
- <known gaps, deliberately deferred>

since: <sha of HEAD now>
```

## Rules

- Record outcomes, not dialogue. No turn by turn narration.
- Do not record anything a reader could get by reading the code.
- Do not describe how the system currently works. That is
  `docs/ARCHITECTURE.md`, a different file with different rules.
- If nothing meaningful happened, say so in one line and stop.
- Do not modify source code in this skill.