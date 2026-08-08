#!/bin/bash
# PreToolUse hook (matcher: Bash): denies any `git` invocation whose
# subcommand is not on a small read-only allowlist.
#
# Why: git staging/working-tree/history state (git add, checkout, reset,
# commit, stash, branch, merge, rebase, push, ...) is the human's to manage,
# not Claude's. Claude is responsible for making file edits directly; the
# human reviews and stages/commits them. A denylist of "dangerous" git
# subcommands is easy to bypass with a subcommand nobody thought to list, so
# this uses the opposite default: only a short list of read-only,
# state-inspecting subcommands is allowed, and everything else is denied.
#
# Detection scans the whole command string for `git <subcommand>` tokens
# (so it also catches git run inside a pipeline, e.g. `git log | head`),
# rather than trying to fully parse the command — command chaining with
# ;, &&, ||, or newlines is already denied by no-command-chaining.sh, so
# this hook doesn't need to reason about multiple independent statements.
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

subcommands=$(printf '%s' "$command" | grep -oP '(?<![\w-])git\s+\K[a-zA-Z][a-zA-Z0-9_-]*' 2>/dev/null || true)

if [ -z "$subcommands" ]; then
  exit 0
fi

blocked=""
while IFS= read -r sub; do
  [ -z "$sub" ] && continue
  if ! is_allowed "$sub"; then
    blocked="$sub"
    break
  fi
done <<< "$subcommands"

if [ -n "$blocked" ]; then
  reason="Blocked \`git $blocked\`: \"$command\". Claude must not change git staging, working-tree, or history state (add, checkout, restore, reset, stash, commit, branch, merge, rebase, push, pull, tag, mv, rm, clean, ...) — that's the human's job. Only read-only inspection commands are allowed ($allowed_subcommands). Make the file edits directly and ask the user to handle staging/committing."
  jq -n --arg reason "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
fi

exit 0
