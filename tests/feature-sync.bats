#!/usr/bin/env bats

setup() {
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"

  # Initial commit on develop
  git symbolic-ref HEAD refs/heads/develop
  echo "v1" > app.ts
  git add app.ts
  git commit -qm "initial"

  # Create feature branches
  git checkout -q -b "feature/foo"
  git checkout -q -b "feature/foo@local"

  # Add a [MEMORY] commit on the shadow branch
  echo "/// local note" > notes.md
  git add notes.md
  git commit -qm "[MEMORY] local notes"

  # Go back to public feature branch and add a commit (simulates colleague work)
  git checkout -q feature/foo
  echo "v2" > app.ts
  git add app.ts
  git commit -qm "feat: update app"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

@test "feature sync exits 1 when not on a shadow branch" {
  git checkout -q feature/foo
  run git shadow feature sync
  [ "$status" -eq 1 ]
  [[ "$output" == *"shadow branch"* ]]
}

@test "feature sync exits 1 when public branch does not exist" {
  git checkout -q -b "feature/orphan@local"
  run git shadow feature sync
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "feature sync --abort exits 1 when no rebase in progress" {
  git checkout -q "feature/foo@local"
  run git shadow feature sync --abort
  # git rebase --abort itself exits non-zero when nothing to abort
  [ "$status" -ne 0 ]
}

@test "feature sync --continue exits 1 when no rebase in progress" {
  git checkout -q "feature/foo@local"
  run git shadow feature sync --continue
  [ "$status" -eq 1 ]
  [[ "$output" == *"No rebase in progress"* ]]
}

# ---------------------------------------------------------------------------
# Happy path — no conflicts
# ---------------------------------------------------------------------------

@test "feature sync succeeds when shadow branch has no conflicts" {
  git checkout -q "feature/foo@local"
  run git shadow feature sync
  [ "$status" -eq 0 ]
  [[ "$output" == *"in sync"* ]]
}

@test "feature sync rebases shadow branch onto public branch" {
  git checkout -q "feature/foo@local"
  git shadow feature sync
  # The [MEMORY] commit should now be on top of the public branch tip
  parent="$(git log -1 --pretty=%P HEAD)"
  public_tip="$(git rev-parse feature/foo)"
  [ "$parent" = "$public_tip" ]
}

@test "feature sync preserves [MEMORY] commit content" {
  git checkout -q "feature/foo@local"
  git shadow feature sync
  result="$(git show HEAD:notes.md)"
  [[ "$result" == *"/// local note"* ]]
}

# ---------------------------------------------------------------------------
# Auto-resolution of code conflicts
# ---------------------------------------------------------------------------

@test "feature sync auto-resolves code commit conflicts with public branch version" {
  # Add conflicting code change on shadow branch
  git checkout -q "feature/foo@local"
  echo "shadow version" > app.ts
  git add app.ts
  git commit -qm "chore: shadow tweak"

  # Add conflicting change on public branch
  git checkout -q feature/foo
  echo "public version" > app.ts
  git add app.ts
  git commit -qm "feat: public update"

  git checkout -q "feature/foo@local"
  run git shadow feature sync
  [ "$status" -eq 0 ]
  # Public branch version should win
  result="$(cat app.ts)"
  [ "$result" = "public version" ]
}

# ---------------------------------------------------------------------------
# [MEMORY] conflict — pause for manual resolution
# ---------------------------------------------------------------------------

@test "feature sync pauses on [MEMORY] commit conflict" {
  # Create a [MEMORY] commit that will conflict with public branch
  git checkout -q "feature/foo@local"
  echo "/// conflict note" > app.ts
  git add app.ts
  git commit -qm "[MEMORY] local override"

  # Add conflicting change on public branch
  git checkout -q feature/foo
  echo "public content" > app.ts
  git add app.ts
  git commit -qm "feat: public change"

  git checkout -q "feature/foo@local"
  run git shadow feature sync
  [ "$status" -eq 0 ]
  [[ "$output" == *"[MEMORY]"* ]]
  [[ "$output" == *"--continue"* ]]
  # Rebase should still be in progress
  [ -d "$(git rev-parse --git-dir)/rebase-merge" ]
}
