#!/usr/bin/env bash
# =============================================================================
# install.sh — PostInstallHUB entry point
#
# Usage:
#   bash install.sh                              # auto-detect OS, interactive
#   POSTINSTALL_YES=1 bash install.sh            # non-interactive / CI mode
#   bash install.sh --POSTINSTALL_YES=1          # same, via CLI flag
#   bash install.sh --UBUNTU_NVIDIA=1 --POSTINSTALL_DOTFILES=jakoolit
#   bash install.sh --OPENSUSE_PACKMAN=1 --OPENSUSE_GAMING=1
#   bash install.sh --NIXOS_FLAKES=1 --NIXOS_HOME_MANAGER=1
#   bash install.sh --help                       # show this usage and exit
#
# CLI flags bypass the TUI — KEY=VALUE sets that var; bare --KEY sets KEY=1.
# Any env var the distro scripts read can be passed as --KEY=VALUE.
#
# Supported distros:
#   kali · ubuntu · zorin · linuxmint · pop · elementary · neon
#   debian · arch · manjaro · endeavouros · cachyos · garuda
#   fedora · opensuse-leap · opensuse-tumbleweed · opensuse · nixos · windows
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Load lib ---
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/lock.sh"
source "${SCRIPT_DIR}/lib/tui.sh"

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
_parse_cli_flags() {
  for arg in "$@"; do
    case "$arg" in
      --help)
        grep '^#' "${BASH_SOURCE[0]}" | head -20 | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      --*=*)
        local key="${arg#--}"
        key="${key%%=*}"
        local val="${arg#*=}"
        export "${key}=${val}"
        echo -e "${DIM}[CLI] ${key}=${val}${NC}"
        ;;
      --*)
        local key="${arg#--}"
        export "${key}=1"
        echo -e "${DIM}[CLI] ${key}=1${NC}"
        ;;
      -*)
        echo -e "${YELLOW}[WARN]${NC} Unknown flag: ${arg} (ignored)"
        ;;
      *)
        # non-flag positional arg — silently skip
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
main() {
  _parse_cli_flags "$@"

  acquire_lock

  local distro
  distro="$(detect_os)"

  echo -e "\n${BOLD}PostInstallHUB${NC} — OS detected: ${CYAN}${distro}${NC}\n"

  run_config_tui "$distro"

  case "$distro" in
    kali)
      source "${SCRIPT_DIR}/scripts/linux/kali.sh"
      run_install
      ;;
    ubuntu | zorin | linuxmint | pop | elementary | neon)
      source "${SCRIPT_DIR}/scripts/linux/ubuntu.sh"
      run_install
      ;;
    debian)
      source "${SCRIPT_DIR}/scripts/linux/debian.sh"
      run_install
      ;;
    arch | manjaro)
      source "${SCRIPT_DIR}/scripts/linux/arch.sh"
      run_install
      ;;
    endeavouros | cachyos | garuda)
      source "${SCRIPT_DIR}/scripts/linux/endeavour.sh"
      run_install
      ;;
    fedora)
      source "${SCRIPT_DIR}/scripts/linux/fedora.sh"
      run_install
      ;;
    opensuse-leap | opensuse-tumbleweed | opensuse)
      source "${SCRIPT_DIR}/scripts/linux/opensuse.sh"
      run_install
      ;;
    nixos)
      source "${SCRIPT_DIR}/scripts/linux/nixos.sh"
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
      echo -e "         Supported: kali · ubuntu · debian · arch · endeavouros · cachyos · fedora · opensuse · nixos · windows"
      echo -e "         See docs/03-architecture/INTEGRATIONS.md for adding a new distro."
      exit 2
      ;;
  esac
}

main "$@"
