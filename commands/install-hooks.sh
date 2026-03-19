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
  pre_commit_script=''
  pre_commit_script+='if command -v git-shadow >/dev/null 2>&1; then\n'
  pre_commit_script+='  git-shadow check-local-comments .\n'
  pre_commit_script+='  exit $?\n'
  pre_commit_script+='elif git config --global alias.shadow >/dev/null 2>&1; then\n'
  pre_commit_script+='  git shadow check-local-comments .\n'
  pre_commit_script+='  exit $?\n'
  pre_commit_script+='fi\n'
  pre_commit_script+='exit 0'

  if [[ -f "$pre_commit_file" ]]; then
    printf '\n%s\n%s\n' "$HOOK_CHECK_MARKER" "$pre_commit_script" >> "$pre_commit_file"
  else
    cat > "$pre_commit_file" <<EOF
#!/usr/bin/env sh
$HOOK_CHECK_MARKER
$pre_commit_script
EOF
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
  pre_push_script=''
  pre_push_script+='if command -v git-shadow >/dev/null 2>&1; then\n'
  pre_push_script+='  git-shadow check-shadow-push "$1" "$2"\n'
  pre_push_script+='  exit $?\n'
  pre_push_script+='elif git config --global alias.shadow >/dev/null 2>&1; then\n'
  pre_push_script+='  git shadow check-shadow-push "$1" "$2"\n'
  pre_push_script+='  exit $?\n'
  pre_push_script+='fi\n'
  pre_push_script+='exit 0'

  if [[ -f "$pre_push_file" ]]; then
    printf '\n%s\n%s\n' "$PRE_PUSH_MARKER" "$pre_push_script" >> "$pre_push_file"
  else
    cat > "$pre_push_file" <<EOF
#!/usr/bin/env sh
$PRE_PUSH_MARKER
$pre_push_script
EOF
    chmod +x "$pre_push_file"
  fi

  echo "✅ pre-push hook installed in: $pre_push_file"
fi
