# Human-Focused Documentation

Applies to markdown whose primary reader is a human developer: guides,
how-tos, design docs, RFCs, runbooks, and tutorials. Does not cover the
top-level `README.md` (see `references/readme.md`) or documents meant
primarily for an agent to consume (see `references/agentic-document.md`).

Write these documents to be clear, clean, and concise. Every choice below
exists to keep the reader from being overloaded.

## Pick the right shape for the subtype

Different human docs do different jobs; use the matching shape rather
than one generic template.

**Guide / how-to / tutorial:**

1. Title stating the outcome, not the topic (e.g. "Deploy the service to
   staging", not "Deployment")
2. One-paragraph purpose: what this covers, who it's for, prerequisites
3. Prerequisites as a checkable bulleted list
4. Body organized by task or logical progression, at most 3 heading
   levels deep, no skipped levels
5. Examples and code blocks placed inline next to the step they support,
   not batched at the end
6. Troubleshooting/pitfalls, if applicable
7. "See also" links gathered at the end, not scattered mid-document

**Design doc / RFC:**

1. Context and scope — succinct, objective background
2. Goals and explicit non-goals (non-goals bound scope as much as goals)
3. The design — overview first, then detail, centered on trade-offs
4. Alternatives considered, and why they were rejected
5. Cross-cutting concerns: security, privacy, observability, rollout
6. Target length: 1-3 pages for a small change; treat ~10-20 pages as a
   ceiling for a large one — beyond that, split into multiple docs

**Runbook:**

Optimize for a reader under time pressure, not a learner: scannable,
imperative steps, minimal prose, closer to reference material than to a
guide.

## Numeric heuristics

- Sentence length: aim for an average of 15-20 words.
- Paragraph length: 3-5 sentences, rarely more than 7; one idea per
  paragraph — if a sentence drifts off-topic, cut it or move it.
- Heading depth: 3 levels in most docs; never skip a level.
- A sentence enumerating 3+ items is a candidate for a bulleted list.
- Use tables when comparing across more than one dimension (e.g.
  parameters × behavior) — prose can't be scanned that way.

## DO / DON'T

**DO**

- Front-load context before instructions ("If X, do Y", not "Do Y if
  X") so readers can skip branches that don't apply to them.
- Use second person, active voice, present tense in guides/how-tos to
  keep the actor and action unambiguous.
- Write for scanning first, reading second: short opening sentences,
  bolded key terms, informative headings.
- Put critical caveats where a skimming reader will hit them, not buried
  mid-paragraph.
- Push secondary or edge-case detail to a "see also" link, footnote, or
  a clearly separate section, keeping the primary path clean.

**DON'T**

- Don't use two or three words where one will do ("utilize" → "use",
  "in order to" → "to") — every extra word taxes the reader.
- Don't lean on vague verbs (be, have, make, do) or filler adverbs
  (quite, very, effectively) — they inflate sentences without adding
  meaning.
- Don't nest headings more than 3 levels deep or skip a level — it
  breaks scanability.
- Don't batch all examples at the end of a long guide — place each one
  next to the step it illustrates.

## Quick checklist

- [ ] Shape matches the subtype (guide vs. design doc vs. runbook)
- [ ] Purpose/context stated before instructions
- [ ] Headings ≤3 levels, none skipped
- [ ] Paragraphs are 3-5 sentences, one idea each
- [ ] 3+ item enumerations converted to lists; comparisons use tables
- [ ] Secondary detail pushed to links/footnotes, not inlined
- [ ] No filler words or vague verbs left in
