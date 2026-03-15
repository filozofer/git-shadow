#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Library: env.sh
# Purpose: load configuration values from .env.example and .env.
# -------------------------------------------------------------------

TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load .env.example first to ensure all variables are defined, then override with .env if it exists.
load_env() {

  # Do this first: load base settings from .env.example
  set -a
  # shellcheck disable=SC1091
  source "$TOOLKIT_ROOT/.env.example"
  set +a

  # Then override with .env if it exists
  if [[ -f "$TOOLKIT_ROOT/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$TOOLKIT_ROOT/.env"
    set +a
  fi
  
}

