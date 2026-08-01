# My Claude Plugins

A set of plugins for Claude CLI to help introduce specific desired behaviors and extensions of functionality that I want.

## Structure

This repo is a [Claude Code plugin marketplace](.claude-plugin/marketplace.json). Each plugin lives under `plugins/<plugin-name>/`.

| Plugin | Description |
|---|---|
| [`passthrough-hook-example`](plugins/passthrough-hook-example) | Bootstrap example: a `PreToolUse` hook that does nothing but pass through. Use as a template for new hook-based plugins. |
| [`behavior-harness`](plugins/behavior-harness) | Hooks that steer Claude away from specific bad behaviors, starting with blocking chained Bash commands (`;`, `&&`, `\|\|`). |

## Usage

### Install from the marketplace

Add this repo as a marketplace, then install a plugin from it:

```
/plugin marketplace add CalebMorris/my-claude-plugins
/plugin install passthrough-hook-example@my-claude-plugins
```

Update the marketplace to pick up new plugins or changes:

```
/plugin marketplace update my-claude-plugins
```

### Try a plugin locally without installing

Clone the repo and point Claude Code at a plugin directory directly:

```bash
git clone https://github.com/CalebMorris/my-claude-plugins.git
claude --plugin-dir my-claude-plugins/plugins/<plugin-name>
```
