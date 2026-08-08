# Agentic Documents

Applies to markdown whose primary reader is Claude or another agent, not a
human: `SKILL.md`, `CLAUDE.md`, `AGENTS.md`, slash-command markdown, agent
system-prompt markdown, and any reference doc meant to be loaded into an
agent's context window.

Write these documents to be tree-shaken: a lean root that always loads,
with topic-specific detail split into child files an agent only pulls in
when needed. The goal is lazy loading, not narrative completeness.

## The three-tier loading model

1. **Metadata** (name + description, or the equivalent front section) —
   always loaded. This is the only content an agent sees before deciding
   whether the document is relevant, so it must state both what the
   document covers and when to load the rest.
2. **Root body** — loaded once the document triggers. Keep it lean: a
   root file should read like a table of contents plus the most common
   case, not the full content duplicated.
3. **Reference children** — loaded only when the agent follows a link
   from the root. Split by topic/domain so a task in one area never pulls
   in another area's tokens.

## Structural rules

- Keep the root file lean. As a ceiling, a root document should stay well
  under 500 lines; if it is a pure context file (e.g. `CLAUDE.md`,
  `AGENTS.md`) aim closer to 150 lines.
- Link every reference child directly from the root — never nest
  references (root → child → grandchild). Agents often read children with
  a partial/`head`-style read; chains beyond one hop silently drop
  information.
- Give reference files longer than 100 lines a table of contents at the
  top, so a partial read still reveals the file's full scope.
- Name reference files descriptively by topic (`references/finance.md`,
  `references/agentic-document.md`), never by position or vague label
  (`doc1.md`, `notes.md`).
- Use one consistent term per concept across the root and all its
  children — synonyms break an agent's ability to grep or navigate
  between split files.

## Style rules

- Write the description/trigger section in third person with explicit
  conditions ("This skill should be used when the user asks to ..."). A
  vague description means the document never loads when it's needed.
- Write the body in imperative/infinitive form ("Validate the input
  before use"), not second person ("You should validate the input").
- Prefer a deterministic script over prose for any fragile or
  repeatedly-rewritten operation — a script can execute without ever
  entering context.
- Show one concrete example per convention rather than a paragraph of
  description; examples outperform prose-only guidance for agent
  consumption.
- Don't inline time-sensitive facts ("as of version X, do Y") into
  the main flow — isolate them (e.g. a dedicated "legacy" section) so a
  stale conditional doesn't mislead a later load.

## Anti-patterns

- **Nested reference chains** — root links to a child that links to
  another child. Flatten to one hop from the root.
- **A ballooning root file** — detail accretes into the root instead of
  being split out. Move it to a topic-specific reference file the moment
  the root drifts past its line ceiling.
- **Wholesale LLM-generated context dumps** — auto-generating a large
  `AGENTS.md`/`CLAUDE.md` without pruning measurably degrades agent
  performance; every line should earn its place.
- **Mixed terminology** across split files for the same concept.

## Quick checklist

- [ ] Description/trigger section states what the doc covers and when to load it, in third person
- [ ] Root file stays under the line ceiling for its type
- [ ] Every reference file is linked directly from the root (no nesting)
- [ ] Reference files over 100 lines have a table of contents
- [ ] File names are descriptive, not positional
- [ ] Body uses imperative/infinitive form throughout
- [ ] Fragile/repeated operations are scripts, not prose
- [ ] Terminology is consistent across root and children
