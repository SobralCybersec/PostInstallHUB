#!/usr/bin/env bash
# =============================================================================
# lib/backup.sh — Backup helpers for config-file modifications
# =============================================================================
[[ -n "${_BACKUP_LOADED:-}" ]] && return 0
_BACKUP_LOADED=1

# backup_warning FILE
#   Shows a warning before a script modifies FILE.
#   Skipped silently when POSTINSTALL_YES=1 (non-interactive / CI mode).
backup_warning() {
  local file="${1:-<unknown file>}"
  echo -e "${YELLOW}[WARNING]${NC} About to modify: ${BOLD}${file}${NC}"
  if [[ -f "$file" ]]; then
    local backup="${file}.postinstallhub.bak"
    cp "$file" "$backup"
    echo -e "          Backup saved → ${DIM}${backup}${NC}"
  fi
  if [[ "${POSTINSTALL_YES:-0}" != "1" ]]; then
    echo -e "          Press ${BOLD}Enter${NC} to continue or ${BOLD}Ctrl+C${NC} to abort."
    read -r
  fi
}
