#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../hooks/no-command-chaining.sh"

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

@test "allows a plain single command" {
  run run_hook "Bash" 'echo "test"'
  assert_allowed
}

@test "allows a semicolon inside double quotes" {
  run run_hook "Bash" 'echo "foo; bar"'
  assert_allowed
}

@test "allows a semicolon inside single quotes" {
  run run_hook "Bash" "echo 'foo; bar'"
  assert_allowed
}

@test "allows piping between commands" {
  run run_hook "Bash" 'git log | head -5'
  assert_allowed
}

@test "allows an empty command" {
  run run_hook "Bash" ''
  assert_allowed
}

@test "ignores non-Bash tool calls" {
  run run_hook "Write" 'echo "test"; echo "test2"'
  assert_allowed
}

@test "denies semicolon-chained commands" {
  run run_hook "Bash" 'echo "test"; echo "test2"'
  assert_denied
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecisionReason | contains(";")' >/dev/null
}

@test "denies && chained commands" {
  run run_hook "Bash" 'npm test && git push'
  assert_denied
}

@test "denies || chained commands" {
  run run_hook "Bash" 'false || echo hi'
  assert_denied
}

@test "fails open on invalid JSON input" {
  run bash -c 'echo "not json" | bash "'"$HOOK"'"'
  assert_allowed
}

@test "denies a bare &&" {
  run run_hook "Bash" '&&'
  assert_denied
}

@test "denies a bare ;" {
  run run_hook "Bash" ';'
  assert_denied
}

@test "allows a bare pipe" {
  run run_hook "Bash" '|'
  assert_allowed
}

@test "allows a single trailing background &" {
  run run_hook "Bash" 'echo hi &'
  assert_allowed
}

@test "does not hang or crash on an unterminated quote" {
  run run_hook "Bash" 'echo "unterminated'
  [ "$status" -eq 0 ]
}

@test "denies newline-chained commands" {
  run run_hook "Bash" $'echo "test"\necho "test2"'
  assert_denied
  echo "$output" | jq -e '.hookSpecificOutput.permissionDecisionReason | contains("newline")' >/dev/null
}

@test "treats a command that is only a trailing newline as empty (allowed)" {
  # $(...) command substitution strips trailing newlines, so a string that is
  # nothing but newline(s) collapses to "" before it ever reaches the scanner
  # — same as the existing empty-command case, not a chaining bypass.
  run run_hook "Bash" $'\n'
  assert_allowed
}

@test "denies a multi-line background-and-follow-up command" {
  run run_hook "Bash" $'pnpm dev > /tmp/log 2>&1 &\ndisown\nsleep 3\ncat /tmp/log'
  assert_denied
}

@test "allows a semicolon inside a multi-line double-quoted string" {
  run run_hook "Bash" $'echo "line one\nline two; still one string"'
  assert_allowed
}

@test "allows a backslash-continued multi-line command" {
  run run_hook "Bash" $'echo hi \\\necho bye'
  assert_allowed
}

@test "uses the same deny message template for ; and newline chaining" {
  run run_hook "Bash" 'echo "test"; echo "test2"'
  semicolon_reason=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason')
  # Strip the leading "Command chaining detected (`LABEL`): \"COMMAND\"." prefix
  # (which necessarily differs — different delimiter, different command text)
  # and compare only the shared explanatory boilerplate that follows it.
  semicolon_template="${semicolon_reason#*. }"

  run run_hook "Bash" $'echo "test"\necho "test2"'
  newline_reason=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason')
  newline_template="${newline_reason#*. }"

  [ -n "$semicolon_template" ]
  [ "$semicolon_template" = "$newline_template" ]
}
