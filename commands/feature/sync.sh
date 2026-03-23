#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: feature/sync.sh
# Purpose: rebase the current shadow branch onto its public counterpart.
#   - Regular code commits: auto-resolved with --ours (public branch wins)
#   - [MEMORY] commits: paused for manual resolution
#
# Usage:
#   git shadow feature sync             # start sync
#   git shadow feature sync --continue  # resume after manual [MEMORY] conflict
#   git shadow feature sync --abort     # abort the rebase
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)/common.sh"

CONTINUE=0
ABORT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --continue) CONTINUE=1; shift ;;
    --abort)    ABORT=1;    shift ;;
    *)
      ui_error "Unknown argument: $1"
      echo "Usage: git shadow feature sync [--continue | --abort]" >&2
      exit 1
      ;;
  esac
done

enter_project "."

# ---------------------------------------------------------------------------
# --abort
# ---------------------------------------------------------------------------
if [[ "$ABORT" -eq 1 ]]; then
  git rebase --abort
  ui_ok "Rebase aborted."
  exit 0
fi

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

# ---------------------------------------------------------------------------
# --continue: resume after a manual [MEMORY] conflict resolution
# ---------------------------------------------------------------------------
if [[ "$CONTINUE" -eq 1 ]]; then
  REBASE_DIR="$(git rev-parse --git-dir)/rebase-merge"
  if [[ ! -d "$REBASE_DIR" ]]; then
    ui_error "No rebase in progress. Nothing to continue."
    exit 1
  fi
  ui_info "Resuming sync after manual resolution..."
  git rebase --continue --no-edit
  # Fall through to the main loop below if more conflicts remain
fi

# ---------------------------------------------------------------------------
# Start rebase (only if not already in progress)
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
    git rebase --continue --no-edit 2>&1 || true
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
      result="$(git rebase --continue --no-edit 2>&1 || true)"
    fi
    echo "$result"
  fi
done

ui_ok "Shadow branch '$CURRENT_BRANCH' is now in sync with '$PUBLIC_BRANCH'."
