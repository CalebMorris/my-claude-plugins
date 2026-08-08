# Top-Level README

Applies to a project's root `README.md` — the entry point a stranger
lands on first. Distinct from other human documentation (see
`references/human-documentation.md`): a README's job is orientation and
triage, not completion.

A README should get a newcomer from "never heard of this" to "I
understand the shape of it and can try it in 5 minutes" — or to "I now
know this isn't for me," which is also a successful outcome. A user
guide's job is different: cover every flag, option, and edge case once
someone has already committed to using the project. Keep that boundary
sharp; anything that only matters to an already-invested user belongs in
a linked doc, not the README.

## Section outline

Write sections in this order; omit any that don't apply, but don't
reorder around them.

1. **Title + one-line tagline** — say what it is in one breath
2. **Badges** (optional, sparse) — build/version/license status only
3. **What & why** (2-5 sentences) — the problem solved and why it
   exists, before anything else; readers decide whether to keep reading
   in under 30 seconds
4. **Core concepts / mental model** — the handful of ideas a newcomer
   must hold to make sense of everything else, not a full glossary
5. **Quickstart** — the single shortest path from zero to a working
   example; one copy-pasteable path, not a menu of options
6. **One usage example** — the smallest realistic snippet showing the
   thing doing its job
7. **Where to go deeper** — explicit links to the docs site, wiki,
   `ARCHITECTURE.md`, API reference, or guides
8. **Contributing** — a pointer to `CONTRIBUTING.md`, not the policy
   itself
9. **License**

The quickstart/usage section's content shifts by project type — a
library leans on API shape and "why choose this over alternatives," a
CLI tool leads with commands/flags/exit codes, an application adds
prerequisites/config — but the surrounding shape stays the same.

## The keep-or-link test

For any paragraph under consideration: if removing it would make a
first-time reader lose the plot of what this is, why it matters, or how
to start, keep it in the README. If it would only matter to someone
already using the project, move it to a linked doc instead of inlining
it.

## DO / DON'T

**DO**

- Answer what-it-is, why-it-matters, and how-to-start on the first
  screen — most evaluation decisions happen before the reader scrolls.
- Structure as an inverted funnel: broadest, most-common information
  first, specifics deeper down, so a returning reader can refresh
  without paging through detail.
- Give exactly one copy-pasteable quickstart path — ambiguity in setup
  is a top reason people give up before trying the project.
- Link out to the docs site, wiki, `ARCHITECTURE.md`, or
  `CONTRIBUTING.md` for anything beyond orientation.
- Keep the README in sync with the current interface as part of the
  release checklist — stale instructions destroy trust faster than no
  instructions.

**DON'T**

- Don't turn the README into the exhaustive manual or API reference —
  that content buries the orientation a newcomer actually needs.
- Don't front-load configuration matrices, edge cases, or
  troubleshooting tables; put them in reference docs instead.
- Don't bury the "why" under installation instructions — a reader who
  doesn't understand the value never reaches the install step.
- Don't over-badge or lead with decoration; the first screen is scarce
  real estate.
- Don't duplicate `CONTRIBUTING.md`/`ARCHITECTURE.md` content inline
  "for convenience" — two copies means one will drift stale.

## Quick checklist

- [ ] What/why answered in the first few sentences
- [ ] Core concepts section covers the mental model, not a glossary
- [ ] Quickstart is a single path, copy-pasteable, no decision points
- [ ] One usage example, minimal
- [ ] Deep content lives behind links, not inlined
- [ ] Every paragraph passes the keep-or-link test
