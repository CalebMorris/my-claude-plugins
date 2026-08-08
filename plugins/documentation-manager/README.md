# documentation-manager

Skills that steer how Claude writes and maintains documentation. Starts
simply and is meant to grow: each documentation convention gets its own
skill.

## Skills

### markdown-writing (`skills/markdown-writing`)

House formatting rules for markdown documents (README files, guides,
design docs, plugin skill/command files). Currently covers:

- No `---` horizontal rules in document bodies — use headings instead.

## Try it locally

```bash
claude --plugin-dir plugins/documentation-manager
```

## Adding a new convention

1. Either add a new rule to an existing skill's `SKILL.md`, or create a new
   skill under `skills/<topic>/SKILL.md` if the convention covers a
   distinct topic (e.g. commit messages, docstrings).
2. Document the rule and its rationale in this README.
