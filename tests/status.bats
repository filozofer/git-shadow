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
  # Create a shadow/public feature branch pair with one publishable commit
  git shadow feature start test-feature
  printf '/// local comment\nreal code\n' > feature.txt
  git add feature.txt
  git shadow commit -m "feat: real code"
  # Now on test-feature@local with 2 commits: feat + [MEMORY]
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --- Branch detection ---

@test "status exits 1 on a non-shadow-managed branch" {
  git checkout -q -b "unrelated-branch"
  run git shadow status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not a Git Shadow branch"* ]]
}

@test "status exits 1 in detached HEAD state" {
  sha="$(git rev-parse HEAD)"
  git checkout -q "$sha"
  run git shadow status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Detached HEAD"* ]]
}

@test "status exits 0 from shadow branch" {
  run git shadow status
  [ "$status" -eq 0 ]
}

@test "status exits 0 from public branch" {
  git checkout -q test-feature
  run git shadow status
  [ "$status" -eq 0 ]
}

# --- Branch type detection ---

@test "status reports branch type shadow when on @local branch" {
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch type    : shadow"* ]]
}

@test "status reports branch type public when on public branch" {
  git checkout -q test-feature
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch type    : public"* ]]
}

@test "status shows public branch name when on shadow branch" {
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Public branch  : test-feature"* ]]
}

@test "status shows shadow branch name when on public branch" {
  git checkout -q test-feature
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Shadow branch  : test-feature@local"* ]]
}

# --- Commit counting ---

@test "status reports 1 publishable commit pending before publish" {
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Publishable commits pending : 1"* ]]
}

@test "status reports 1 MEMORY commit" {
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Shadow-only [MEMORY] commits: 1"* ]]
}

@test "status reports 0 publishable commits after publish" {
  git shadow feature publish
  git checkout -q "test-feature@local"
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Publishable commits pending : 0"* ]]
}

@test "status reports public branch not ahead when in sync" {
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Public branch ahead         : no"* ]]
}

@test "status reports public branch ahead when public has new commits" {
  git shadow feature publish
  git checkout -q test-feature
  echo "extra" > extra.txt
  git add extra.txt
  git commit -qm "fix: extra on public"
  git checkout -q "test-feature@local"
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Public branch ahead         : yes"* ]]
}

# --- Status labels ---

@test "status label is 'ready to publish' when shadow has publishable commits" {
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status    : ready to publish"* ]]
}

@test "status label is 'up to date' after publish with no new commits" {
  git shadow feature publish
  git checkout -q "test-feature@local"
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status    : up to date"* ]]
}

@test "status label is 'public branch ahead' when public has unpulled commits" {
  git shadow feature publish
  git checkout -q test-feature
  echo "extra" > extra.txt
  git add extra.txt
  git commit -qm "fix: extra on public"
  git checkout -q "test-feature@local"
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status    : public branch ahead"* ]]
}

@test "status label is 'diverged' when both branches have unpublished commits" {
  git checkout -q test-feature
  echo "extra" > extra.txt
  git add extra.txt
  git commit -qm "fix: extra on public"
  git checkout -q "test-feature@local"
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status    : diverged"* ]]
}

# --- Missing counterpart ---

@test "status reports shadow branch missing when public branch has no shadow counterpart" {
  # Create an orphan public branch with no @local counterpart
  git checkout -q -b "orphan-feature"
  run git shadow status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Not a Git Shadow branch"* ]]
}

@test "status reports public branch missing when shadow exists but public does not" {
  git branch -D test-feature
  run git shadow status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Status    : public branch missing"* ]]
}

# --- JSON output ---

@test "status --json exits 0 from shadow branch" {
  run git shadow status --json
  [ "$status" -eq 0 ]
}

@test "status --json outputs valid JSON structure" {
  run git shadow status --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"current_branch"'* ]]
  [[ "$output" == *'"branch_type"'* ]]
  [[ "$output" == *'"publishable_count"'* ]]
  [[ "$output" == *'"status"'* ]]
}

@test "status --json reports branch type shadow" {
  run git shadow status --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"branch_type": "shadow"'* ]]
}

@test "status --json reports correct shadow and public branch names" {
  run git shadow status --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"shadow_branch": "test-feature@local"'* ]]
  [[ "$output" == *'"public_branch": "test-feature"'* ]]
}

@test "status --json reports 1 publishable commit pending" {
  run git shadow status --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"publishable_count": 1'* ]]
}

@test "status --json reports 0 publishable commits after publish" {
  git shadow feature publish
  git checkout -q "test-feature@local"
  run git shadow status --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"publishable_count": 0'* ]]
}

@test "status --json reports status up to date after publish" {
  git shadow feature publish
  git checkout -q "test-feature@local"
  run git shadow status --json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"status": "up to date"'* ]]
}

@test "status --json exits 1 on non-shadow branch" {
  git checkout -q -b "unrelated-json"
  run git shadow status --json
  [ "$status" -eq 1 ]
  [[ "$output" == *'"error"'* ]]
}

@test "status exits 1 on unknown argument" {
  run git shadow status --unknown
  [ "$status" -eq 1 ]
}
