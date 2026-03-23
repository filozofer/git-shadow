#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: feature/start.sh
# Purpose: create a feature branch and corresponding @local shadow branch.
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)/common.sh"

# ---------------------------------------------------------------------------
# No argument: smart detection based on current branch
# ---------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
  enter_project '.'
  ensure_clean_repo

  CURRENT_BRANCH="$(current_branch)"
  if [[ -z "$CURRENT_BRANCH" ]]; then
    ui_error "Unable to determine current branch."
    exit 1
  fi

  # Case 1: already on a shadow branch
  if [[ "$CURRENT_BRANCH" =~ ${LOCAL_SUFFIX}$ ]]; then
    ui_error "You are already on a shadow branch ('$CURRENT_BRANCH')."
    ui_info  "Provide a branch name to create a new feature."
    exit 1
  fi

  # Case 2: on a public branch — check if shadow branch already exists
  SHADOW_BRANCH="${CURRENT_BRANCH}${LOCAL_SUFFIX}"
  if git show-ref --verify --quiet "refs/heads/$SHADOW_BRANCH"; then
    ui_warn "A shadow branch already exists for '$CURRENT_BRANCH': '$SHADOW_BRANCH'."
    ui_info "To switch to it: git checkout '$SHADOW_BRANCH'"
    ui_info "To create a new feature branch: git shadow feature start <branch-name>"
    exit 0
  fi

  # Case 3: on a public branch with no shadow — create the shadow branch
  ui_shadow "No shadow branch found for '$CURRENT_BRANCH'. Creating '$SHADOW_BRANCH'..."
  git checkout -b "$SHADOW_BRANCH"
  ui_shadow "Switched to new shadow branch '$SHADOW_BRANCH'."
  exit 0
fi

# ---------------------------------------------------------------------------
# Argument provided: standard feature creation
# ---------------------------------------------------------------------------
PROJECT_ARG='.'
FEATURE_NAME="$1"
LOCAL_BRANCH="${FEATURE_NAME}${LOCAL_SUFFIX}"

# Validate branch name before doing any git operations
if ! git check-ref-format --branch "$FEATURE_NAME" >/dev/null 2>&1; then
  ui_error "Invalid branch name: '$FEATURE_NAME'"
  exit 1
fi

# Enter project and ensure repo is in clean state
enter_project "$PROJECT_ARG"
ensure_clean_repo

# Determine current branch and expansions for public/local base
CURRENT_BRANCH="$(current_branch)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  ui_error "Unable to determine current branch."
  exit 1
fi
PUBLIC_BASE="$(public_branch_from_any "$CURRENT_BRANCH")"
LOCAL_BASE="$(local_branch_from_any "$CURRENT_BRANCH")"

# Ensure the public base branch exists before creating feature branches
if ! git show-ref --verify --quiet "refs/heads/$PUBLIC_BASE"; then
  ui_error "Public base branch does not exist: $PUBLIC_BASE"
  exit 1
fi

# If the local base branch does not exist, fall back to the public base
if ! git show-ref --verify --quiet "refs/heads/$LOCAL_BASE"; then
  ui_info "Local base branch '$LOCAL_BASE' not found, using '$PUBLIC_BASE' as local base."
  LOCAL_BASE="$PUBLIC_BASE"
fi

ui_git    "Public base: $PUBLIC_BASE"
ui_shadow "Local base:  $LOCAL_BASE"

if git show-ref --verify --quiet "refs/heads/$FEATURE_NAME"; then
  ui_error "Branch already exists: $FEATURE_NAME"
  exit 1
fi
if git show-ref --verify --quiet "refs/heads/$LOCAL_BRANCH"; then
  ui_error "Branch already exists: $LOCAL_BRANCH"
  exit 1
fi

# Create public feature branch from public base, then create local shadow branch from local base
ui_git "Creating public branch '$FEATURE_NAME' from '$PUBLIC_BASE'"
git checkout "$PUBLIC_BASE"
git checkout -b "$FEATURE_NAME"

ui_shadow "Creating local branch '$LOCAL_BRANCH' from '$LOCAL_BASE'"
git checkout "$LOCAL_BASE"
git checkout -b "$LOCAL_BRANCH"

ui_shadow "Switching to local working branch '$LOCAL_BRANCH'"
git checkout "$LOCAL_BRANCH"
