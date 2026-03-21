#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: feature/start.sh
# Purpose: create a feature branch and corresponding @local shadow branch.
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)/common.sh"

# Validate required parameters
if [[ $# -ne 1 ]]; then
  echo "Usage: git shadow feature start <branch-name>" >&2
  exit 1
fi
PROJECT_ARG='.'
FEATURE_NAME="$1"
LOCAL_BRANCH="${FEATURE_NAME}${LOCAL_SUFFIX}"

# Validate branch name before doing any git operations
if ! git check-ref-format --branch "$FEATURE_NAME" >/dev/null 2>&1; then
  echo "❌ Invalid branch name: '$FEATURE_NAME'" >&2
  exit 1
fi

# Enter project and ensure repo is in clean state
enter_project "$PROJECT_ARG"
ensure_clean_repo

# Determine current branch and expansions for public/local base
CURRENT_BRANCH="$(current_branch)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "❌ Unable to determine current branch." >&2
  exit 1
fi
PUBLIC_BASE="$(public_branch_from_any "$CURRENT_BRANCH")"
LOCAL_BASE="$(local_branch_from_any "$CURRENT_BRANCH")"

# Ensure the public base branch exists before creating feature branches
if ! git show-ref --verify --quiet "refs/heads/$PUBLIC_BASE"; then
  echo "❌ Public base branch does not exist: $PUBLIC_BASE" >&2
  exit 1
fi

# If the local base branch does not exist, fall back to the public base
if ! git show-ref --verify --quiet "refs/heads/$LOCAL_BASE"; then
  echo "ℹ️ Local base branch '$LOCAL_BASE' not found, using '$PUBLIC_BASE' as local base."
  LOCAL_BASE="$PUBLIC_BASE"
fi

echo "Public base: $PUBLIC_BASE"
echo "Local base : $LOCAL_BASE"
if git show-ref --verify --quiet "refs/heads/$FEATURE_NAME"; then
  echo "❌ Branch already exists: $FEATURE_NAME" >&2
  exit 1
fi
if git show-ref --verify --quiet "refs/heads/$LOCAL_BRANCH"; then
  echo "❌ Branch already exists: $LOCAL_BRANCH" >&2
  exit 1
fi

# Create public feature branch from public base, then create local shadow branch from local base
echo "🌿 Creating public branch '$FEATURE_NAME' from '$PUBLIC_BASE'"
git checkout "$PUBLIC_BASE"
git checkout -b "$FEATURE_NAME"

echo "🌿 Creating local branch '$LOCAL_BRANCH' from '$LOCAL_BASE'"
git checkout "$LOCAL_BASE"
git checkout -b "$LOCAL_BRANCH"

echo "🧠 Switching to local working branch '$LOCAL_BRANCH'"
git checkout "$LOCAL_BRANCH"
