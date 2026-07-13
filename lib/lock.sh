#!/usr/bin/env bash
# =============================================================================
# lib/lock.sh — Single-instance lock file management
# Prevents two concurrent PostInstallHUB runs stomping each other.
# =============================================================================
[[ -n "${_LOCK_LOADED:-}" ]] && return 0
_LOCK_LOADED=1

LOCK_FILE="/tmp/postinstallhub.lock"

acquire_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    echo -e "${RED}[ERROR]${NC} PostInstallHUB is already running (PID $(cat "$LOCK_FILE" 2>/dev/null || echo '?'))."
    echo -e "        Stale lock? Delete it and re-run:  rm -f ${LOCK_FILE}"
    exit 3
  fi
  echo "$$" >"$LOCK_FILE"
  # Release on any exit (success, error, signal)
  trap 'rm -f "$LOCK_FILE"' EXIT INT TERM
}
