# documentation-manager

Skills that steer how Claude writes and maintains documentation. Starts
simply and is meant to grow: each documentation convention gets its own
skill.

## Try it locally

```bash
claude --plugin-dir plugins/documentation-manager
```

## Skills

### markdown-writing (`skills/markdown-writing`)

House formatting rules for markdown documents (README files, guides,
design docs, plugin skill/command files, agent-consumed docs like
CLAUDE.md). `SKILL.md` holds universal rules that apply to every
document — currently, no `---` horizontal rules in document bodies, use
headings instead — plus a router that picks one of three type-specific
references:

- `references/agentic-document.md` — docs read by Claude/agents
  (`SKILL.md`, `CLAUDE.md`, command/agent markdown). Structure for
  lazy-loading: a lean root plus topic-specific children loaded on
  demand.
- `references/human-documentation.md` — guides, design docs, RFCs,
  runbooks, tutorials. Structure and style rules for clarity and
  conciseness.
- `references/readme.md` — the top-level project `README.md`.
  Concepts-first and minimal; links out to deeper docs instead of
  duplicating them.

## Adding a new convention

1. Either add a new rule to an existing skill's `SKILL.md`, or create a new
   skill under `skills/<topic>/SKILL.md` if the convention covers a
   distinct topic (e.g. commit messages, docstrings).
2. Document the rule and its rationale in this README.
