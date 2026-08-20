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

## Hooks

- Hooks fail open: exit 2 blocks unconditionally; any other nonzero exit lets the tool call proceed.
- Emit the deny JSON and exit 0. Never rely on a `set -e` abort to block.
- Never swallow errors (`2>/dev/null || true`) in a detection path — an empty result reads as "allow".
- Keep hook scripts POSIX-portable. Hooks run with BSD tools on macOS: no `grep -P`, no GNU-only flags.
- Synthesize the full documented payload in test fixtures, not just the fields the hook reads.
