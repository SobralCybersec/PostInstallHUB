#!/usr/bin/env bash
# =============================================================================
# install.sh — PostInstallHUB entry point
#
# Usage:
#   bash install.sh               # auto-detect OS, interactive
#   POSTINSTALL_YES=1 bash install.sh   # non-interactive / CI mode
#
# Supported distros: kali · ubuntu · debian · arch · fedora · endeavouros · cachyos · windows
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Load lib ---
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/lock.sh"

# ---------------------------------------------------------------------------
detect_os() {
  local id
  if [[ -f /etc/os-release ]]; then
    id="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release | tr -d '"')"
    echo "${id:-unknown}"
  elif uname -s | grep -qi "mingw\|cygwin\|msys"; then
    echo "windows"
  else
    echo "unknown"
  fi
}

# ---------------------------------------------------------------------------
main() {
  acquire_lock

  local distro
  distro="$(detect_os)"

  echo -e "\n${BOLD}PostInstallHUB${NC} — OS detected: ${CYAN}${distro}${NC}\n"

  case "$distro" in
    kali)
      source "${SCRIPT_DIR}/scripts/linux/kali.sh"
      run_install
      ;;
    ubuntu|zorin|linuxmint|pop|elementary|neon)
      source "${SCRIPT_DIR}/scripts/linux/ubuntu.sh"
      run_install
      ;;
    debian)
      source "${SCRIPT_DIR}/scripts/linux/debian.sh"
      run_install
      ;;
    arch|manjaro)
      source "${SCRIPT_DIR}/scripts/linux/arch.sh"
      run_install
      ;;
    endeavouros|cachyos|garuda)
      source "${SCRIPT_DIR}/scripts/linux/endeavour.sh"
      run_install
      ;;
    fedora)
      source "${SCRIPT_DIR}/scripts/linux/fedora.sh"
      run_install
      ;;
    windows)
      echo -e "${YELLOW}[INFO]${NC} Windows detected — run scripts/windows/setup.ps1 in PowerShell 7:"
      echo -e "         ${CYAN}Set-ExecutionPolicy Bypass -Scope Process -Force${NC}"
      echo -e "         ${CYAN}.\\scripts\\windows\\setup.ps1${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}[ERROR]${NC} Unsupported OS: '${distro}'"
      echo -e "         Supported: kali · ubuntu · debian · arch · endeavouros · cachyos · fedora · windows"
      echo -e "         See docs/03-architecture/INTEGRATIONS.md for adding a new distro."
      exit 2
      ;;
  esac
}

main "$@"
