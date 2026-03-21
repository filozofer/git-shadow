#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: install-hooks.sh
# Purpose: install git-shadow hooks (pre-commit and pre-push).
# -------------------------------------------------------------------

# Environment setup
TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$TOOLKIT_ROOT/lib/common.sh"

# Install hooks in current repository only
enter_project "."

# ---------------------------------------------------------------------------
# pre-commit hook — blocks commits containing local comments
# ---------------------------------------------------------------------------

pre_commit_file="$(detect_hook_file pre-commit)"
mkdir -p "$(dirname "$pre_commit_file")"

if [[ -f "$pre_commit_file" ]] && grep -Fq "$HOOK_CHECK_MARKER" "$pre_commit_file"; then
  echo "ℹ️  pre-commit hook already installed in: $pre_commit_file"
else
  if [[ -f "$pre_commit_file" ]]; then
    {
      printf '\n%s\n' "$HOOK_CHECK_MARKER"
      cat <<'HOOK'
if command -v git-shadow >/dev/null 2>&1; then
  git-shadow check-local-comments .
  exit $?
elif git config --global alias.shadow >/dev/null 2>&1; then
  git shadow check-local-comments .
  exit $?
fi
exit 0
HOOK
    } >> "$pre_commit_file"
  else
    {
      printf '#!/usr/bin/env sh\n%s\n' "$HOOK_CHECK_MARKER"
      cat <<'HOOK'
if command -v git-shadow >/dev/null 2>&1; then
  git-shadow check-local-comments .
  exit $?
elif git config --global alias.shadow >/dev/null 2>&1; then
  git shadow check-local-comments .
  exit $?
fi
exit 0
HOOK
    } > "$pre_commit_file"
    chmod +x "$pre_commit_file"
  fi

  echo "✅ pre-commit hook installed in: $pre_commit_file"
fi

# ---------------------------------------------------------------------------
# pre-push hook — warns when pushing a shadow branch to a remote
# ---------------------------------------------------------------------------

PRE_PUSH_MARKER="# git-shadow pre-push hook"
pre_push_file="$(detect_hook_file pre-push)"
mkdir -p "$(dirname "$pre_push_file")"

if [[ -f "$pre_push_file" ]] && grep -Fq "$PRE_PUSH_MARKER" "$pre_push_file"; then
  echo "ℹ️  pre-push hook already installed in: $pre_push_file"
else
  if [[ -f "$pre_push_file" ]]; then
    {
      printf '\n%s\n' "$PRE_PUSH_MARKER"
      cat <<'HOOK'
if command -v git-shadow >/dev/null 2>&1; then
  git-shadow check-shadow-push "$1" "$2"
  exit $?
elif git config --global alias.shadow >/dev/null 2>&1; then
  git shadow check-shadow-push "$1" "$2"
  exit $?
fi
exit 0
HOOK
    } >> "$pre_push_file"
  else
    {
      printf '#!/usr/bin/env sh\n%s\n' "$PRE_PUSH_MARKER"
      cat <<'HOOK'
if command -v git-shadow >/dev/null 2>&1; then
  git-shadow check-shadow-push "$1" "$2"
  exit $?
elif git config --global alias.shadow >/dev/null 2>&1; then
  git shadow check-shadow-push "$1" "$2"
  exit $?
fi
exit 0
HOOK
    } > "$pre_push_file"
    chmod +x "$pre_push_file"
  fi

  echo "✅ pre-push hook installed in: $pre_push_file"
fi
