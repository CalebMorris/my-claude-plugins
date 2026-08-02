# Claude.md

## Plugin version bump is required on every change

`~/.claude/plugins/cache/my-claude-plugins/<plugin>/<version>/` is keyed by
the `version` field in that plugin's `.claude-plugin/plugin.json`. The cache
is only repopulated when the version string changes — `/plugin marketplace
update` and `/reload-plugins` do NOT re-copy content into an existing
version's cache directory, even after the change is committed and pushed.

Any change to a plugin's files (hooks, commands, agents, skills) MUST bump
that plugin's `version` in `.claude-plugin/plugin.json`, or the change will
silently never take effect in an installed session no matter how many times
the marketplace/plugins are reloaded.
