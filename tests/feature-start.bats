#!/usr/bin/env bats

setup() {
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
  git symbolic-ref HEAD refs/heads/develop
  echo "initial" > file.txt
  git add file.txt
  git commit -qm "initial"
  git checkout -q -b "develop@local"
  git checkout -q develop
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "feature start without arg on shadow branch exits 1" {
  git checkout -q "develop@local"
  run git shadow feature start
  [ "$status" -eq 1 ]
  [[ "$output" == *"shadow branch"* ]]
}

@test "feature start without arg on public branch with existing shadow exits 0 with warning" {
  run git shadow feature start
  [ "$status" -eq 0 ]
  [[ "$output" == *"develop@local"* ]]
}

@test "feature start without arg on public branch without shadow creates shadow branch" {
  git branch -d "develop@local"
  run git shadow feature start
  [ "$status" -eq 0 ]
  git show-ref --verify --quiet "refs/heads/develop@local"
  current="$(git branch --show-current)"
  [ "$current" = "develop@local" ]
}

@test "feature start creates the public feature branch" {
  run git shadow feature start test-feature
  [ "$status" -eq 0 ]
  git show-ref --verify --quiet "refs/heads/test-feature"
}

@test "feature start creates the local shadow branch" {
  run git shadow feature start test-feature
  [ "$status" -eq 0 ]
  git show-ref --verify --quiet "refs/heads/test-feature@local"
}

@test "feature start switches to the local shadow branch" {
  run git shadow feature start test-feature
  [ "$status" -eq 0 ]
  current="$(git branch --show-current)"
  [ "$current" = "test-feature@local" ]
}

@test "feature start exits 1 when branch name already exists" {
  git shadow feature start test-feature
  run git shadow feature start test-feature
  [ "$status" -eq 1 ]
}

@test "feature start uses public base when local base branch does not exist" {
  git branch -d "develop@local"
  run git shadow feature start test-feature
  [ "$status" -eq 0 ]
  git show-ref --verify --quiet "refs/heads/test-feature"
  git show-ref --verify --quiet "refs/heads/test-feature@local"
}

@test "feature start exits 1 for invalid branch name" {
  run git shadow feature start "invalid..name"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid branch name"* ]]
}

@test "feature start exits 1 for branch name with spaces" {
  run git shadow feature start "name with spaces"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid branch name"* ]]
}
