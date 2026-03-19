#!/usr/bin/env bats

# Tests for: git shadow check-shadow-push (pre-push hook logic)
#
# The pre-push hook passes remote info as $1/$2 and branch refs on stdin:
#   <local-ref> <local-sha1> <remote-ref> <remote-sha1>

setup() {
  TEST_DIR="$(mktemp -d)"
  XDG_DIR="$(mktemp -d)"
  export XDG_CONFIG_HOME="$XDG_DIR"
  cd "$TEST_DIR"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
  git symbolic-ref HEAD refs/heads/main
  echo "initial" > file.txt
  git add file.txt
  git commit -qm "initial"
}

teardown() {
  rm -rf "$TEST_DIR" "$XDG_DIR"
}

# ---------------------------------------------------------------------------
# Pushing public (non-shadow) branches — should always pass
# ---------------------------------------------------------------------------

@test "check-shadow-push exits 0 for a regular branch" {
  SHA="$(git rev-parse HEAD)"
  run sh -c "printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' '$SHA' | git shadow check-shadow-push origin https://example.com 2>&1"
  [ "$status" -eq 0 ]
}

@test "check-shadow-push exits 0 for a feature branch without suffix" {
  SHA="$(git rev-parse HEAD)"
  run sh -c "printf 'refs/heads/feature/login %s refs/heads/feature/login 0000000000000000000000000000000000000000\n' '$SHA' | git shadow check-shadow-push origin https://example.com 2>&1"
  [ "$status" -eq 0 ]
}

@test "check-shadow-push exits 0 when stdin is empty (no refs)" {
  run sh -c "printf '' | git shadow check-shadow-push origin https://example.com 2>&1"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Pushing shadow branches — should block
# ---------------------------------------------------------------------------

@test "check-shadow-push exits 1 for a shadow branch" {
  SHA="$(git rev-parse HEAD)"
  run sh -c "printf 'refs/heads/main@local %s refs/heads/main@local 0000000000000000000000000000000000000000\n' '$SHA' | git shadow check-shadow-push origin https://example.com 2>&1"
  [ "$status" -eq 1 ]
}

@test "check-shadow-push output mentions the shadow branch name" {
  SHA="$(git rev-parse HEAD)"
  run sh -c "printf 'refs/heads/feature/login@local %s refs/heads/feature/login@local 0000000000000000000000000000000000000000\n' '$SHA' | git shadow check-shadow-push origin https://example.com 2>&1"
  [[ "$output" == *"feature/login@local"* ]]
}

@test "check-shadow-push output mentions --no-verify as bypass" {
  SHA="$(git rev-parse HEAD)"
  run sh -c "printf 'refs/heads/main@local %s refs/heads/main@local 0000000000000000000000000000000000000000\n' '$SHA' | git shadow check-shadow-push origin https://example.com 2>&1"
  [[ "$output" == *"--no-verify"* ]]
}

@test "check-shadow-push blocks when shadow branch is mixed with a public branch" {
  SHA="$(git rev-parse HEAD)"
  run sh -c "{ printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' '$SHA'; printf 'refs/heads/feature@local %s refs/heads/feature@local 0000000000000000000000000000000000000000\n' '$SHA'; } | git shadow check-shadow-push origin https://example.com 2>&1"
  [ "$status" -eq 1 ]
}

@test "check-shadow-push passes when only public branches are pushed alongside" {
  SHA="$(git rev-parse HEAD)"
  run sh -c "printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' '$SHA' | git shadow check-shadow-push origin https://example.com 2>&1"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Bypass via ALLOW_LOCAL_PUSH project config
# ---------------------------------------------------------------------------

@test "check-shadow-push exits 0 when ALLOW_LOCAL_PUSH=true in project config" {
  echo 'ALLOW_LOCAL_PUSH="true"' > "$TEST_DIR/.git-shadow.env"
  SHA="$(git rev-parse HEAD)"
  run sh -c "printf 'refs/heads/main@local %s refs/heads/main@local 0000000000000000000000000000000000000000\n' '$SHA' | git shadow check-shadow-push origin https://example.com 2>&1"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Delete pushes (local-ref = "(delete)") — should be ignored
# ---------------------------------------------------------------------------

@test "check-shadow-push exits 0 for a delete push of a shadow branch" {
  run sh -c "printf '(delete) 0000000000000000000000000000000000000000 refs/heads/main@local 0000000000000000000000000000000000000000\n' | git shadow check-shadow-push origin https://example.com 2>&1"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Respects configured LOCAL_SUFFIX
# ---------------------------------------------------------------------------

@test "check-shadow-push respects custom LOCAL_SUFFIX from project config" {
  echo 'LOCAL_SUFFIX="@private"' > "$TEST_DIR/.git-shadow.env"
  SHA="$(git rev-parse HEAD)"
  # "@private" suffix should be blocked
  run sh -c "printf 'refs/heads/feature@private %s refs/heads/feature@private 0000000000000000000000000000000000000000\n' '$SHA' | git shadow check-shadow-push origin https://example.com 2>&1"
  [ "$status" -eq 1 ]
}

@test "check-shadow-push with custom suffix: default @local suffix is no longer blocked" {
  echo 'LOCAL_SUFFIX="@private"' > "$TEST_DIR/.git-shadow.env"
  SHA="$(git rev-parse HEAD)"
  run sh -c "printf 'refs/heads/feature@local %s refs/heads/feature@local 0000000000000000000000000000000000000000\n' '$SHA' | git shadow check-shadow-push origin https://example.com 2>&1"
  [ "$status" -eq 0 ]
}
