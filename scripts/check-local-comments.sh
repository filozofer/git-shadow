#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: check-local-comments.sh
# Purpose: reject commits with local-only comments in staged files.
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# Validate arguments
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <project-dir>" >&2
  exit 1
fi

# Navigate to project
enter_project "$1"

# Get list of staged files and check for local comments
staged_files="$(git diff --cached --name-only --diff-filter=ACM)"
if [[ -z "$staged_files" ]]; then
  exit 0
fi
has_local_comments=0
while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  # Regex search base on LOCAL_COMMENT_PATTERN
  if git show ":$file" 2>/dev/null | grep -nE "$LOCAL_COMMENT_PATTERN" >/dev/null 2>&1; then
    if [[ "$has_local_comments" -eq 0 ]]; then
      echo "❌ Commit blocked: local comments are still present in staged files."
      echo
    fi
    has_local_comments=1
    echo "File: $file"
    git show ":$file" | grep -nE "$LOCAL_COMMENT_PATTERN" || true
    echo
  fi
done <<< "$staged_files"

# Inform the user if local comments were found and reject the commit
if [[ "$has_local_comments" -eq 1 ]]; then
  echo "Run this first:"
  echo "$TOOLKIT_ROOT/scripts/strip-local-comments.sh $PWD"
  exit 1
fi
