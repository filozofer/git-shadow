#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: feature/publish.sh
# Purpose: push clean commits from local shadow branch to public branch.
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)/common.sh"

COMMIT_FIRST=0
COMMIT_MESSAGE=""

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --commit)
      COMMIT_FIRST=1
      shift
      ;;
    -m)
      if [[ $# -lt 2 ]]; then
        echo "❌ The -m option requires a message." >&2
        exit 1
      fi
      COMMIT_MESSAGE="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown argument: $1" >&2
      echo "Usage: git shadow feature publish [--commit] [-m \"MESSAGE\"]" >&2
      exit 1
      ;;
  esac
done

# Enter project and validate current branch
enter_project "."
CURRENT_BRANCH="$(current_branch)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "❌ Unable to determine current branch." >&2
  exit 1
fi
if [[ ! "$CURRENT_BRANCH" =~ ${LOCAL_SUFFIX}$ ]]; then
  echo "❌ git publish must be run from a branch ending with '$LOCAL_SUFFIX'." >&2
  echo "   Current branch: $CURRENT_BRANCH" >&2
  exit 1
fi
TARGET_BRANCH="${CURRENT_BRANCH%"$LOCAL_SUFFIX"}"
SOURCE_BRANCH="$CURRENT_BRANCH"

# If requested, commit any remaining changes in the local branch before publishing
if [[ "$COMMIT_FIRST" -eq 1 ]]; then
  if [[ -n "$COMMIT_MESSAGE" ]]; then
    "$TOOLKIT_ROOT/scripts/commit-with-separate-local-comments.sh" -m "$COMMIT_MESSAGE"
  else
    "$TOOLKIT_ROOT/scripts/commit-with-separate-local-comments.sh"
  fi
fi

# Publish commits from local branch to public branch using cherry-pick, skipping any commits that appear to already be present or that contain local comments
ensure_clean_repo
if ! git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
  echo "❌ Target branch does not exist: $TARGET_BRANCH" >&2
  exit 1
fi

# Determine which commits from the local branch are not yet in the public branch and do not contain local comments
echo "🔀 Checkout target branch: $TARGET_BRANCH"
git checkout "$TARGET_BRANCH"
commits_to_pick=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  status="${line:0:1}"
  sha="${line:2}"
  subject="$(git log -1 --pretty=%s "$sha")"

  # Skip commits that appear to already be in the target branch
  if [[ "$status" != "+" ]]; then
    echo "⏭️  Ignored (patch already present): $sha  $subject"
    continue
  fi

  # Skip commits that match the SHADOW_COMMIT_FILTER
  if [[ "$subject" =~ $SHADOW_COMMIT_FILTER ]]; then
    echo "⏭️  Ignored (shadow commit): $sha  $subject"
    continue
  fi

  commits_to_pick+=("$sha")
done < <(git cherry "$TARGET_BRANCH" "$SOURCE_BRANCH")

# If there are commits to pick, display them and proceed with cherry-pick, otherwise exit with a message
if [[ "${#commits_to_pick[@]}" -eq 0 ]]; then
  echo "ℹ️ No publishable commits to cherry-pick from $SOURCE_BRANCH to $TARGET_BRANCH."
  exit 0
fi

# Display commits to be cherry-picked and confirm with user before proceeding
echo "📦 Commits to cherry-pick:"
for sha in "${commits_to_pick[@]}"; do
  git log -1 --pretty=' - %h %s' "$sha"
done

# Cherry picking proccess
for sha in "${commits_to_pick[@]}"; do
  echo "🍒 Cherry-picking $sha"

  if git cherry-pick "$sha"; then
    continue
  fi

  cherry_pick_head_file="$(git rev-parse --git-path CHERRY_PICK_HEAD)"
  if [[ -f "$cherry_pick_head_file" ]] && git diff --quiet && git diff --cached --quiet; then
    echo "⏭️  Empty cherry-pick detected, skipping: $sha"
    git cherry-pick --skip
    continue
  fi

  echo "❌ Cherry-pick conflict on commit: $sha" >&2
  echo "Resolve it, then run 'git cherry-pick --continue' or 'git cherry-pick --abort'." >&2
  exit 1
done

echo "✅ Publish completed on branch: $TARGET_BRANCH"
