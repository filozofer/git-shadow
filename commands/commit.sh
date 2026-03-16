#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: commit.sh
# Purpose: commit cleaned code, then commit local comments separately.
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# Validate input args
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <project-dir> [-m \"message\"]" >&2
  exit 1
fi
PROJECT_ARG="$1"
shift
COMMIT_MESSAGE=""

# Next step: parse optional `-m` commit message
while getopts "m:" opt; do
  case $opt in
    m) COMMIT_MESSAGE="$OPTARG" ;;
    *)
      echo "Usage: $0 <project-dir> [-m \"message\"]" >&2
      exit 1
      ;;
  esac
done

# Enter project directory
enter_project "$PROJECT_ARG"

# Verify there is something to commit
if git diff --cached --quiet; then
  echo "❌ No staged changes." >&2
  exit 1
fi

# Remove local comments from index while keeping working tree unmodified
"$TOOLKIT_ROOT/scripts/strip-local-comments.sh" "$PWD"

# If no code remains after stripping comments, abort commit
if git diff --cached --quiet; then
  echo "❌ After removing local comments, nothing remains to commit." >&2
  echo "You can commit your local comments with: " >&2
  echo "git commit -m \"[COMMENTS] title\" --no-verify"
  exit 1
fi

# Create main commit (clean code)
if [[ -n "$COMMIT_MESSAGE" ]]; then
  git commit -m "$COMMIT_MESSAGE"
else
  git commit
fi

# Remember last non-comment commit message for comments commit reference
last_commit_message="$(git log -1 --pretty=%s)"

# Stage changes again to capture local comments that remain
git add .

if git diff --cached --quiet; then
  echo "ℹ️ No local comments to save in a separate commit."
  exit 0
fi

# Commit local comments in a separate commit
git commit -m "[COMMENTS] $last_commit_message" --no-verify
