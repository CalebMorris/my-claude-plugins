---
name: markdown-writing
description: This skill should be used when writing or editing any markdown document — README files, guides, design docs, plugin skill/command files, agent-consumed docs like CLAUDE.md, or general `.md` output. Applies house formatting rules plus document-type-specific structure guidance. Trigger phrases include "write a doc", "update the README", "create a markdown file", "write a skill", or any task that produces or edits `.md` content.
---

# Markdown Writing Guidelines

Apply the universal rules below to every markdown document. Then identify
the document's type and load the matching reference file for
type-specific structure guidance before writing.

## Universal rules

These apply regardless of document type.

### Horizontal rules

Do not use `---` horizontal rules in document bodies — they clutter docs
without adding structure. Use headings to separate sections instead.

Note: this does not apply to YAML frontmatter delimiters, which also use
`---` but serve a different, structural purpose.

### Line splitting

Break a block of text into multiple lines only at natural transition points,
such as sentence-ending punctuation ('.', '?', etc.). Do not split lines based
on line length, unless a project-specific linting rule requires it.

## Choose the document type

Markdown documents split into three types with different readers and
different structural needs. Load the reference file that matches before
writing or restructuring a document — do not apply one type's rules to
another.

| Document type | Reader | Examples | Reference |
|---|---|---|---|
| Agentic document | Claude or another agent | `SKILL.md`, `CLAUDE.md`, command/agent markdown, any doc loaded into an agent's context | @references/agentic-document.md |
| Human documentation | A human developer | Guides, how-tos, design docs, RFCs, runbooks, tutorials | @references/human-documentation.md |
| Top-level README | A newcomer evaluating the project | The repo or package root `README.md` | @references/readme.md |

If the type is ambiguous, use these signals in order: the file name/path
(`README.md` at a project root is always the README type; `SKILL.md`,
`CLAUDE.md`, `AGENTS.md`, or files under a plugin's `commands/`/`agents/`
directories are always agentic), then who reads the file day-to-day, then
ask the user.

A single project can and should contain all three types — they are not
alternatives to pick once, but different jobs a document can do.
