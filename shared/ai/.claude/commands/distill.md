# Distill this session into a journal entry

Write one journal entry for the session we are in, into
`~/06_SYSTEM/agents/journal/YYYY/MM/YYYY-MM-DD_short-slug.md`, following the
house format exactly.

## Format (strict)

Exactly two header lines first:

```
SLUG: <3-5-word kebab-case>
TITLE: <one declarative sentence>
```

Then only the sections that are non-empty, in this order and with these exact
headings:

- `## What was done`
- `## Decisions taken`
- `## What failed or surprised`
- `## Still open`

Omit any empty section. Content must record only what a future session would
otherwise have to re-derive: exact paths, commands, error strings, decisions,
and failures. Failures are the most valuable. No praise, no summary-of-summary,
no filler, and never invent anything not in the transcript.

## Rules

- **Append only.** If an entry for this session already exists, do not edit it;
  write nothing and say so.
- The file is new; never overwrite an existing entry.
- End by stating the file path you wrote and the byte count
  (`wc -c <path>`).
