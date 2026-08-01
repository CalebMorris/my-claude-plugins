# behavior-harness

Hooks that steer Claude away from specific bad behaviors during a session.
Starts simply and is meant to grow: each behavior gets its own hook script
and its own test file.

## Behaviors covered

### No command chaining (`hooks/no-command-chaining.sh`)

A `PreToolUse` hook on the `Bash` matcher that denies commands sequenced
with unquoted `;`, `&&`, or `||`.

**Why:** Claude Code's Bash permission checks evaluate the command string
as a whole. `echo "test"; echo "test2"` runs two independent commands in
one tool call — if either half wouldn't pass an allow/deny rule on its
own, chaining lets it ride along with the half that would, silently
defeating per-command permission checks. The fix is procedural: one
command per `Bash` call.

**Out of scope on purpose:** pipes (`|`) are left alone. A pipeline like
`git log | head -5` is a single data-flow operation, not a sequence of
unrelated commands, and is common enough that flagging it would cause
more friction than it prevents.

When the hook denies a call, it returns a `permissionDecisionReason`
naming the operator it found and the offending command, so Claude sees
why the call was blocked and knows to split it into separate `Bash`
calls next time.

## Testing

Tests use [bats-core](https://github.com/bats-core/bats-core), installed
locally as a dev dependency (no sudo/global install required):

```bash
npm install --prefix plugins/behavior-harness
npm test --prefix plugins/behavior-harness
```

You can also invoke the hook script directly with sample JSON on stdin:

```bash
echo '{"tool_name": "Bash", "tool_input": {"command": "echo a; echo b"}}' | \
  bash plugins/behavior-harness/hooks/no-command-chaining.sh
```

## Try it locally

```bash
claude --plugin-dir plugins/behavior-harness
```

## Adding a new behavior

1. Add a hook script under `hooks/` and wire it into `hooks/hooks.json`.
2. Write failing tests in `tests/<behavior>.bats` first (red).
3. Implement until `npm test` is green.
4. Document the behavior and its rationale in this README.
