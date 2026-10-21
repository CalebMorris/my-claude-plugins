#!/bin/bash
# PreToolUse hook (matcher: Bash): denies any `git` invocation whose subcommand is not on a small read-only allowlist.
#
# Why: git staging/working-tree/history state (git add, checkout, reset, commit, stash, branch, merge, rebase, push, ...) is the human's to manage, not Claude's.
# Claude is responsible for making file edits directly; the human reviews and stages/commits them.
# A denylist of "dangerous" git subcommands is easy to bypass with a subcommand nobody thought to list, so this uses the opposite default: only a short list of read-only, state-inspecting subcommands is allowed, and everything else is denied.
#
# Detection splits the command into shell words with a quote-aware tokenizer written in pure bash, and it must stay that way: the earlier `grep -oP` detection was rejected outright by BSD grep on macOS, and the swallowed error read as "no git in this command", allowing every subcommand.
# Unquoted whitespace, |, ;, &, ( and ) all end a word, so git is found inside a pipeline (`git log | head`) and inside a $(...) substitution.
# Redirections (`2>&1`, `>file`, `&>/dev/null`) are dropped along with their target, so they are never read as a subcommand or action.
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

# Subcommands that both read and mutate are allowed only in their read-only forms: no action at all (a listing), or one of read_only_actions_<sub>, optionally after any of read_only_flags_<sub>.
# Every other action is denied and named in the reason. To cover another such subcommand, add it here and define its two lists.
mixed_subcommands="remote"
read_only_flags_remote="-v --verbose -h --help"
read_only_actions_remote="get-url show"

in_list() {
  local word="$1"
  local item
  for item in $2; do
    if [ "$word" = "$item" ]; then
      return 0
    fi
  done
  return 1
}

# Prints the action that makes a mixed subcommand call mutating and succeeds, or prints nothing and fails when the call is read-only.
# The scan starts at the token after the subcommand and stops at the end of its segment, so `git remote | head` is a bare listing rather than an action named head.
mutating_action() {
  local sub="$1"
  local k="$2"
  local count=${#tokens[@]}
  local flags_var="read_only_flags_$sub"
  local actions_var="read_only_actions_$sub"
  while [ "$k" -lt "$count" ]; do
    if [ "${segment_end[$((k - 1))]}" -eq 1 ]; then
      return 1
    fi
    if in_list "${tokens[$k]}" "${!flags_var}"; then
      k=$((k + 1))
      continue
    fi
    if in_list "${tokens[$k]}" "${!actions_var}"; then
      return 1
    fi
    printf '%s' "${tokens[$k]}"
    return 0
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
# Parallel to tokens: 1 when an unquoted |, ;, &, (, ) or newline follows the token, marking the end of its command segment.
segment_end=()
token=""
have_token=0
in_single=0
in_double=0
escaped=0
# 1 while the next word is a redirection target, which is dropped rather than kept as a token.
redirect_target=0
length=${#command}
i=0

flush_token() {
  if [ "$have_token" -eq 1 ]; then
    if [ "$redirect_target" -eq 1 ]; then
      redirect_target=0
    else
      tokens+=("$token")
      segment_end+=(0)
    fi
    token=""
    have_token=0
  fi
}

# Consumes the rest of a redirection operator starting at index i (>, >>, 2>, 2>&1, &>, <, <<<, >|, ...) and marks the following word as its target.
# The operator and its target are dropped, so `git remote -v 2>&1` reads as `git remote -v`, while words after the target still count: `git remote >/dev/null add x` runs `git remote add x`.
consume_redirect() {
  while [ $((i + 1)) -lt "$length" ]; do
    case "${command:i+1:1}" in
      '<' | '>') i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  case "${command:i+1:1}" in
    '&' | '|') i=$((i + 1)) ;;
  esac
  redirect_target=1
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
    ' ' | $'\t')
      if [ "$in_single" -eq 1 ] || [ "$in_double" -eq 1 ]; then
        token+="$char"
        have_token=1
      else
        flush_token
      fi
      ;;
    '<' | '>')
      if [ "$in_single" -eq 1 ] || [ "$in_double" -eq 1 ]; then
        token+="$char"
        have_token=1
      else
        # Digits glued to the operator name its file descriptor (`2>`), so they are dropped rather than kept as an argument.
        case "$token" in
          '' | *[!0-9]*) flush_token ;;
          *)
            token=""
            have_token=0
            ;;
        esac
        consume_redirect
      fi
      ;;
    '&')
      if [ "$in_single" -eq 1 ] || [ "$in_double" -eq 1 ]; then
        token+="$char"
        have_token=1
      elif [ "${command:i+1:1}" = '>' ]; then
        flush_token
        i=$((i + 1))
        consume_redirect
      else
        flush_token
        redirect_target=0
        if [ "${#tokens[@]}" -gt 0 ]; then
          segment_end[$((${#tokens[@]} - 1))]=1
        fi
      fi
      ;;
    '|' | ';' | '(' | ')' | $'\n')
      if [ "$in_single" -eq 1 ] || [ "$in_double" -eq 1 ]; then
        token+="$char"
        have_token=1
      else
        flush_token
        redirect_target=0
        if [ "${#tokens[@]}" -gt 0 ]; then
          segment_end[$((${#tokens[@]} - 1))]=1
        fi
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
      if in_list "$sub" "$mixed_subcommands"; then
        if action=$(mutating_action "$sub" $((j + 1))); then
          blocked="$sub $action"
          break
        fi
      elif ! in_list "$sub" "$allowed_subcommands"; then
        blocked="$sub"
        break
      fi
    fi
  fi
  i=$((i + 1))
done

if [ -n "$blocked" ]; then
  read_only_forms=""
  for sub in $mixed_subcommands; do
    flags_var="read_only_flags_$sub"
    actions_var="read_only_actions_$sub"
    read_only_forms+=", plus $sub with no action or one of ${!actions_var}, optionally after ${!flags_var}"
  done
  reason="Blocked \`git $blocked\`: \"$command\". Claude must not change git staging, working-tree, or history state (add, checkout, restore, reset, stash, commit, branch, merge, rebase, push, pull, tag, mv, rm, clean, ...) — that's the human's job. Only read-only inspection commands are allowed ($allowed_subcommands$read_only_forms). Make the file edits directly and ask the user to handle staging/committing."
  jq -n --arg reason "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
fi

exit 0
