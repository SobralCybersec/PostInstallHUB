#!/usr/bin/env bash
# =============================================================================
# tests/test_opensuse.sh — Smoke tests for scripts/linux/opensuse.sh
#
# Run AFTER install.sh on a live openSUSE box, or in dry-run mode with stubs
# to verify run_install() completes without errors.
#
# Usage:
#   bash tests/test_opensuse.sh
#   POSTINSTALL_YES=1 bash tests/test_opensuse.sh
#   OPENSUSE_NVIDIA=1 OPENSUSE_GAMING=1 OPENSUSE_PACKMAN=1 bash tests/test_opensuse.sh
#
# Exit code: 0 = all pass · 1 = one or more failures
# =============================================================================
set -uo pipefail

_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT_DIR="$(cd "${_TEST_DIR}/.." && pwd)"

source "${_ROOT_DIR}/lib/colors.sh"

# ---------------------------------------------------------------------------
_PASS=0
_FAIL=0

_pass() { echo -e "${GREEN}[PASS]${NC} $*"; (( _PASS++ )) || true; }
_fail() { echo -e "${RED}[FAIL]${NC} $*"; (( _FAIL++ )) || true; }
_skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; }

check_cmd()  { command -v "$1" &>/dev/null  && _pass "binary on PATH: $1"    || _fail "binary missing: $1"; }
check_file() { [[ -f "$1" ]]                && _pass "file exists: $1"         || _fail "file missing: $1"; }
check_rpm()  { rpm -q "$1" &>/dev/null      && _pass "rpm installed: $1"       || _fail "rpm missing: $1"; }
check_grep() { grep -qF "$2" "$1" 2>/dev/null && _pass "found in $1: $2"      || _fail "missing in $1: $2"; }
check_flatpak_app() {
  flatpak list --app 2>/dev/null | grep -q "^$1" \
    && _pass "flatpak installed: $1" \
    || _fail "flatpak missing: $1"
}
check_flatpak_remote() {
  flatpak remotes 2>/dev/null | grep -q "^$1" \
    && _pass "flatpak remote: $1" \
    || _fail "flatpak remote missing: $1"
}

# ---------------------------------------------------------------------------
# Detect whether we're running on actual openSUSE.
# If not, we run a dry-run stub test instead of live system checks.
# ---------------------------------------------------------------------------
_ACTUAL_OS="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release 2>/dev/null | tr -d '"' || echo unknown)"
_IS_OPENSUSE=false
case "$_ACTUAL_OS" in
  opensuse-leap|opensuse-tumbleweed|opensuse|suse) _IS_OPENSUSE=true ;;
esac

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}PostInstallHUB — openSUSE Smoke Tests${NC}"
echo -e "${DIM}OS detected: ${_ACTUAL_OS}${NC}\n"

# ============================================================================
# DRY-RUN STUB TEST
# When not on openSUSE, verify run_install() wires up correctly by stubbing
# out all system-mutating commands and checking it exits 0.
# ============================================================================
if [[ "$_IS_OPENSUSE" == false ]]; then
  echo -e "${CYAN}── Dry-run (stub) test — not running on openSUSE ──${NC}"

  (
    set -euo pipefail

    # Stub /etc/os-release so _require_opensuse_family passes
    export _OPENSUSE_OS_RELEASE_OVERRIDE="opensuse-tumbleweed"

    # Source common.sh first so log_* exist before we stub them out
    source "${_ROOT_DIR}/lib/colors.sh"
    source "${_ROOT_DIR}/lib/backup.sh"

    # Override require_os to be a no-op (common.sh's version checks ID literal)
    require_os() { return 0; }

    # Stub _require_opensuse_family so it always passes
    _require_opensuse_family() { return 0; }

    # Stub check_sudo — no sudo in tests
    check_sudo() { return 0; }

    # Stub zypper — record calls, never actually install
    zypper() { echo "[stub] zypper $*"; return 0; }
    sudo()   { echo "[stub] sudo $*";   return 0; }

    # Stub flatpak — list returns empty so everything looks uninstalled,
    # but install is a no-op stub
    flatpak() {
      case "${1:-}" in
        list)    echo ""       ;;
        remotes) echo ""       ;;
        *)       echo "[stub] flatpak $*" ;;
      esac
      return 0
    }

    # Stub curl (used in oh-my-zsh install)
    curl() { echo "[stub] curl $*"; return 0; }

    # Stub chsh
    chsh() { echo "[stub] chsh $*"; return 0; }

    # Stub getent so chsh comparison triggers "not default yet"
    getent() { echo "user:x:1000:1000::/home/user:/bin/bash"; }

    # Stub append_once (needs backup_warning stub too)
    backup_warning() { return 0; }
    append_once() { echo "[stub] append_once: marker='$1' file='$2'"; return 0; }

    # Stub step_dotfiles (from dotfiles.sh)
    step_dotfiles() { echo "[stub] step_dotfiles"; return 0; }

    # Stub git_clone_once (used transitively in some paths)
    git_clone_once() { echo "[stub] git_clone_once $*"; return 0; }

    # Needed by log_step etc. — already sourced via colors.sh above,
    # but define is_installed so zypper_install can call it
    is_installed() { command -v "$1" &>/dev/null; }

    # Now define the helpers and steps from opensuse.sh inline
    # (We source opensuse.sh itself — stubs above override the real commands)
    # We need to override /etc/os-release read inside _require_opensuse_family,
    # so we redefine it after sourcing.
    POSTINSTALL_YES=1 \
    OPENSUSE_PACKMAN=1 \
    OPENSUSE_NVIDIA=1 \
    OPENSUSE_GAMING=1 \
      source "${_ROOT_DIR}/scripts/linux/opensuse.sh"

    # Re-stub after source (source may have defined real versions of helpers
    # that call sudo/zypper — our stubs are already in scope since bash
    # resolves function names at call time, not definition time)
    _require_opensuse_family() { return 0; }
    check_sudo() { return 0; }

    run_install
  ) && echo -e "${GREEN}[PASS]${NC} run_install() stub dry-run: exit 0" && (( _PASS++ )) || true \
    || { echo -e "${RED}[FAIL]${NC} run_install() stub dry-run: non-zero exit"; (( _FAIL++ )) || true; }

  echo ""
fi

# ============================================================================
# LIVE SYSTEM CHECKS (only run on actual openSUSE)
# ============================================================================
if [[ "$_IS_OPENSUSE" == true ]]; then

  # ── Step 1: system update ─────────────────────────────────────────────
  echo -e "${CYAN}── System ──${NC}"
  # zypper itself being present is the proxy check for "update ran"
  check_cmd zypper

  # ── Step 3: Essential packages ────────────────────────────────────────
  echo -e "\n${CYAN}── Essential Packages ──${NC}"
  for bin in curl git wget htop neovim rg fzf zsh; do
    check_cmd "$bin"
  done
  # bat ships as 'bat' on openSUSE (no batcat rename)
  check_cmd bat
  # eza
  check_cmd eza
  # fd
  check_cmd fd

  # ── Step 4: Flatpak ───────────────────────────────────────────────────
  echo -e "\n${CYAN}── Flatpak ──${NC}"
  check_cmd flatpak
  check_flatpak_remote flathub
  check_flatpak_app org.gnome.Extensions
  check_flatpak_app com.github.tchx84.Flatseal
  check_flatpak_app com.brave.Browser
  check_flatpak_app com.github.johnfactotum.Foliate

  # ── Step 2: Packman (optional) ────────────────────────────────────────
  if [[ "${OPENSUSE_PACKMAN:-0}" == "1" ]]; then
    echo -e "\n${CYAN}── Packman (OPENSUSE_PACKMAN=1) ──${NC}"
    sudo zypper repos 2>/dev/null | grep -q "packman" \
      && _pass "Packman repo configured" \
      || _fail "Packman repo NOT configured"
  fi

  # ── Step 5: NVIDIA (optional) ─────────────────────────────────────────
  if [[ "${OPENSUSE_NVIDIA:-0}" == "1" ]]; then
    echo -e "\n${CYAN}── NVIDIA (OPENSUSE_NVIDIA=1) ──${NC}"
    sudo zypper repos 2>/dev/null | grep -q "NVIDIA" \
      && _pass "NVIDIA repo configured" \
      || _fail "NVIDIA repo NOT configured"
    check_rpm nvidia-glG05
    check_rpm nvidia-computeG05
  fi

  # ── Step 6: Gaming (optional) ─────────────────────────────────────────
  if [[ "${OPENSUSE_GAMING:-0}" == "1" ]]; then
    echo -e "\n${CYAN}── Gaming (OPENSUSE_GAMING=1) ──${NC}"
    check_flatpak_app com.valvesoftware.Steam
    check_flatpak_app net.lutris.Lutris
    check_flatpak_app com.github.Matoking.protontricks
    check_rpm gamemode
  fi

  # ── Step 7: ZSH ───────────────────────────────────────────────────────
  echo -e "\n${CYAN}── ZSH ──${NC}"
  check_cmd zsh
  [[ -d "${HOME}/.oh-my-zsh" ]] \
    && _pass "oh-my-zsh installed: ~/.oh-my-zsh" \
    || _fail "oh-my-zsh missing: ~/.oh-my-zsh"
  check_grep "${HOME}/.zshrc" "zsh-autosuggestions"

  CURRENT_SHELL="$(getent passwd "$(whoami)" | cut -d: -f7)"
  [[ "$CURRENT_SHELL" == "$(command -v zsh)" ]] \
    && _pass "Default shell is ZSH: ${CURRENT_SHELL}" \
    || _fail "Default shell is NOT ZSH: ${CURRENT_SHELL}"

fi

# ============================================================================
# Script syntax checks (always run, regardless of OS)
# ============================================================================
echo -e "\n${CYAN}── Script syntax ──${NC}"
for script in \
  "${_ROOT_DIR}/install.sh" \
  "${_ROOT_DIR}/lib/colors.sh" \
  "${_ROOT_DIR}/lib/lock.sh" \
  "${_ROOT_DIR}/lib/backup.sh" \
  "${_ROOT_DIR}/scripts/linux/common.sh" \
  "${_ROOT_DIR}/scripts/linux/dotfiles.sh" \
  "${_ROOT_DIR}/scripts/linux/opensuse.sh"; do
  bash -n "$script" 2>/dev/null \
    && _pass "syntax OK: $(basename "$script")" \
    || _fail "syntax ERR: $(basename "$script")"
done

# ── lib/ double-source guards ─────────────────────────────────────────────
echo -e "\n${CYAN}── lib/ double-source guards ──${NC}"
for lib in colors lock backup; do
  (
    # shellcheck source=/dev/null
    source "${_ROOT_DIR}/lib/${lib}.sh"
    # shellcheck source=/dev/null
    source "${_ROOT_DIR}/lib/${lib}.sh"
    var="_$(echo "$lib" | tr '[:lower:]' '[:upper:]')_LOADED"
    [[ -n "${!var:-}" ]] \
      && echo -e "${GREEN}[PASS]${NC} ${lib}.sh: guard works" \
      || echo -e "${RED}[FAIL]${NC}  ${lib}.sh: guard missing"
  )
done

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}Results: ${GREEN}${_PASS} passed${NC}  ${RED}${_FAIL} failed${NC}\n"
[[ $_FAIL -eq 0 ]] && exit 0 || exit 1
