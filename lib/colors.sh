#!/usr/bin/env bash
# =============================================================================
# lib/colors.sh — ANSI color constants
# Sourced by all scripts; safe to source multiple times (guard via var check).
# =============================================================================
[[ -n "${_COLORS_LOADED:-}" ]] && return 0
_COLORS_LOADED=1

# shellcheck disable=SC2034  # vars sourced and used by scripts throughout the project
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color / Reset
