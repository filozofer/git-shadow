#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: status.sh
# Purpose: display the current Git Shadow state of the branch pair.
# -------------------------------------------------------------------

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

JSON=false
for arg in "$@"; do
  case "$arg" in
    --json) JSON=true ;;
    *) echo "❌ Unknown argument: $arg" >&2
       echo "Usage: git shadow status [--json]" >&2
       exit 1 ;;
  esac
done

_json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

enter_project "."

CURRENT_BRANCH="$(current_branch)"

if [[ -z "$CURRENT_BRANCH" ]]; then
  if $JSON; then
    printf '{"error": "detached HEAD state"}\n'
  else
    echo "❌ Detached HEAD state — not on any branch." >&2
  fi
  exit 1
fi

# Detect branch type and resolve the counterpart
IS_SHADOW=0
if [[ "$CURRENT_BRANCH" =~ ${LOCAL_SUFFIX}$ ]]; then
  IS_SHADOW=1
  SHADOW_BRANCH="$CURRENT_BRANCH"
  PUBLIC_BRANCH="${CURRENT_BRANCH%$LOCAL_SUFFIX}"
else
  PUBLIC_BRANCH="$CURRENT_BRANCH"
  SHADOW_BRANCH="${CURRENT_BRANCH}${LOCAL_SUFFIX}"
fi

# Verify at least one shadow branch exists in the pair
shadow_exists=0
public_exists=0
git show-ref --verify --quiet "refs/heads/$SHADOW_BRANCH" && shadow_exists=1 || true
git show-ref --verify --quiet "refs/heads/$PUBLIC_BRANCH" && public_exists=1 || true

if [[ $shadow_exists -eq 0 && $IS_SHADOW -eq 0 ]]; then
  if $JSON; then
    printf '{"error": "not a Git Shadow branch", "current_branch": "%s"}\n' "$(_json_escape "$CURRENT_BRANCH")"
  else
    echo "Not a Git Shadow branch."
    echo "Current branch \`$CURRENT_BRANCH\` is neither a shadow branch nor a public branch managed by Git Shadow."
  fi
  exit 1
fi

# Compute metrics
publishable_count=0
memory_count=0
public_ahead=0

if [[ $shadow_exists -eq 1 && $public_exists -eq 1 ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    cherry_status="${line:0:1}"
    [[ "$cherry_status" != "+" ]] && continue
    sha="${line:2}"
    subject="$(git log -1 --pretty=%s "$sha")"
    if [[ "$subject" =~ $SHADOW_COMMIT_FILTER ]]; then
      (( memory_count++ )) || true
    else
      (( publishable_count++ )) || true
    fi
  done < <(git cherry "$PUBLIC_BRANCH" "$SHADOW_BRANCH" 2>/dev/null || true)

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "+" ]] && (( public_ahead++ )) || true
  done < <(git cherry "$SHADOW_BRANCH" "$PUBLIC_BRANCH" 2>/dev/null || true)
fi

# Determine status label and next step
if [[ $shadow_exists -eq 0 ]]; then
  STATUS_LABEL="shadow branch missing"
  STATUS_EMOJI="❌"
  NEXT_STEP="create it with \`git shadow feature start ${PUBLIC_BRANCH}\`"
elif [[ $public_exists -eq 0 ]]; then
  STATUS_LABEL="public branch missing"
  STATUS_EMOJI="❌"
  NEXT_STEP="the public branch \`${PUBLIC_BRANCH}\` does not exist yet"
elif [[ $publishable_count -gt 0 && $public_ahead -eq 0 ]]; then
  STATUS_LABEL="ready to publish"
  STATUS_EMOJI="✅"
  NEXT_STEP="run \`git shadow feature publish\`"
elif [[ $publishable_count -eq 0 && $public_ahead -eq 0 ]]; then
  STATUS_LABEL="up to date"
  STATUS_EMOJI="✅"
  NEXT_STEP="nothing — shadow and public branches are in sync"
elif [[ $publishable_count -eq 0 && $public_ahead -gt 0 ]]; then
  STATUS_LABEL="public branch ahead"
  STATUS_EMOJI="⚠️"
  NEXT_STEP="switch to \`$SHADOW_BRANCH\` and merge \`$PUBLIC_BRANCH\` to sync"
else
  STATUS_LABEL="diverged"
  STATUS_EMOJI="⚠️"
  NEXT_STEP="publish pending commits first with \`git shadow feature publish\`, then sync"
fi

# --- JSON output ---
if $JSON; then
  BRANCH_TYPE="$( [[ $IS_SHADOW -eq 1 ]] && echo shadow || echo public )"
  printf '{\n'
  printf '  "current_branch": "%s",\n'              "$(_json_escape "$CURRENT_BRANCH")"
  printf '  "branch_type": "%s",\n'                 "$BRANCH_TYPE"
  printf '  "shadow_branch": "%s",\n'               "$(_json_escape "$SHADOW_BRANCH")"
  printf '  "public_branch": "%s",\n'               "$(_json_escape "$PUBLIC_BRANCH")"
  printf '  "publishable_count": %s,\n'             "$publishable_count"
  printf '  "memory_count": %s,\n'                  "$memory_count"
  printf '  "public_ahead": %s,\n'                  "$public_ahead"
  printf '  "status": "%s",\n'                      "$(_json_escape "$STATUS_LABEL")"
  printf '  "next_step": "%s"\n'                    "$(_json_escape "$NEXT_STEP")"
  printf '}\n'
  exit 0
fi

# --- Human output ---
BRANCH_EMOJI="$( [[ $IS_SHADOW -eq 1 ]] && echo "🧠" || echo "🌿" )"

echo "Git Shadow Status"
echo ""

if [[ $IS_SHADOW -eq 1 ]]; then
  printf '%s Current branch : %s\n' "$BRANCH_EMOJI" "$SHADOW_BRANCH"
  printf '   Branch type    : shadow\n'
  printf '   Public branch  : %s\n'   "$PUBLIC_BRANCH"
else
  printf '%s Current branch : %s\n' "$BRANCH_EMOJI" "$PUBLIC_BRANCH"
  printf '   Branch type    : public\n'
  printf '   Shadow branch  : %s\n'   "$SHADOW_BRANCH"
fi

echo ""

if [[ $shadow_exists -eq 1 && $public_exists -eq 1 ]]; then
  printf '   Publishable commits pending : %s\n' "$publishable_count"
  printf '   Shadow-only [MEMORY] commits: %s\n' "$memory_count"
  if [[ $public_ahead -gt 0 ]]; then
    printf '   Public branch ahead         : yes (%s)\n' "$public_ahead"
  else
    printf '   Public branch ahead         : no\n'
  fi
fi

echo ""
printf '%s Status    : %s\n' "$STATUS_EMOJI" "$STATUS_LABEL"
printf '   Next step : %s\n' "$NEXT_STEP"
