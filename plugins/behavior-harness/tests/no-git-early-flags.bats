#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../hooks/no-git-early-flags.sh"

# Mirrors the documented PreToolUse hook payload, not just the two fields the
# hook reads, so the tests exercise the real input contract.
run_hook() {
  local tool_name="$1"
  local command="$2"
  jq -n --arg tool_name "$tool_name" --arg command "$command" \
    '{
      session_id: "test-session",
      prompt_id: "550e8400-e29b-41d4-a716-446655440000",
      transcript_path: "/tmp/transcript.jsonl",
      cwd: "/tmp/test-cwd",
      permission_mode: "default",
      effort: {level: "medium"},
      hook_event_name: "PreToolUse",
      tool_name: $tool_name,
      tool_use_id: "test-tool-use",
      tool_input: {
        command: $command,
        description: "test command",
        timeout: 120000,
        run_in_background: false
      }
    }' | bash "$HOOK"
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

# The reason must hand Claude the exact command to re-run, so the next attempt
# hits the user's allow rules instead of another prompt.
assert_reason_contains() {
  local expected="$1"
  echo "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -F -q -- "$expected"
}

@test "allows an empty command" {
  run run_hook "Bash" ''
  assert_allowed
}

@test "ignores non-Bash tool calls" {
  run run_hook "Write" 'git -c core.pager=cat log'
  assert_allowed
}

@test "allows a command with no git in it" {
  run run_hook "Bash" 'echo hi'
  assert_allowed
}

@test "allows plain git log" {
  run run_hook "Bash" 'git log --oneline -15'
  assert_allowed
}

@test "allows git status" {
  run run_hook "Bash" 'git status'
  assert_allowed
}

@test "allows options after the subcommand" {
  run run_hook "Bash" 'git log -c HEAD'
  assert_allowed
}

@test "allows git diff -c" {
  run run_hook "Bash" 'git diff -c HEAD~1'
  assert_allowed
}

@test "allows long options after the subcommand" {
  run run_hook "Bash" 'git status --short --branch'
  assert_allowed
}

@test "allows git --version" {
  run run_hook "Bash" 'git --version'
  assert_allowed
}

@test "allows git -v" {
  run run_hook "Bash" 'git -v'
  assert_allowed
}

@test "allows git --help" {
  run run_hook "Bash" 'git --help'
  assert_allowed
}

@test "allows git --help <subcommand>" {
  run run_hook "Bash" 'git --help log'
  assert_allowed
}

@test "allows git log piped to head" {
  run run_hook "Bash" 'git log | head -5'
  assert_allowed
}

@test "denies git -c log.showSignature=false log" {
  run run_hook "Bash" 'git -c log.showSignature=false log --oneline -15'
  assert_denied
}

@test "denies git -c core.pager=cat diff" {
  run run_hook "Bash" 'git -c core.pager=cat diff --stat'
  assert_denied
}

@test "denies several -c flags on one call" {
  run run_hook "Bash" 'git -c core.pager=cat -c log.showSignature=false log'
  assert_denied
}

@test "denies git -C <dir> status" {
  run run_hook "Bash" 'git -C /tmp/repo status'
  assert_denied
}

@test "denies git -C <dir> with a subcommand that takes arguments" {
  run run_hook "Bash" 'git -C /tmp/repo log --oneline -5'
  assert_denied
}

@test "denies -C combined with -c" {
  run run_hook "Bash" 'git -C /tmp/repo -c core.pager=cat status'
  assert_denied
}

@test "denies --config-env inline config" {
  run run_hook "Bash" 'git --config-env=core.pager=PAGER_VAR log'
  assert_denied
}

@test "denies -c glued to its value" {
  run run_hook "Bash" 'git -ccore.pager=cat log'
  assert_denied
}

@test "denies --no-pager" {
  run run_hook "Bash" 'git --no-pager log -3'
  assert_denied
}

@test "denies -p (paginate)" {
  run run_hook "Bash" 'git -p log -3'
  assert_denied
}

@test "denies --git-dir=<path>" {
  run run_hook "Bash" 'git --git-dir=/tmp/repo/.git status'
  assert_denied
}

@test "denies --git-dir <path> as a separate argument" {
  run run_hook "Bash" 'git --git-dir /tmp/repo/.git status'
  assert_denied
}

@test "denies --work-tree <path>" {
  run run_hook "Bash" 'git --work-tree /tmp/repo status'
  assert_denied
}

@test "denies --namespace <name>" {
  run run_hook "Bash" 'git --namespace foo log'
  assert_denied
}

@test "denies --bare" {
  run run_hook "Bash" 'git --bare rev-parse HEAD'
  assert_denied
}

@test "denies --no-optional-locks" {
  run run_hook "Bash" 'git --no-optional-locks status'
  assert_denied
}

@test "denies --literal-pathspecs" {
  run run_hook "Bash" 'git --literal-pathspecs ls-files'
  assert_denied
}

@test "denies an unknown early flag" {
  run run_hook "Bash" 'git --some-future-flag status'
  assert_denied
}

@test "denies a quoted early flag" {
  run run_hook "Bash" 'git "-c" core.pager=cat log'
  assert_denied
}

@test "denies a quoted -C flag" {
  run run_hook "Bash" 'git "-C" /tmp/repo status'
  assert_denied
}

@test "denies git invoked by absolute path" {
  run run_hook "Bash" '/usr/bin/git -c core.pager=cat log'
  assert_denied
}

@test "denies early flags hidden in a pipeline" {
  run run_hook "Bash" 'git -C /tmp/repo log | head -5'
  assert_denied
}

@test "denies early flags after a pipeline" {
  run run_hook "Bash" 'echo start | git -c core.pager=cat log'
  assert_denied
}

@test "reason names the offending -c flag" {
  run run_hook "Bash" 'git -c log.showSignature=false log --oneline -15'
  assert_denied
  assert_reason_contains '-c log.showSignature=false'
}

@test "reason names the offending -C flag and its value" {
  run run_hook "Bash" 'git -C /tmp/repo status'
  assert_denied
  assert_reason_contains '-C /tmp/repo'
}

@test "reason names a boolean early flag" {
  run run_hook "Bash" 'git --no-pager log'
  assert_denied
  assert_reason_contains '--no-pager'
}

@test "reason contains the command with -c stripped" {
  run run_hook "Bash" 'git -c log.showSignature=false log --oneline -15'
  assert_denied
  assert_reason_contains 'git log --oneline -15'
}

@test "reason contains the command with -C and its value stripped" {
  run run_hook "Bash" 'git -C /tmp/repo status --short'
  assert_denied
  assert_reason_contains 'git status --short'
}

@test "reason contains the command with --git-dir <path> stripped" {
  run run_hook "Bash" 'git --git-dir /tmp/repo/.git status'
  assert_denied
  assert_reason_contains 'git status'
}

@test "reason contains the command with a boolean flag stripped" {
  run run_hook "Bash" 'git --no-pager log -3'
  assert_denied
  assert_reason_contains 'git log -3'
}

@test "stripped command keeps the original quoting of surviving arguments" {
  run run_hook "Bash" 'git -c core.pager=cat log --format="%h %s" -5'
  assert_denied
  assert_reason_contains 'git log --format="%h %s" -5'
}

@test "stripped command drops every early flag" {
  run run_hook "Bash" 'git -C /tmp/repo -c core.pager=cat --no-pager log -3'
  assert_denied
  assert_reason_contains 'git log -3'
}

@test "reason explains that early flags defeat permission rules" {
  run run_hook "Bash" 'git -C /tmp/repo status'
  assert_denied
  assert_reason_contains 'permission'
}

@test "does not match git-like words that are not the git binary" {
  run run_hook "Bash" 'mygit -c core.pager=cat log'
  assert_allowed
}

@test "fails open on invalid JSON input" {
  run bash -c 'echo "not json" | bash "'"$HOOK"'"'
  assert_allowed
}
