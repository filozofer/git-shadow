#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: strip-local-comments.sh
# Purpose: remove local comment markers from staged files in Git index.
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# Check that project directory is provided and exists
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <project-dir>" >&2
  exit 1
fi

# Navigate to project and get list of staged files
enter_project "$1"
has_changes=0
while IFS= read -r -d '' file; do
  # Skip deleted files; only process added/copied/modified files
  if [[ ! -f "$file" ]]; then
    continue
  fi

  # Skip binary files; only text files can contain local comment markers
  if git show ":$file" 2>/dev/null | grep -qI .; then
    :
  else
    continue
  fi

  if ! git show ":$file" 2>/dev/null | grep -qE "$LOCAL_COMMENT_PATTERN"; then
    continue
  fi

  tmp_file="$(mktemp)"

  # Remove lines matching the local comment pattern while preserving other content.
  git show ":$file" | grep -vE "$LOCAL_COMMENT_PATTERN" > "$tmp_file"
  index_info="$(git ls-files -s -- "$file")"
  if [[ -z "$index_info" ]]; then
    echo "Unable to read index info for $file" >&2
    rm -f "$tmp_file"
    exit 1
  fi

  # Update the Git index with the cleaned file content, preserving mode and path
  mode="$(printf '%s\n' "$index_info" | awk '{print $1}')"
  blob_sha="$(git hash-object -w "$tmp_file")"
  git update-index --cacheinfo "$mode,$blob_sha,$file"

  # Clean up temporary file and mark that we made changes to the index
  rm -f "$tmp_file"
  echo "Local comments removed from index: $file"
  has_changes=1
done < <(git diff --cached --name-only -z --diff-filter=ACM)

# Inform the user
if [[ "$has_changes" -eq 0 ]]; then
  echo "No local comments found in staged files."
else
  echo "Index cleanup complete. Working tree was left untouched."
fi
