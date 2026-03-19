#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: check-shadow-push.sh
# Purpose: warn and block pushes of shadow branches to a remote.
#
# Called by the pre-push hook with:
#   $1 — remote name
#   $2 — remote URL
#   stdin — lines of: <local-ref> <local-sha1> <remote-ref> <remote-sha1>
#
# Bypass: ALLOW_LOCAL_PUSH=true in config, or git push --no-verify
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

REMOTE="${1:-origin}"

# Bypass: allow push if ALLOW_LOCAL_PUSH is set to true in config.
if [[ "${ALLOW_LOCAL_PUSH:-false}" == "true" ]]; then
  exit 0
fi

# Read pushed refs from stdin and collect any shadow branches.
SHADOW_BRANCHES=()
while IFS=' ' read -r local_ref _local_sha _remote_ref _remote_sha; do
  # Delete pushes have a zero sha — nothing to check.
  [[ "$local_ref" == "(delete)" ]] && continue
  # Extract branch name from full ref (refs/heads/feature@local → feature@local).
  branch="${local_ref#refs/heads/}"
  if [[ "$branch" == *"${LOCAL_SUFFIX}" ]]; then
    SHADOW_BRANCHES+=("$branch")
  fi
done

if [[ ${#SHADOW_BRANCHES[@]} -eq 0 ]]; then
  exit 0
fi

printf '\n' >&2
printf '⚠️  [git-shadow] Push blocked: shadow branch(es) should not be pushed to a remote.\n' >&2
printf '\n' >&2
for branch in "${SHADOW_BRANCHES[@]}"; do
  printf '   📌 %s → %s\n' "$branch" "$REMOTE" >&2
done
printf '\n' >&2
printf '   Shadow branches ("%s" suffix) are meant to stay local.\n' "$LOCAL_SUFFIX" >&2
printf '   They may contain private notes, AI context, or unfinished thinking.\n' >&2
printf '\n' >&2
printf '   To push anyway (e.g. for backup purposes):\n' >&2
printf '\n' >&2
printf '   git push --no-verify\n' >&2
printf '\n' >&2
exit 1
