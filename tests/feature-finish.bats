#!/usr/bin/env bats

setup() {
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"
  git symbolic-ref HEAD refs/heads/main
  echo "initial" > file.txt
  git add file.txt
  git commit -qm "initial"
  git checkout -q -b "main@local"
  git checkout -q main

  # Create feature, add code, publish
  git shadow feature start test-feature
  echo "feature code" > feature.txt
  git add feature.txt
  git shadow commit -m "feat: feature code"
  git shadow feature publish
  # Simulate the feature being merged into main
  git checkout -q main
  git merge -q --no-edit test-feature

  # Return to the local feature branch so feature finish can detect it
  git checkout -q "test-feature@local"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "feature finish exits 0 after feature is merged into develop" {
  run git shadow feature finish --no-pull
  [ "$status" -eq 0 ]
}

@test "feature finish outputs completion message" {
  run git shadow feature finish --no-pull
  [[ "$output" == *"Feature finished successfully"* ]]
}

@test "feature finish merges feature commits into main@local" {
  git shadow feature finish --no-pull
  git checkout -q "main@local"
  result="$(git log --oneline)"
  [[ "$result" == *"feat: feature code"* ]]
}

@test "feature finish deletes the public feature branch" {
  git shadow feature finish --no-pull
  run git branch --list "test-feature"
  [ -z "$output" ]
}

@test "feature finish deletes the local feature branch" {
  git shadow feature finish --no-pull
  run git branch --list "test-feature@local"
  [ -z "$output" ]
}

@test "feature finish exits 1 when run from the base branch" {
  git checkout -q main
  run git shadow feature finish --no-pull
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Conflict scenarios
# ---------------------------------------------------------------------------

@test "feature finish exits 1 when sync merge has conflicts" {
  # Scenario: public base and feature both modified the same file
  # → git merge of public_base into local_base will conflict

  # Setup: feature is published and merged
  git checkout -q main
  git merge -q --no-edit test-feature

  # Now commit a conflicting change on main AFTER the feature was merged
  git checkout -q main
  echo "conflicting main change" > feature.txt
  git add feature.txt
  git commit -qm "chore: post-merge change on main"

  # Also put the conflicting content on main@local
  git checkout -q "main@local"
  echo "conflicting local change" > feature.txt
  git add feature.txt
  git commit -qm "chore: conflicting local"

  # Return to feature branch and attempt finish
  git checkout -q "test-feature@local"
  run git shadow feature finish --no-pull
  [ "$status" -ne 0 ]
}

@test "feature finish exits 1 when feature merge has conflicts" {
  # Scenario: local base modified a file that the feature branch also modified
  # → git merge of feature_local_branch into local_base will conflict

  git checkout -q main
  git merge -q --no-edit test-feature

  # Modify the same file on main@local independently
  git checkout -q "main@local"
  echo "local base independent change" > feature.txt
  git add feature.txt
  git commit -qm "chore: independent change on main@local"

  # Return to feature and attempt finish
  git checkout -q "test-feature@local"
  run git shadow feature finish --no-pull
  [ "$status" -ne 0 ]
}

@test "feature finish: repo is in conflict state after merge failure" {
  # After a failed merge, MERGE_HEAD should exist — user can resolve manually
  git checkout -q main
  git merge -q --no-edit test-feature

  # Create conflict between main@local and feature
  git checkout -q "main@local"
  echo "local change" > feature.txt
  git add feature.txt
  git commit -qm "chore: conflict setup"

  git checkout -q "test-feature@local"
  git shadow feature finish --no-pull 2>/dev/null || true

  # After failure, we should be in a merge conflict state on main@local
  git checkout -q "main@local" 2>/dev/null || true
  merge_head_file="$(git rev-parse --git-path MERGE_HEAD 2>/dev/null || echo '')"
  [ -f "$merge_head_file" ]
}

@test "feature finish --keep-branches: branches are not deleted on conflict" {
  git checkout -q main
  git merge -q --no-edit test-feature

  git checkout -q "main@local"
  echo "local change" > feature.txt
  git add feature.txt
  git commit -qm "chore: conflict setup"

  git checkout -q "test-feature@local"
  git shadow feature finish --no-pull --keep-branches 2>/dev/null || true

  # Branches still exist
  git show-ref --verify --quiet "refs/heads/test-feature"
  git show-ref --verify --quiet "refs/heads/test-feature@local"
}
