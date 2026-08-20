# Fix: `behavior-harness` not blocking `git mv`

> Written for a fresh Claude Code session picking this up after a CLI restart.
> This repo (`/Users/calebm/code/cm_my-claude-plugins`, remote `github.com/CalebMorris/my-claude-plugins`)
> is the correct place to make this change — it is the real developer working copy, not the
> Claude-Code-managed marketplace clone or the installed plugin cache (see "Where NOT to edit" below).

## Context

The `behavior-harness` plugin is supposed to block Claude from mutating git state (`git mv`, `git add`,
`git commit`, etc.) via a `PreToolUse` hook. The user observed `git mv` going through unblocked and asked
for an investigation into whether the plugin is installed correctly, hooked correctly, and — if not — a
fix plan. A multi-agent investigation (3 Explore agents + 1 Plan agent) confirmed the following.

## Findings

- **Installation/registration is correct.** `behavior-harness@my-claude-plugins` v0.2.0 is properly
  installed, registered in `~/.claude/settings.json` (`enabledPlugins`) and
  `~/.claude/plugins/installed_plugins.json`, and its `hooks/hooks.json` correctly registers
  `no-git-mutations.sh` against the `Bash` matcher. This is **not** a config, permissions,
  plugin-ordering, or stale-session problem.
- **Root cause: a portability bug in the hook script itself.** `plugins/behavior-harness/hooks/no-git-mutations.sh`
  extracts the git subcommand with:
  ```
  grep -oP '(?<![\w-])git\s+\K[a-zA-Z][a-zA-Z0-9_-]*'
  ```
  This requires GNU grep's PCRE (`-P`) support. On macOS, the non-interactive `/usr/bin/grep` used when
  the hook actually runs is BSD grep, which rejects `-P` (`invalid option -- P`). The script swallows that
  error (`2>/dev/null || true`) and treats the resulting empty output as "no git subcommand found,"
  silently **allowing every git subcommand**, not just `mv`. This was independently reproduced by running
  the plugin's own bats suite: all 10 `denies git *` tests fail; all `allows *` tests pass.
- **Two smaller pre-existing gaps in the same regex**, worth closing in the same pass: it never detects
  `git -C <dir> mv ...` (the char after `git\s+` is `-`, not a letter) or a quoted subcommand like
  `git "mv" a b` (the char after `git\s+` is `"`).
- **Scope check:** the sibling hook `no-command-chaining.sh` has no PCRE/`grep -P` dependency (it already
  does a manual quote-aware bash state machine) — no changes needed there.
- **Constraint — do not reintroduce this:** an earlier attempt (in the session that did this investigation)
  to fix the bug via a `~/.claude/bin/grep` PCRE shim + `BASH_ENV` injection in `~/.claude/settings.json`
  was explicitly rejected by the user ("None of this is allowed. Revert any writes you've made") and
  reverted. The fix must stay entirely inside the plugin's own script — no environment shims, no global
  grep aliasing, no `settings.json` env changes.

## Where to edit — and where NOT to

There are three layers on disk; only one is the actual editable source:

- **`/Users/calebm/code/cm_my-claude-plugins` (this repo)** — the real developer working copy. Full
  (non-shallow) git clone of `github.com/CalebMorris/my-claude-plugins`, branch `master`. **This is the
  only place to author the fix.**
- `/Users/calebm/.claude/plugins/marketplaces/my-claude-plugins` — a shallow, Claude-Code-managed clone of
  the same GitHub repo, kept in sync via `/plugin marketplace update`. Do not hand-edit.
- `/Users/calebm/.claude/plugins/cache/my-claude-plugins/behavior-harness/0.2.0` — the installed copy
  actually referenced by `CLAUDE_PLUGIN_ROOT` at hook-runtime. Repopulated from the marketplace clone only
  when the plugin's `version` changes. Do not hand-edit.

This repo's own `README.md`/`CLAUDE.md` document the required propagation path:
**edit → commit/push to GitHub → `/plugin marketplace update my-claude-plugins` → `/reload-plugins`**,
and critically: **the cache is only repopulated when `.claude-plugin/plugin.json`'s `version` string
changes** — `/plugin marketplace update` and `/reload-plugins` alone will NOT re-copy file contents into
an already-existing version directory. Skipping the version bump means the fix would silently never reach
the running hook.

## Fix design

Replace the PCRE-based extraction in `no-git-mutations.sh` with a portable, quote-aware bash tokenizer (no
external grep dependency at all), mirroring the state-machine style already used in `no-command-chaining.sh`.
This:
- Works identically on BSD grep-only macOS and GNU/Linux (no external PCRE tool required).
- Treats `git` as a whole token (not a substring match), which gives word-boundary correctness (`mygit`,
  `digit`) for free — no lookbehind needed.
- Splits on unquoted whitespace/`|`/`;`/`&`/`(`/`)`, so pipelines are scanned (matching current behavior).
- Walks forward from a `git` token skipping leading flags (specially consuming `-C`/`-c`'s value argument)
  to find the subcommand — this closes the `git -C <dir> mv` gap as a natural side effect rather than a
  bolted-on special case.
- Drops the `2>/dev/null || true` swallow entirely — there's no external command left to fail.
  `set -euo pipefail` (already present) means a genuine bash-level error now aborts non-zero, which Claude
  Code treats as a blocking hook result (fail closed instead of fail open).
- Keeps a cheap `case "$command" in *git*) ;; *) exit 0 ;; esac` bail-out so git-free commands skip the
  tokenizer entirely.

### Files to edit in this repo

- `plugins/behavior-harness/hooks/no-git-mutations.sh` — replace the subcommand-extraction block (the
  `allowed_subcommands=...` line through the block that builds `subcommands`/checks it and denies) with a
  tokenizer along these lines (adapt variable names/message format to match the file as it currently
  reads):

  ```bash
  allowed_subcommands="status diff log show blame ls-files ls-tree rev-parse rev-list describe shortlog cat-file grep help version --version -v"

  is_allowed() {
    local sub="$1"
    local allowed
    for allowed in $allowed_subcommands; do
      if [ "$sub" = "$allowed" ]; then
        return 0
      fi
    done
    return 1
  }

  # Cheap bail-out: if "git" never appears as a substring, no git token can
  # possibly be present, so skip the tokenizer entirely.
  case "$command" in
    *git*) ;;
    *) exit 0 ;;
  esac

  # Tokenize into shell "words" without invoking any external command (no
  # grep -P / PCRE dependency — works identically on BSD grep-only macOS and
  # GNU/Linux). Splits on *unquoted* whitespace/|/;/&/(/) so pipelines and
  # chained commands are all word boundaries. Quote chars are consumed, not
  # copied, so `git "mv"` tokenizes the same as `git mv`. Purely lexical —
  # never evaluates/expands the string.
  tokens=()
  token=""
  have_token=0
  in_single=0
  in_double=0
  escaped=0
  length=${#command}
  i=0

  flush_token() {
    if [ "$have_token" -eq 1 ]; then
      tokens+=("$token")
      token=""
      have_token=0
    fi
  }

  while [ "$i" -lt "$length" ]; do
    char="${command:i:1}"

    if [ "$escaped" -eq 1 ]; then
      token+="$char"
      have_token=1
      escaped=0
      i=$((i + 1))
      continue
    fi

    case "$char" in
      '\')
        if [ "$in_single" -eq 0 ]; then
          escaped=1
        else
          token+="$char"
          have_token=1
        fi
        ;;
      "'")
        if [ "$in_double" -eq 0 ]; then
          if [ "$in_single" -eq 1 ]; then in_single=0; else in_single=1; fi
          have_token=1
        else
          token+="$char"
          have_token=1
        fi
        ;;
      '"')
        if [ "$in_single" -eq 0 ]; then
          if [ "$in_double" -eq 1 ]; then in_double=0; else in_double=1; fi
          have_token=1
        else
          token+="$char"
          have_token=1
        fi
        ;;
      ' ' | $'\t' | $'\n' | '|' | ';' | '&' | '(' | ')')
        if [ "$in_single" -eq 1 ] || [ "$in_double" -eq 1 ]; then
          token+="$char"
          have_token=1
        else
          flush_token
        fi
        ;;
      *)
        token+="$char"
        have_token=1
        ;;
    esac

    i=$((i + 1))
  done
  flush_token

  blocked=""
  n=${#tokens[@]}
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "${tokens[$i]}" = "git" ]; then
      j=$((i + 1))
      # Skip top-level git options to find the subcommand token. -C/-c take
      # a separate value argument (this is what makes `git -C <dir> mv`
      # detected: it falls out of "skip options, then look at the next
      # bare word").
      while [ "$j" -lt "$n" ]; do
        case "${tokens[$j]}" in
          -C | -c)
            j=$((j + 2))
            continue
            ;;
          -*)
            j=$((j + 1))
            continue
            ;;
          *)
            break
            ;;
        esac
      done
      if [ "$j" -lt "$n" ]; then
        sub="${tokens[$j]}"
        if ! is_allowed "$sub"; then
          blocked="$sub"
          break
        fi
      fi
    fi
    i=$((i + 1))
  done

  if [ -n "$blocked" ]; then
    reason="Blocked \`git $blocked\`: \"$command\". Claude must not change git staging, working-tree, or history state (add, checkout, restore, reset, stash, commit, branch, merge, rebase, push, pull, tag, mv, rm, clean, ...) — that's the human's job. Only read-only inspection commands are allowed ($allowed_subcommands). Make the file edits directly and ask the user to handle staging/committing."
    jq -n --arg reason "$reason" \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
    exit 0
  fi
  ```

  Also update the header comment describing the old "regex scan" to describe the tokenizer instead.

- `plugins/behavior-harness/tests/no-git-mutations.bats` — add these cases (alongside the existing
  `denies git rm` / `does not match git-like words` tests):
  ```bash
  @test "denies git mv" {
    run run_hook "Bash" 'git mv a b'
    assert_denied
  }

  @test "denies git -C <dir> mv" {
    run run_hook "Bash" 'git -C /tmp/repo mv a b'
    assert_denied
  }

  @test "denies a quoted subcommand" {
    run run_hook "Bash" 'git "mv" a b'
    assert_denied
  }

  @test "denies git mv hidden in a pipeline" {
    run run_hook "Bash" 'echo start | git mv a b'
    assert_denied
  }

  @test "allows git --version" {
    run run_hook "Bash" 'git --version'
    assert_allowed
  }

  @test "allows git -v" {
    run run_hook "Bash" 'git -v'
    assert_allowed
  }
  ```
  (Match actual helper names `run_hook`/`assert_denied`/`assert_allowed` to whatever the file currently
  uses — read the file first.)

- `plugins/behavior-harness/.claude-plugin/plugin.json` — **bump `version`** from `0.2.0` to `0.2.1`.
  Required — the cache only repopulates on a version change.

No changes needed to `no-command-chaining.sh` or its bats file (confirmed no PCRE dependency there).

## Propagation steps (in order)

1. Make the edits above in this repo.
2. Run `npx bats plugins/behavior-harness/tests` and confirm **all** tests pass, including the
   previously-failing `denies git *` set (add, checkout, restore, reset, commit, stash, branch, push, rm,
   mv, pipeline-hidden) and the new gap-closing cases (`-C <dir> mv`, quoted subcommand).
3. `git add`/`git commit` the change in this repo (confirm with the user before pushing — pushing is a
   shared-state action per standing git-safety rules).
4. `git push` to `github.com/CalebMorris/my-claude-plugins`.
5. In a Claude Code session: `/plugin marketplace update my-claude-plugins` (syncs the shallow marketplace
   clone — note it may be a couple commits behind on unrelated changes too).
6. `/reload-plugins` to re-register hooks — this should also trigger cache repopulation for the new
   version (the version bump is what gates this).
7. Confirm a new `/Users/calebm/.claude/plugins/cache/my-claude-plugins/behavior-harness/0.2.1/` directory
   exists with the fixed script, and that `installed_plugins.json`'s `installPath` for
   `behavior-harness@my-claude-plugins` now points at it.

## Verification

1. Manually invoke the newly-cached hook the same way the plugin runtime does, e.g.:
   ```
   echo '{"tool_name":"Bash","tool_input":{"command":"git mv a b"}}' | bash /Users/calebm/.claude/plugins/cache/my-claude-plugins/behavior-harness/0.2.1/hooks/no-git-mutations.sh
   ```
   and confirm it prints a `permissionDecision: "deny"` JSON payload instead of exiting silently.
2. In a fresh Claude Code session (so the reloaded hook is active), attempt `git mv <file> <other>` and
   confirm it is actually blocked live, not just in the bats suite.
3. Do **not** re-add any grep-shim/`BASH_ENV`/environment-level workaround, and do **not** hand-edit the
   marketplace clone or cache copies directly — the only authored diff should be in this repo; everything
   downstream comes from the propagation steps above.
