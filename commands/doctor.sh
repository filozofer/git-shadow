#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: doctor.sh
# Purpose: run a suite of Git-shadow self-checks for the environment and repo.
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

echo "🔍 git-shadow doctor check"

# 1) toolkit core sanity
TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ! -d "$TOOLKIT_ROOT" ]]; then
  echo "❌ TOOLKIT_ROOT not found: $TOOLKIT_ROOT" >&2
  exit 1
fi

needed=("commands/feature/start.sh" "commands/feature/publish.sh" "commands/feature/finish.sh" "commands/commit.sh" "commands/install-hook.sh" "scripts/check-local-comments.sh" "scripts/strip-local-comments.sh")
for path in "${needed[@]}"; do
  if [[ ! -f "$TOOLKIT_ROOT/$path" ]]; then
    echo "❌ Missing required file: $path" >&2
    exit 1
  fi
done

echo "✅ Toolkit files present"

# 2) .env config
if [[ ! -f "$TOOLKIT_ROOT/.env.example" ]]; then
  echo "❌ .env.example missing" >&2
  exit 1
fi
if ! grep -q '^LOCAL_COMMENT_PATTERN=' "$TOOLKIT_ROOT/.env.example"; then
  echo "❌ LOCAL_COMMENT_PATTERN not set in .env.example" >&2
  exit 1
fi
if ! grep -q '^SHADOW_COMMIT_PREFIX=' "$TOOLKIT_ROOT/.env.example"; then
  echo "❌ SHADOW_COMMIT_PREFIX not set in .env.example" >&2
  exit 1
fi
if ! grep -q '^SHADOW_COMMIT_FILTER=' "$TOOLKIT_ROOT/.env.example"; then
  echo "❌ SHADOW_COMMIT_FILTER not set in .env.example" >&2
  exit 1
fi

echo "✅ Configuration template valid"

# 3) shell command availability
if ! command -v git >/dev/null 2>&1; then
  echo "❌ git is not installed" >&2
  exit 1
fi
echo "✅ git CLI available"

if command -v git-shadow >/dev/null 2>&1; then
  echo "✅ git-shadow CLI available"
else
  echo "⚠️ git-shadow not in PATH (usage: export PATH=\"$TOOLKIT_ROOT/bin:$PATH\")"
fi

# 4) optional alias check
if git config --global alias.shadow >/dev/null 2>&1; then
  echo "✅ git shadow alias set"
else
  echo "⚠️ git shadow alias not set (optional)"
fi

# 5) repository state (current project only)
if [[ $# -gt 0 ]]; then
  echo "Usage: $0" >&2
  exit 1
fi

project_path='.'
if [[ -d "$project_path" ]]; then
  echo "📁 Checking project path: $project_path"
  enter_project "."
  echo "✅ Inside Git repository: $(git rev-parse --is-inside-work-tree 2>/dev/null)"
  echo "🔀 Current branch: $(git branch --show-current)"
  if ! git diff --quiet; then
    echo "⚠️ Uncommitted working tree changes"
  else
    echo "✅ Working tree clean"
  fi
  if ! git diff --cached --quiet; then
    echo "⚠️ Staged changes present"
  else
    echo "✅ No staged changes"
  fi
else
  echo "⚠️ Project path not found (skipping repo checks): $project_path"
fi

echo "🏁 git-shadow doctor completed"
