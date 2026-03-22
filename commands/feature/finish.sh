#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: feature/finish.sh
# Purpose: finalize a feature by validating public integration,
# updating local base branches, merging local feature work back
# into the local base, and optionally deleting feature branches.
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)/common.sh"

# Finish-feature operates on current repository only.
PROJECT_ARG='.'
DELETE_BRANCHES=1
PULL_BASES=1
FORCE_DELETE=0

# Parse optional flags for finish-feature behavior
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-branches)
      DELETE_BRANCHES=0
      shift
      ;;
    --no-pull)
      PULL_BASES=0
      shift
      ;;
    --force)
      FORCE_DELETE=1
      shift
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: git shadow feature finish [--keep-branches] [--no-pull] [--force]" >&2
      exit 1
      ;;
  esac
done

# Enter project and ensure repo is in clean state
enter_project "$PROJECT_ARG"
ensure_clean_repo
current_branch_name="$(current_branch)"
feature_public_branch="$(public_branch_from_any "$current_branch_name")"
feature_local_branch="$(local_branch_from_any "$current_branch_name")"
public_base="$PUBLIC_BASE_BRANCH"
local_base="${PUBLIC_BASE_BRANCH}${LOCAL_SUFFIX}"
if [[ "$feature_public_branch" == "$public_base" || "$feature_local_branch" == "$local_base" ]]; then
  echo "❌ This command must be run from a feature branch, not from $public_base or $local_base." >&2
  exit 1
fi

# Ensure all expected branches exist locally before proceeding
for branch in "$feature_public_branch" "$feature_local_branch" "$public_base" "$local_base"; do
  if ! git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "❌ Branch does not exist locally: $branch" >&2
    exit 1
  fi
done

# Display summary of detected branches and bases for user confirmation
echo "🏁 Finalizing feature branches"
echo "   Public branch : $feature_public_branch"
echo "   Local branch  : $feature_local_branch"
echo "   Public base   : $public_base"
echo "   Local base    : $local_base"
echo
echo "🔀 Checkout $public_base"
git checkout "$public_base"
if [[ "$PULL_BASES" -eq 1 ]]; then
  echo "⬇️  Pulling latest changes for $public_base"
  git pull
fi
public_branch_merged=0
if git merge-base --is-ancestor "$feature_public_branch" "$public_base"; then
  public_branch_merged=1
fi

# Warn if the public branch does not appear to be merged into the public base
if [[ "$public_branch_merged" -eq 1 ]]; then
  echo "✅ '$feature_public_branch' is already merged into '$public_base'."
else
  echo "⚠️  '$feature_public_branch' does NOT appear to be merged into '$public_base'."
  if [[ "$DELETE_BRANCHES" -eq 1 && "$FORCE_DELETE" -eq 0 ]]; then
    echo "❌ Branch deletion aborted to avoid losing work."
    echo "   Run with --force if you really want to continue."
    exit 1
  fi
fi

# Sync local base with public base to prepare for final merge
echo "🔀 Checkout $local_base"
git checkout "$local_base"
if [[ "$PULL_BASES" -eq 1 ]]; then
  echo "⬇️  Pulling latest changes for $local_base"
  if ! git pull; then
    echo "⚠️  Failed to pull '$local_base'. Continuing with local state."
  fi
fi

# Merge public base into local base to minimize risk of conflicts in final merge
# shellcheck disable=SC2059
sync_message="$(printf "$SYNC_MERGE_MESSAGE_TEMPLATE" "$public_base" "$local_base")"
# shellcheck disable=SC2059
feature_message="$(printf "$FEATURE_MERGE_MESSAGE_TEMPLATE" "$feature_local_branch" "$local_base")"
echo "🔁 Merging '$public_base' into '$local_base'"
git merge --no-edit -m "$sync_message" "$public_base"
echo "🔁 Merging '$feature_local_branch' into '$local_base'"
git merge --no-edit -m "$feature_message" "$feature_local_branch"

# Final merge complete, now handle branch cleanup based on user preferences
if [[ "$DELETE_BRANCHES" -eq 1 ]]; then
  echo "🧹 Cleaning up feature branches"

  if [[ "$public_branch_merged" -eq 1 ]]; then
    git branch -d "$feature_public_branch"
  else
    echo "⚠️  Forcing deletion of '$feature_public_branch' (--force used)"
    git branch -D "$feature_public_branch"
  fi

  if git merge-base --is-ancestor "$feature_local_branch" "$local_base"; then
    git branch -d "$feature_local_branch"
  else
    if [[ "$FORCE_DELETE" -eq 1 ]]; then
      echo "⚠️  Forcing deletion of '$feature_local_branch'"
      git branch -D "$feature_local_branch"
    else
      echo "⚠️  '$feature_local_branch' was not fully merged into '$local_base'."
      echo "   Local branch kept."
    fi
  fi
else
  echo "ℹ️ Feature branches preserved (--keep-branches)"
fi

echo
echo "✅ Feature finished successfully."
echo "📍 Current branch: $local_base"
