# My Claude Plugins

A set of plugins for Claude CLI to help introduce specific desired behaviors and extensions of functionality that I want.

## Structure

This repo is a [Claude Code plugin marketplace](.claude-plugin/marketplace.json). Each plugin lives under `plugins/<plugin-name>/`.

| Plugin | Description |
|---|---|
| [`behavior-harness`](plugins/behavior-harness) | Hooks that steer Claude away from specific bad behaviors, starting with blocking chained Bash commands (`;`, `&&`, `\|\|`). |
| [`documentation-manager`](plugins/documentation-manager) | Skills that steer how Claude writes and maintains documentation, starting with markdown formatting rules. |

## Usage

### Install from the marketplace

Add this repo as a marketplace, then install a plugin from it:

```
/plugin marketplace add CalebMorris/my-claude-plugins
/plugin install behavior-harness@my-claude-plugins
```

### Updating an installed plugin after a change

1. Commit and push the change to GitHub.
2. `/plugin marketplace update my-claude-plugins` — pulls the new commit into
   your installed copy.
3. `/reload-plugins` — re-registers hooks from the updated copy.

Both steps are required. `/reload-plugins` alone will not pick up new
commits — it only re-registers whatever is already installed.

### Try a plugin locally without installing

Clone the repo and point Claude Code at a plugin directory directly:

```bash
git clone https://github.com/CalebMorris/my-claude-plugins.git
claude --plugin-dir my-claude-plugins/plugins/<plugin-name>
```
