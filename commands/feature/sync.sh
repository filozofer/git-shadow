#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: feature/sync.sh
# Purpose: sync the current shadow branch with its public counterpart.
#
#   Default (rebase mode):
#     Replays shadow commits on top of the public branch.
#     - Regular code conflicts: auto-resolved in favour of public branch
#     - [MEMORY] commit conflicts: paused for manual resolution
#
#   --merge mode:
#     Merges the public branch into the shadow branch (preserves history).
#     Intended for shared shadow branches pushed to a remote.
#     All conflicts are auto-resolved in favour of the public branch
#     via `git merge -X theirs`.
#
# Usage:
#   git shadow feature sync [--merge]
#   git shadow feature sync --continue
#   git shadow feature sync --abort
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)/common.sh"

CONTINUE=0
ABORT=0
MERGE_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --continue) CONTINUE=1; shift ;;
    --abort)    ABORT=1;    shift ;;
    --merge)    MERGE_MODE=1; shift ;;
    *)
      ui_error "Unknown argument: $1"
      echo "Usage: git shadow feature sync [--merge] [--continue | --abort]" >&2
      exit 1
      ;;
  esac
done

enter_project "."

# ---------------------------------------------------------------------------
# --abort: works for both rebase and merge in-progress
# ---------------------------------------------------------------------------
if [[ "$ABORT" -eq 1 ]]; then
  GIT_DIR="$(git rev-parse --git-dir)"
  if [[ -d "$GIT_DIR/rebase-merge" ]]; then
    git rebase --abort
    ui_ok "Rebase aborted."
  elif [[ -f "$GIT_DIR/MERGE_HEAD" ]]; then
    git merge --abort
    ui_ok "Merge aborted."
  else
    ui_error "No rebase or merge in progress. Nothing to abort."
    exit 1
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# --continue: resume after a manual conflict resolution
# ---------------------------------------------------------------------------
if [[ "$CONTINUE" -eq 1 ]]; then
  GIT_DIR="$(git rev-parse --git-dir)"

  if [[ -f "$GIT_DIR/MERGE_HEAD" ]]; then
    # Merge in progress
    ui_info "Resuming merge after manual resolution..."
    GIT_EDITOR=true git merge --continue
    ui_ok "Merge sync completed."
    exit 0
  fi

  if [[ -d "$GIT_DIR/rebase-merge" ]]; then
    # During rebase, HEAD is detached — read the branch name from rebase state
    CURRENT_BRANCH="$(sed 's|refs/heads/||' "$GIT_DIR/rebase-merge/head-name")"
    PUBLIC_BRANCH="$(public_branch_from_any "$CURRENT_BRANCH")"
    ui_info "Resuming rebase after manual resolution..."
    GIT_EDITOR=true git rebase --continue || true
    # Fall through to the resolution loop below if more conflicts remain
  else
    ui_error "No rebase or merge in progress. Nothing to continue."
    exit 1
  fi
else
  # ---------------------------------------------------------------------------
  # Validate we are on a shadow branch
  # ---------------------------------------------------------------------------
  CURRENT_BRANCH="$(current_branch)"
  if [[ -z "$CURRENT_BRANCH" ]]; then
    ui_error "Unable to determine current branch."
    exit 1
  fi
  if [[ ! "$CURRENT_BRANCH" =~ ${LOCAL_SUFFIX}$ ]]; then
    ui_error "git shadow feature sync must be run from a shadow branch (ending with '$LOCAL_SUFFIX')."
    ui_step "Current branch: $CURRENT_BRANCH"
    exit 1
  fi
  PUBLIC_BRANCH="$(public_branch_from_any "$CURRENT_BRANCH")"
fi

# At this point PUBLIC_BRANCH is set (either from continue state or fresh start)
: "${PUBLIC_BRANCH:?}"

# ---------------------------------------------------------------------------
# --merge mode: merge public branch into shadow, with per-file conflict handling
#   - Conflicted files with NO local comments  → public branch wins (--theirs)
#   - Conflicted files WITH local comments     → pause for manual resolution
# ---------------------------------------------------------------------------
if [[ "$MERGE_MODE" -eq 1 ]]; then
  # Only start a fresh merge if not already mid-merge (--continue falls through here)
  if [[ ! -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]]; then
    if ! git show-ref --verify --quiet "refs/heads/$PUBLIC_BRANCH"; then
      ui_error "Public branch does not exist: $PUBLIC_BRANCH"
      exit 1
    fi
    ensure_clean_repo
    ui_shadow "Merging '$PUBLIC_BRANCH' into '$CURRENT_BRANCH' (--merge mode)..."
    git merge "$PUBLIC_BRANCH" || true  # continue even if conflicts
  fi

  CONFLICTS="$(git diff --name-only --diff-filter=U)"

  if [[ -z "$CONFLICTS" ]]; then
    # Clean merge or already resolved — commit if still needed
    if [[ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]]; then
      GIT_EDITOR=true git merge --continue
    fi
    ui_ok "Shadow branch '$CURRENT_BRANCH' is now in sync with '$PUBLIC_BRANCH'."
    exit 0
  fi

  # Per-file conflict resolution
  HAS_MANUAL=0
  while IFS= read -r file; do
    # Check if our (shadow) version of the file contains local comment markers
    if git show ":2:$file" 2>/dev/null | grep -qP "$LOCAL_COMMENT_PATTERN"; then
      ui_warn "Conflict with local comments: $file"
      HAS_MANUAL=1
    else
      git checkout --theirs -- "$file"
      git add -- "$file"
      ui_shadow "Auto-resolved (no local comments): $file"
    fi
  done <<< "$CONFLICTS"

  if [[ "$HAS_MANUAL" -eq 1 ]]; then
    ui_warn "Some conflicted files contain local comments — manual resolution required."
    ui_info "Resolve each file above, stage it with 'git add', then run:"
    ui_step "git shadow feature sync --continue"
    ui_info "To abort:"
    ui_step "git shadow feature sync --abort"
    exit 0
  fi

  # All conflicts resolved automatically
  GIT_EDITOR=true git merge --continue
  ui_ok "Shadow branch '$CURRENT_BRANCH' is now in sync with '$PUBLIC_BRANCH'."
  exit 0
fi

# ---------------------------------------------------------------------------
# Rebase mode: start rebase (only if not already in progress)
# ---------------------------------------------------------------------------
REBASE_DIR="$(git rev-parse --git-dir)/rebase-merge"
if [[ ! -d "$REBASE_DIR" ]]; then
  if ! git show-ref --verify --quiet "refs/heads/$PUBLIC_BRANCH"; then
    ui_error "Public branch does not exist: $PUBLIC_BRANCH"
    exit 1
  fi
  ensure_clean_repo
  ui_shadow "Syncing '$CURRENT_BRANCH' onto '$PUBLIC_BRANCH'..."
  git rebase "$PUBLIC_BRANCH" || true
fi

# ---------------------------------------------------------------------------
# Resolution loop
# ---------------------------------------------------------------------------
while [[ -d "$(git rev-parse --git-dir)/rebase-merge" ]]; do
  CONFLICTS="$(git diff --name-only --diff-filter=U)"

  # No conflicts — just continue
  if [[ -z "$CONFLICTS" ]]; then
    GIT_EDITOR=true git rebase --continue 2>&1 || true
    continue
  fi

  # Determine commit type
  COMMIT_MSG="$(cat "$(git rev-parse --git-dir)/rebase-merge/message" 2>/dev/null || true)"

  if [[ "$COMMIT_MSG" == "${SHADOW_COMMIT_PREFIX}"* ]]; then
    # [MEMORY] commit — pause for manual resolution
    ui_warn "Conflict on shadow commit: $COMMIT_MSG"
    ui_info "Conflicted files:"
    echo "$CONFLICTS" | while IFS= read -r f; do ui_step "  $f"; done
    ui_info "Resolve conflicts manually, then run:"
    ui_step "git shadow feature sync --continue"
    ui_info "To abort:"
    ui_step "git shadow feature sync --abort"
    exit 0
  else
    # Regular code commit — auto-resolve with --ours (public branch wins)
    ui_shadow "Auto-resolving (code commit): $COMMIT_MSG"
    echo "$CONFLICTS" | xargs git checkout --ours --
    echo "$CONFLICTS" | xargs git add
    # If the commit becomes empty (changes already in public branch), skip it
    if git diff --cached --quiet; then
      result="$(git rebase --skip 2>&1 || true)"
    else
      result="$(GIT_EDITOR=true git rebase --continue 2>&1 || true)"
    fi
    echo "$result"
  fi
done

ui_ok "Shadow branch '$CURRENT_BRANCH' is now in sync with '$PUBLIC_BRANCH'."
