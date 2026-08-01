# passthrough-hook-example

Minimal bootstrap plugin. Its only component is a `PreToolUse` hook that
matches every tool call, reads the input, and exits `0` without changing
anything — a no-op scaffold to build real hooks from.

## What it does

`hooks/hooks.json` registers `hooks/passthrough.sh` on `PreToolUse` for all
tools (`matcher: "*"`). The script consumes stdin and exits `0`, allowing
every tool call to proceed unchanged.

## Use as a template

Copy this plugin directory and:

1. Update `.claude-plugin/plugin.json` (`name`, `description`).
2. Narrow the `matcher` in `hooks/hooks.json` to the tools you care about.
3. Replace the logic in `hooks/passthrough.sh` (or switch to a `prompt`-type
   hook) with real validation/automation.

## Testing locally

```bash
echo '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/test"}}' | \
  bash hooks/passthrough.sh
echo "Exit code: $?"
```

Run Claude Code against this plugin directory with:

```bash
claude --plugin-dir /path/to/plugins/passthrough-hook-example
```
