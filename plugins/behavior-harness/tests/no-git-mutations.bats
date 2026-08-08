#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../hooks/no-git-mutations.sh"

run_hook() {
  local tool_name="$1"
  local command="$2"
  jq -n --arg tool_name "$tool_name" --arg command "$command" \
    '{tool_name: $tool_name, tool_input: {command: $command}}' | bash "$HOOK"
}

assert_allowed() {
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

assert_denied() {
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null
  echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null
  [ -n "$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason')" ]
}

@test "allows an empty command" {
  run run_hook "Bash" ''
  assert_allowed
}

@test "ignores non-Bash tool calls" {
  run run_hook "Write" 'git add .'
  assert_allowed
}

@test "allows a command with no git in it" {
  run run_hook "Bash" 'echo hi'
  assert_allowed
}

@test "allows git status" {
  run run_hook "Bash" 'git status'
  assert_allowed
}

@test "allows git diff" {
  run run_hook "Bash" 'git diff --stat'
  assert_allowed
}

@test "allows git log piped to head" {
  run run_hook "Bash" 'git log | head -5'
  assert_allowed
}

@test "allows git show" {
  run run_hook "Bash" 'git show HEAD'
  assert_allowed
}

@test "denies git add" {
  run run_hook "Bash" 'git add file.txt'
  assert_denied
}

@test "denies git checkout" {
  run run_hook "Bash" 'git checkout main'
  assert_denied
}

@test "denies git restore" {
  run run_hook "Bash" 'git restore file.txt'
  assert_denied
}

@test "denies git reset" {
  run run_hook "Bash" 'git reset --hard'
  assert_denied
}

@test "denies git commit" {
  run run_hook "Bash" 'git commit -m "test"'
  assert_denied
}

@test "denies git stash" {
  run run_hook "Bash" 'git stash'
  assert_denied
}

@test "denies git branch" {
  run run_hook "Bash" 'git branch -D old'
  assert_denied
}

@test "denies git push" {
  run run_hook "Bash" 'git push origin main'
  assert_denied
}

@test "denies git rm" {
  run run_hook "Bash" 'git rm file.txt'
  assert_denied
}

@test "denies git mutation hidden after a pipeline" {
  run run_hook "Bash" 'git log | head -1 && git checkout main'
  assert_denied
}

@test "does not match git-like words that are not the git binary" {
  run run_hook "Bash" 'echo digit; mygit status'
  assert_allowed
}

@test "fails open on invalid JSON input" {
  run bash -c 'echo "not json" | bash "'"$HOOK"'"'
  assert_allowed
}
