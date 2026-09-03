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

### No early git flags (`hooks/no-git-early-flags.sh`)

A `PreToolUse` hook on the `Bash` matcher that denies any `git` invocation carrying options ahead of the subcommand — `git -* <subcommand> ...` in every form: `git -C <dir> status`, `git -c key=value log`, `git -ckey=value log`, `git --config-env=... log`, `git --no-pager log`, `git -p log`, `git --git-dir=... status`, `git --work-tree <dir> status`, `git --bare rev-parse`, and any flag git adds in the future.

**Why:** Claude habitually prefixes git commands with `-C /absolute/path`, `-c log.showSignature=false`, `-c core.pager=cat` or `--no-pager`.
Those flags add nothing — the session already runs inside the repository, and pager and signature behavior belong in the user's git config — but they break granular Bash permission rules.
An allow rule such as `Bash(git log *)` is matched against the literal command text, so `git -C /repo log --oneline` or `git -c core.pager=cat log --oneline` no longer matches and every call falls through to a manual approval prompt.

**Why not just widen the allow rule:** `Bash(git -* log *)` would match, but `-c` can set `core.pager`, `core.fsmonitor`, `core.sshCommand` and other keys that make git run an arbitrary program, `-C`/`--git-dir`/`--work-tree` retarget the command at a different repository, and `--exec-path` swaps the git binaries themselves.
Allowing any early flag reopens exactly what the narrow rule is meant to gate.
There is no Claude Code setting that turns the habit off, and CLAUDE.md guidance does not reliably override it, so denying the call is the only option that keeps the rules narrow.

**What Claude sees:** the `permissionDecisionReason` names each offending flag (with its value, for `-C`, `-c`, `--config-env`, `--git-dir`, `--work-tree` and `--namespace`), explains that early flags defeat the user's permission rules, and includes the exact same command with the flags cut out (original quoting preserved) so the retry matches the allow rule on the first attempt.

**Detection:** shares the quote-aware tokenizer used by `no-git-mutations.sh`, so a flag is caught in a pipeline, when quoted (`git "-C" ...`), or when git is called by path.
Only options *before* the subcommand count: `git log -c`, `git diff -c` and `git status --short` are subcommand options and are allowed.
`git --version`, `git -v`, `git --help` and `git -h` are the whole command rather than a prefix to one, so they are treated as the subcommand and allowed.

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
