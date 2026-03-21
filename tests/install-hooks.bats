#!/usr/bin/env bats

setup() {
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ---------------------------------------------------------------------------
# pre-commit hook
# ---------------------------------------------------------------------------

@test "install-hooks exits 0" {
  run git shadow install-hooks
  [ "$status" -eq 0 ]
}

@test "install-hooks creates .git/hooks/pre-commit file" {
  git shadow install-hooks
  [ -f ".git/hooks/pre-commit" ]
}

@test "install-hooks makes the pre-commit hook executable" {
  git shadow install-hooks
  [ -x ".git/hooks/pre-commit" ]
}

@test "install-hooks pre-commit is idempotent (exits 0 when already installed)" {
  git shadow install-hooks
  run git shadow install-hooks
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

# ---------------------------------------------------------------------------
# pre-push hook
# ---------------------------------------------------------------------------

@test "install-hooks creates .git/hooks/pre-push file" {
  git shadow install-hooks
  [ -f ".git/hooks/pre-push" ]
}

@test "install-hooks makes the pre-push hook executable" {
  git shadow install-hooks
  [ -x ".git/hooks/pre-push" ]
}

@test "install-hooks pre-push is idempotent (exits 0 when already installed)" {
  git shadow install-hooks
  run git shadow install-hooks
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
}

@test "install-hooks pre-push hook contains shadow push check" {
  git shadow install-hooks
  grep -q "check-shadow-push" ".git/hooks/pre-push"
}

@test "install-hooks pre-commit hook is syntactically valid sh" {
  git shadow install-hooks
  sh -n ".git/hooks/pre-commit"
}

@test "install-hooks pre-push hook is syntactically valid sh" {
  git shadow install-hooks
  sh -n ".git/hooks/pre-push"
}

@test "install-hooks appended pre-commit hook is syntactically valid sh" {
  printf '#!/usr/bin/env sh\necho "existing hook"\n' > ".git/hooks/pre-commit"
  chmod +x ".git/hooks/pre-commit"
  git shadow install-hooks
  sh -n ".git/hooks/pre-commit"
}
