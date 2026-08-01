# My Claude Plugins

A set of plugins for Claude CLI to help introduce specific desired behaviors and extensions of functionality that I want.

## Structure

This repo is a [Claude Code plugin marketplace](.claude-plugin/marketplace.json). Each plugin lives under `plugins/<plugin-name>/`.

| Plugin | Description |
|---|---|
| [`passthrough-hook-example`](plugins/passthrough-hook-example) | Bootstrap example: a `PreToolUse` hook that does nothing but pass through. Use as a template for new hook-based plugins. |

To try a plugin locally:

```bash
claude --plugin-dir /path/to/plugins/<plugin-name>
```
