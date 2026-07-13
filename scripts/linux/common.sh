#!/usr/bin/env bash
# =============================================================================
# scripts/linux/common.sh — Shared functions for all Linux distro scripts
# Source this file at the top of every distro script.
# =============================================================================
[[ -n "${_LINUX_COMMON_LOADED:-}" ]] && return 0
_LINUX_COMMON_LOADED=1

_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT_DIR="$(cd "${_COMMON_DIR}/../.." && pwd)"

source "${_ROOT_DIR}/lib/colors.sh"
source "${_ROOT_DIR}/lib/backup.sh"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info() { echo -e "${BLUE}[INFO]${NC}    $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} ✓ $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} ⚠ $*"; }
log_error() { echo -e "${RED}[ERROR]${NC}   ✗ $*" >&2; }
log_step() { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }

# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------
check_sudo() {
  if ! sudo -n true 2>/dev/null && ! sudo -v 2>/dev/null; then
    log_error "This script requires sudo. Ensure your user has sudo privileges."
    exit 4
  fi
}

require_os() {
  # require_os kali  — exits if /etc/os-release ID != arg
  local expected="$1"
  local actual
  actual="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release 2>/dev/null | tr -d '"' || echo unknown)"
  if [[ "$actual" != "$expected" ]]; then
    log_error "Wrong OS: expected '${expected}', got '${actual}'."
    exit 5
  fi
}

# ---------------------------------------------------------------------------
# Package helpers (Debian/apt)
# ---------------------------------------------------------------------------

# is_pkg_installed PKG — returns 0 if installed, 1 if not
is_pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# is_installed BINARY — returns 0 if binary is on PATH
is_installed() {
  command -v "$1" &>/dev/null
}

# apt_install PKG [PKG…] — idempotent: only installs packages not already present
apt_install() {
  local to_install=()
  for pkg in "$@"; do
    if ! is_pkg_installed "$pkg"; then
      to_install+=("$pkg")
    else
      log_info "Already installed: ${pkg}"
    fi
  done
  if [[ ${#to_install[@]} -eq 0 ]]; then
    return 0
  fi
  log_info "Installing: ${to_install[*]}"
  sudo apt-get install -y "${to_install[@]}"
}

# ---------------------------------------------------------------------------
# Config-file helpers
# ---------------------------------------------------------------------------

# append_once MARKER FILE CONTENT
#   Appends CONTENT to FILE only if MARKER string is not already present.
#   Uses backup_warning before first write.
append_once() {
  local marker="$1"
  local file="$2"
  shift 2
  local content="$*"

  if grep -qF "$marker" "$file" 2>/dev/null; then
    log_info "Already configured (skipping): ${marker}"
    return 0
  fi
  backup_warning "$file"
  printf '\n%s\n' "$content" >>"$file"
  log_success "Appended to ${file}: ${marker}"
}

# git_clone_once REPO_URL TARGET_DIR
#   Clones repo only if TARGET_DIR doesn't exist.
git_clone_once() {
  local url="$1"
  local target="$2"
  if [[ -d "$target" ]]; then
    log_info "Already cloned (skipping): ${target}"
    return 0
  fi
  log_info "Cloning ${url} → ${target}"
  git clone --depth=1 "$url" "$target"
  log_success "Cloned: $(basename "$target")"
}
