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

### No git mutations (`hooks/no-git-mutations.sh`)

A `PreToolUse` hook on the `Bash` matcher that denies any `git`
invocation whose subcommand isn't on a small read-only allowlist
(`status`, `diff`, `log`, `show`, `blame`, `ls-files`, `ls-tree`,
`rev-parse`, `rev-list`, `describe`, `shortlog`, `cat-file`, `grep`,
`help`, `version`/`--version`/`-v`).

**Why:** git staging, working-tree, and history state (`add`,
`checkout`, `restore`, `reset`, `commit`, `stash`, `branch`, `merge`,
`rebase`, `push`, `pull`, `tag`, `mv`, `rm`, `clean`, ...) is the
human's to manage, not Claude's. Claude is responsible for making file
edits directly; the human reviews and stages/commits them. The hook
uses an allowlist rather than a denylist of "dangerous" subcommands,
since a denylist is trivially bypassed by any mutating subcommand
nobody thought to add to it.

**Out of scope on purpose:** the hook scans the command string for
`git <subcommand>` tokens rather than fully parsing shell syntax, so it
also catches git run inside a pipeline (e.g. `git log | head`).
Command chaining (`;`, `&&`, `||`, newlines) is already denied by
`no-command-chaining.sh`, so this hook doesn't need to reason about
multiple independent statements sharing one call.

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
