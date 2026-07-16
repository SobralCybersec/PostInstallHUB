#!/usr/bin/env bash
# =============================================================================
# lib/colors.sh — ANSI color constants
# Sourced by all scripts; safe to source multiple times (guard via var check).
# =============================================================================
[[ -n "${_COLORS_LOADED:-}" ]] && return 0
_COLORS_LOADED=1

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export BOLD='\033[1m'
export DIM='\033[2m'
export NC='\033[0m' # No Color / Reset
