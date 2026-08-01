#!/bin/bash
# PreToolUse hook (matcher: Bash): denies commands that sequence multiple
# statements with unquoted ;, newlines, &&, or ||.
#
# Why: Claude Code's Bash permission checks evaluate the command string as a
# whole. Chaining lets a command that would fail an allow/deny check ride
# along with one that would pass, silently defeating per-command permission
# checks. A multi-line command (one statement per line, no trailing `\`) is
# the same trick with a different delimiter, so it's denied with the same
# message as a `;`-chained command. Pipes (|) are intentionally left alone: a
# pipeline is a single logical data-flow operation (e.g. `git log | head`),
# not a sequence of unrelated commands, and is common enough that flagging it
# would be more disruptive than protective.
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

in_single=0
in_double=0
escaped=0
found=""
length=${#command}
i=0

while [ "$i" -lt "$length" ]; do
  char="${command:i:1}"

  if [ "$escaped" -eq 1 ]; then
    escaped=0
    i=$((i + 1))
    continue
  fi

  case "$char" in
    '\')
      if [ "$in_single" -eq 0 ]; then
        escaped=1
      fi
      ;;
    "'")
      if [ "$in_double" -eq 0 ]; then
        if [ "$in_single" -eq 1 ]; then in_single=0; else in_single=1; fi
      fi
      ;;
    '"')
      if [ "$in_single" -eq 0 ]; then
        if [ "$in_double" -eq 1 ]; then in_double=0; else in_double=1; fi
      fi
      ;;
    ';')
      if [ "$in_single" -eq 0 ] && [ "$in_double" -eq 0 ]; then
        found=";"
      fi
      ;;
    $'\n')
      if [ "$in_single" -eq 0 ] && [ "$in_double" -eq 0 ]; then
        found=$'\n'
      fi
      ;;
    '&')
      if [ "$in_single" -eq 0 ] && [ "$in_double" -eq 0 ]; then
        next="${command:$((i + 1)):1}"
        if [ "$next" = "&" ]; then
          found="&&"
          i=$((i + 1))
        fi
      fi
      ;;
    '|')
      if [ "$in_single" -eq 0 ] && [ "$in_double" -eq 0 ]; then
        next="${command:$((i + 1)):1}"
        if [ "$next" = "|" ]; then
          found="||"
          i=$((i + 1))
        fi
      fi
      ;;
  esac

  if [ -n "$found" ]; then
    break
  fi

  i=$((i + 1))
done

if [ -n "$found" ]; then
  label="$found"
  if [ "$found" = $'\n' ]; then
    label="newline"
  fi
  reason="Command chaining detected (\`$label\`): \"$command\". Run one command per Bash tool call instead of chaining with ;, newlines, &&, or || — a chained command (on one line or split across lines) is checked as a single string, so an unapproved command can ride along with an approved one and defeat per-command permission checks. Split this into separate Bash calls (or use | if it's genuinely one pipeline)."
  jq -n --arg reason "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
fi

exit 0
