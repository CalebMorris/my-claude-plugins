#!/bin/bash
# PreToolUse hook (matcher: Bash): denies any `git` invocation that carries options ahead of the subcommand (`git -C <dir> status`, `git -c key=value log`, `git --no-pager log`, `git --git-dir=... status`, ...).
#
# Why: Claude habitually prefixes git commands with early flags such as `-C /abs/path`, `-c log.showSignature=false`, `-c core.pager=cat` or `--no-pager`. Those flags add nothing (the session already runs in the repository, and pager and signature behavior belong in the user's git config), but they break the user's granular Bash permission rules: an allow rule such as `Bash(git log *)` is matched against the literal command text, so `git -C /repo log` or `git -c core.pager=cat log` no longer matches and every call falls through to a manual approval prompt.
# Widening the rules to `Bash(git -* log *)` is not an acceptable fix — `-c` can set `core.pager`, `core.fsmonitor`, `core.sshCommand` and other keys that make git run an arbitrary program, `--git-dir`/`--work-tree`/`-C` retarget the command at a different repository, and `--exec-path` swaps the git binaries themselves. Allowing any early flag reopens exactly what the granular rule is meant to gate. Denying the flag and telling Claude to re-run without it is the only option that keeps the rules narrow.
# There is no setting to turn the habit off and CLAUDE.md guidance does not reliably override it, so this hook denies the call and hands Claude the exact command to re-run instead.
#
# Only options *before* the subcommand count. `-c` after the subcommand (`git log -c`, `git diff -c`) is the combined-diff option and is left alone, as is every other subcommand option.
# `--version`, `-v`, `--help` and `-h` are not early flags: they *are* the command (git prints and exits), so they are treated as the subcommand and allowed.
#
# Detection splits the command into shell words with a quote-aware tokenizer written in pure bash, and it must stay that way: BSD grep on macOS rejects `grep -P`, and a swallowed error reads as "no git in this command", allowing everything.
# Unquoted whitespace, |, ;, &, ( and ) all end a word, so git is found inside a pipeline and inside a $(...) substitution.
# Tokenizing is purely lexical — the command string is never evaluated or expanded — so a flag assembled at runtime (`git $opts log`) is never resolved, and a backtick is not a word boundary.
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

# A token is the git binary if it is `git` itself or a path ending in /git, so `/usr/bin/git` is caught but `mygit`/`digit` are not.
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
# Alongside each token we record the character offsets where it starts and ends in the original string, so the offending flags can be cut out of the command verbatim (keeping the user's quoting intact) for the suggested re-run.
tokens=()
starts=()
ends=()
token=""
token_start=0
have_token=0
in_single=0
in_double=0
escaped=0
length=${#command}
i=0

mark_token() {
  if [ "$have_token" -eq 0 ]; then
    token_start=$i
  fi
  have_token=1
}

flush_token() {
  if [ "$have_token" -eq 1 ]; then
    tokens+=("$token")
    starts+=("$token_start")
    ends+=("$i")
    token=""
    have_token=0
  fi
}

# Quote characters are consumed rather than copied into the token, so `git "-C"` tokenizes identically to `git -C`.
# have_token distinguishes an empty-but-real token (`""`) from no token at all.
while [ "$i" -lt "$length" ]; do
  char="${command:i:1}"

  if [ "$escaped" -eq 1 ]; then
    mark_token
    token+="$char"
    escaped=0
    i=$((i + 1))
    continue
  fi

  case "$char" in
    '\')
      if [ "$in_single" -eq 0 ]; then
        mark_token
        escaped=1
      else
        mark_token
        token+="$char"
      fi
      ;;
    "'")
      if [ "$in_double" -eq 0 ]; then
        mark_token
        if [ "$in_single" -eq 1 ]; then in_single=0; else in_single=1; fi
      else
        mark_token
        token+="$char"
      fi
      ;;
    '"')
      if [ "$in_single" -eq 0 ]; then
        mark_token
        if [ "$in_double" -eq 1 ]; then in_double=0; else in_double=1; fi
      else
        mark_token
        token+="$char"
      fi
      ;;
    ' ' | $'\t' | $'\n' | '|' | ';' | '&' | '(' | ')')
      if [ "$in_single" -eq 1 ] || [ "$in_double" -eq 1 ]; then
        mark_token
        token+="$char"
      else
        flush_token
      fi
      ;;
    *)
      mark_token
      token+="$char"
      ;;
  esac

  i=$((i + 1))
done
flush_token

# Each offending flag contributes a removal span [start, end) over the original command; the end is pushed past any trailing blanks so the cut leaves single spacing behind.
found_flags=""
span_starts=()
span_ends=()

record_span() {
  local start="$1"
  local end="$2"
  while [ "$end" -lt "$length" ]; do
    case "${command:end:1}" in
      ' ' | $'\t') end=$((end + 1)) ;;
      *) break ;;
    esac
  done
  span_starts+=("$start")
  span_ends+=("$end")
}

add_found() {
  if [ -n "$found_flags" ]; then
    found_flags="$found_flags, "
  fi
  found_flags="$found_flags\`$1\`"
}

n=${#tokens[@]}
i=0
while [ "$i" -lt "$n" ]; do
  if is_git_token "${tokens[$i]}"; then
    j=$((i + 1))
    # Walk the top-level git options ahead of the subcommand. Every one of them is denied. The first token that is not an option (or an option's value) is the subcommand, and nothing after it counts.
    while [ "$j" -lt "$n" ]; do
      tok="${tokens[$j]}"
      case "$tok" in
        --version | -v | --help | -h)
          # These are the whole command, not a prefix to one: git prints and exits. Treat them as the subcommand.
          break
          ;;
        -C | -c | --config-env | --git-dir | --work-tree | --namespace)
          # Options that take a separate value argument: deny the flag and consume its value so the value is not mistaken for the subcommand, and so the stripped re-run drops both.
          if [ $((j + 1)) -lt "$n" ]; then
            add_found "$tok ${tokens[$((j + 1))]}"
            record_span "${starts[$j]}" "${ends[$((j + 1))]}"
            j=$((j + 2))
          else
            add_found "$tok"
            record_span "${starts[$j]}" "${ends[$j]}"
            j=$((j + 1))
          fi
          continue
          ;;
        -*)
          # Every other early option, known or not: glued-value forms (`-ckey=value`, `--git-dir=path`), booleans (`--no-pager`, `-p`, `--bare`), and anything git adds later.
          add_found "$tok"
          record_span "${starts[$j]}" "${ends[$j]}"
          j=$((j + 1))
          continue
          ;;
        *)
          break
          ;;
      esac
    done
  fi
  i=$((i + 1))
done

if [ -n "$found_flags" ]; then
  # Remove spans back-to-front so earlier offsets stay valid.
  stripped="$command"
  k=${#span_starts[@]}
  while [ "$k" -gt 0 ]; do
    k=$((k - 1))
    s="${span_starts[$k]}"
    e="${span_ends[$k]}"
    stripped="${stripped:0:s}${stripped:e}"
  done

  reason="Blocked early git flags ($found_flags) in: \"$command\". Never put options between \`git\` and its subcommand — no \`-C <dir>\`, no \`-c key=value\`, no \`--no-pager\`, no \`--git-dir\`, nothing. They add nothing (the session already runs inside the repository, and pager and signature behavior are governed by the user's git config) and they defeat the user's granular Bash permission rules: an allow rule such as Bash(git log *) is matched against the literal command text, so \`git -C ... log\` or \`git -c ... log\` no longer matches and forces a manual approval prompt every time. Re-run the same command with the early flags removed: $stripped"
  jq -n --arg reason "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
fi

exit 0
