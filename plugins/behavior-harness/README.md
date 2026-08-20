# behavior-harness

Hooks that steer Claude away from specific bad behaviors during a session.
Starts simply and is meant to grow: each behavior gets its own hook script
and its own test file.

## Try it locally

```bash
claude --plugin-dir plugins/behavior-harness
```

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

**Detection:** the command is split into shell words by a quote-aware tokenizer, so a `git` invocation is recognized wherever it appears — inside a pipeline (`git log | head`), behind top-level flags (`git -C /some/repo mv a b`), with a quoted subcommand (`git "mv" a b`), or called by path (`/usr/bin/git mv a b`).
Words that merely contain `git`, like `mygit` and `digit`, are not matched.
The tokenizer needs no external command, so the hook behaves the same on macOS and Linux.

**Out of scope on purpose:** tokenizing is purely lexical — the command is never evaluated or expanded, so a subcommand assembled at runtime (`git $verb`) is not resolved and will not be blocked.
Command chaining (`;`, `&&`, `||`, newlines) is already denied by `no-command-chaining.sh`, so this hook doesn't need to reason about multiple independent statements sharing one call.

## Testing

Bash hooks have no first-party test harness, so these tests pipe a synthesized hook payload into the script and assert on its exit status and stdout.

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

## Adding a new behavior

1. Add a hook script under `hooks/` and wire it into `hooks/hooks.json`.
2. Write failing tests in `tests/<behavior>.bats` first (red), with fixtures carrying the full documented hook payload rather than only the fields the script reads.
3. Implement until `npm test` is green.
4. Document the behavior and its rationale in this README.

Keep hook scripts POSIX-portable: hooks run against BSD tools on macOS, so a GNU-only flag such as `grep -P` fails there, and an error swallowed with `2>/dev/null || true` turns that failure into a silent allow.
