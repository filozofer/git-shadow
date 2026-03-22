#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Library: env.sh
# Purpose: load configuration using a three-tier hierarchy.
#
# Priority (highest to lowest):
#   1. Project-level : .git-shadow.env  (in $PWD when command runs)
#   2. User-level    : ~/.config/git-shadow/config.env  (XDG-aware)
#   3. Built-in defaults : config/defaults.env  (shipped with the tool)
# -------------------------------------------------------------------

TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Warn about any key in FILE that is not declared in config/defaults.env.
_check_unknown_keys() {
  local file="$1"
  local line key
  while IFS= read -r line; do
    [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)= ]] || continue
    key="${BASH_REMATCH[1]}"
    if ! grep -qE "^${key}=" "$TOOLKIT_ROOT/config/defaults.env"; then
      printf '⚠️  [git-shadow] Unknown config key "%s" in: %s\n' "$key" "$file" >&2
    fi
  done < "$file"
}

load_env() {

  # 1. Built-in defaults (always present, shipped with the tool)
  set -a
  # shellcheck disable=SC1091
  source "$TOOLKIT_ROOT/config/defaults.env"
  set +a

  # 2. User-level config (XDG-aware, optional)
  local user_config="${XDG_CONFIG_HOME:-$HOME/.config}/git-shadow/config.env"
  if [[ -f "$user_config" ]]; then
    set -a
    # shellcheck disable=SC1090,SC1091
    source "$user_config"
    set +a
    _check_unknown_keys "$user_config"
  fi

  # 3. Project-level config (optional, from current working directory)
  local project_config="$PWD/.git-shadow.env"
  if [[ -f "$project_config" ]]; then
    set -a
    # shellcheck disable=SC1090,SC1091
    source "$project_config"
    set +a
    _check_unknown_keys "$project_config"
  fi

}
