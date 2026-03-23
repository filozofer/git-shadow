# Changelog

## [1.1.0] — 2026-03-23

### Added

- **`git shadow feature sync`** — rebase the shadow branch onto its public counterpart.
  Auto-resolves code conflicts in favour of the public branch; pauses for manual resolution on `[MEMORY]` commits so local AI context is never silently overwritten.
  Supports `--continue` and `--abort` to drive the underlying rebase.

- **`git shadow feature start` (no argument)** — smart context detection when invoked without a branch name.
  - On a public branch with no existing shadow: creates the shadow branch and switches to it.
  - On a public branch with an existing shadow: warns and prints the checkout command.
  - On a shadow branch: exits with an error.

- **`git shadow commit` auto-`[MEMORY]`** — when all staged content consists of local comment markers, automatically creates a `[MEMORY]` commit with the original files instead of silently doing nothing.

- **`git shadow feature publish --push`** — optional flag to push the public branch to `origin` immediately after publishing.

- **`git shadow feature publish` always returns to shadow branch** — after publish completes (with or without `--push`), the command always switches back to the originating `@local` branch.

### Fixed

- `strip-local-comments.sh` — new files whose entire content is local comment markers were left as empty blobs in the index, blocking the auto-`[MEMORY]` path. Empty new files are now removed from the index with `git rm --cached`.
- `commit.sh` — `git add .` was replaced with a targeted add of the originally staged files to avoid staging unrelated working-tree changes.
- `feature/sync.sh` — `[MEMORY]` prefix detection used `grep -qE "^[MEMORY]"` which treated the brackets as a regex character class. Replaced with a bash `==` glob match.
- `feature/sync.sh` — empty commits (code conflicts resolved to the public branch version) caused an infinite loop. Detected via `git diff --cached --quiet` and skipped with `git rebase --skip`.
- `feature/sync.sh` — `git rebase --continue --no-edit` is not accepted by the apply rebase backend. Replaced with `GIT_EDITOR=true git rebase --continue`.
- `feature/sync.sh` — `--continue` failed with "unable to determine current branch" because git operates in detached HEAD during a rebase. Branch name is now read from `.git/rebase-merge/head-name`.

## [1.0.4] — 2026-03-09

- feat(promote): add `git shadow promote` command + publish-time detection
- feat(ui): add semantic colour design system

## [1.0.3] and earlier

See git log.
