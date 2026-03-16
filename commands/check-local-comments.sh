#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------------------------
# Script: check-local-comments.sh
# Purpose: wrapper to run local comment check from the toolkit dispatcher.
# -------------------------------------------------------------------

TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$TOOLKIT_ROOT/scripts/check-local-comments.sh" "$@"
