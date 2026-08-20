# My Claude Plugins

A set of plugins for Claude CLI to help introduce specific desired behaviors and extensions of functionality that I want.

## Structure

This repo is a [Claude Code plugin marketplace](.claude-plugin/marketplace.json). Each plugin lives under `plugins/<plugin-name>/`.

| Plugin | Description |
|---|---|
| [`behavior-harness`](plugins/behavior-harness) | Hooks that steer Claude away from specific bad behaviors: blocking chained Bash commands (`;`, `&&`, `\|\|`) and blocking git staging/history mutations. |
| [`documentation-manager`](plugins/documentation-manager) | Skills that steer how Claude writes and maintains documentation, starting with markdown formatting rules. |
| [`reference-skills`](plugins/reference-skills) | A vendored bundle of third-party reference skills (Jetpack Compose, Robolectric, and more over time), installed as one plugin. |

## Usage

### Install from the marketplace

Add this repo as a marketplace, then install a plugin from it:

```
/plugin marketplace add CalebMorris/my-claude-plugins
/plugin install reference-skills@my-claude-plugins
```

### Updating an installed plugin after a change

1. Bump `version` in the plugin's `.claude-plugin/plugin.json`.
2. Commit and push the change to GitHub.
3. `/plugin marketplace update my-claude-plugins` — pulls the new commit into your installed copy.
4. `/reload-plugins` — re-registers hooks from the updated copy.
5. Confirm `~/.claude/plugins/cache/my-claude-plugins/<plugin>/<new-version>/` exists and contains the files you changed.

Every step is required.
The installed copy is keyed by the version string, and neither `/plugin marketplace update` nor `/reload-plugins` re-copies content into a version's existing cache directory — so without the bump in step 1, the change silently never takes effect.

### Try a plugin locally without installing

Clone the repo and point Claude Code at a plugin directory directly:

```bash
git clone https://github.com/CalebMorris/my-claude-plugins.git
claude --plugin-dir my-claude-plugins/plugins/<plugin-name>
```
