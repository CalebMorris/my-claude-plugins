#!/bin/bash
# PreToolUse hook (matcher: Bash): denies any `git` invocation whose subcommand is not on a small read-only allowlist.
#
# Why: git staging/working-tree/history state (git add, checkout, reset, commit, stash, branch, merge, rebase, push, ...) is the human's to manage, not Claude's.
# Claude is responsible for making file edits directly; the human reviews and stages/commits them.
# A denylist of "dangerous" git subcommands is easy to bypass with a subcommand nobody thought to list, so this uses the opposite default: only a short list of read-only, state-inspecting subcommands is allowed, and everything else is denied.
#
# Detection splits the command into shell words with a quote-aware tokenizer written in pure bash, and it must stay that way: the earlier `grep -oP` detection was rejected outright by BSD grep on macOS, and the swallowed error read as "no git in this command", allowing every subcommand.
# Unquoted whitespace, |, ;, &, ( and ) all end a word, so git is found inside a pipeline (`git log | head`) and inside a $(...) substitution.
# Chaining with ;, &&, || or newlines is separately denied by no-command-chaining.sh, so this hook doesn't need to reason about multiple independent statements.
# Tokenizing is purely lexical — the command string is never evaluated or expanded — which bounds what can be caught: a subcommand assembled at runtime (`git $verb`) is never resolved, and a backtick is not a word boundary, so git inside a legacy `...` substitution is not recognized.
set -euo pipefail

input=$(cat)

tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

command=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [ -z "$command" ]; then
  exit 0
fi

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

# A token is the git binary if it is `git` itself or a path ending in /git, so `/usr/bin/git mv` is caught but `mygit`/`digit` are not.
is_git_token() {
  case "$1" in
    git | */git) return 0 ;;
    *) return 1 ;;
  esac
}

# Cheap bail-out: if "git" never appears as a substring, no git token can possibly be present, so skip the tokenizer entirely.
case "$command" in
  *git*) ;;
  *) exit 0 ;;
esac

# Tokenizer state: walk the command one character at a time, tracking quote and escape state so only unquoted separators break a word.
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

# Quote characters are consumed rather than copied into the token, so `git "mv"` tokenizes identically to `git mv`.
# have_token distinguishes an empty-but-real token (`""`) from no token at all.
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
  if is_git_token "${tokens[$i]}"; then
    j=$((i + 1))
    # Skip top-level git options to reach the subcommand token.
    # -C and -c take a separate value argument, so consume that too — otherwise `git -C <dir> status` would read <dir> as the subcommand and deny an allowed command.
    # A git call that is nothing but options (`git --version`, `git -v`) runs out of tokens here and is allowed without consulting the allowlist.
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

exit 0
