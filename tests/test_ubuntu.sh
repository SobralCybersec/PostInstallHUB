#!/usr/bin/env bash
# =============================================================================
# tests/test_ubuntu.sh — Smoke tests for scripts/linux/ubuntu.sh
#
# Run AFTER install.sh on a live Ubuntu / Ubuntu-based system.
#
# Usage:
#   bash tests/test_ubuntu.sh
#   UBUNTU_DEBLOAT=1 UBUNTU_SNAP=1 bash tests/test_ubuntu.sh
#   POSTINSTALL_YES=1 bash tests/test_ubuntu.sh
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

check_cmd()     { command -v "$1" &>/dev/null  && _pass "binary on PATH: $1"    || _fail "binary missing: $1"; }
check_pkg()     { dpkg -l "$1" 2>/dev/null | grep -q "^ii" && _pass "pkg installed: $1" || _fail "pkg missing: $1"; }
check_flatpak() { flatpak list 2>/dev/null | grep -q "$1"  && _pass "flatpak: $1" || _fail "flatpak missing: $1"; }
check_snap()    { snap list 2>/dev/null | awk '{print $1}' | grep -qx "$1" && _pass "snap: $1" || _fail "snap missing: $1"; }
check_ppa()     {
  local ppa="$1"
  find /etc/apt/sources.list.d/ \( -name "*.list" -o -name "*.sources" \) \
    -exec grep -l "${ppa}" {} \; 2>/dev/null | grep -q . \
    && _pass "PPA present: ${ppa}" \
    || _fail "PPA missing: ${ppa}"
}
check_flatpak_remote() {
  flatpak remotes 2>/dev/null | grep -q "^$1" \
    && _pass "flatpak remote: $1" \
    || _fail "flatpak remote missing: $1"
}

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}PostInstallHUB — Ubuntu Smoke Tests${NC}\n"

# ── OS family check ───────────────────────────────────────────────────────
echo -e "${CYAN}── OS Detection ──${NC}"
ID="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release 2>/dev/null | tr -d '"' || echo unknown)"
ID_LIKE="$(grep -oP '(?<=^ID_LIKE=)[^\n]+' /etc/os-release 2>/dev/null | tr -d '"' || echo '')"

if [[ "$ID" == "ubuntu" ]] || echo "$ID_LIKE" | grep -qw "ubuntu" || \
   [[ "$ID" == "debian" ]] || echo "$ID_LIKE" | grep -qw "debian"; then
  _pass "OS is Ubuntu/Debian family: ID=${ID} ID_LIKE=${ID_LIKE:-none}"
else
  _fail "OS not Ubuntu family: ID=${ID} ID_LIKE=${ID_LIKE:-none}"
fi

# ── Step 1: System update ─────────────────────────────────────────────────
echo -e "\n${CYAN}── System Update ──${NC}"
# Check apt-get is functional
apt-get --version &>/dev/null && _pass "apt-get available" || _fail "apt-get not found"

# ── Step 3: Flatpak ───────────────────────────────────────────────────────
echo -e "\n${CYAN}── Flatpak + Flathub ──${NC}"
check_cmd flatpak
check_flatpak_remote flathub

# ── Step 5: Timeshift ─────────────────────────────────────────────────────
echo -e "\n${CYAN}── Timeshift ──${NC}"
check_cmd timeshift

# ── Step 6: PPAs ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}── PPAs ──${NC}"
check_ppa "zhangsongcui3371"
check_ppa "danielrichter2007"
check_ppa "papirus"
check_ppa "git-core"
check_ppa "sebastian-stenzel"
check_ppa "phoerious"

# ── Step 6: apt packages ──────────────────────────────────────────────────
echo -e "\n${CYAN}── apt packages ──${NC}"
for pkg in curl wget git synaptic adb blueman fuse3 \
           fastfetch grub-customizer papirus-icon-theme \
           qbittorrent cryptomator keepassxc timeshift; do
  check_pkg "$pkg"
done

# ── Step 7: Flatpak apps ──────────────────────────────────────────────────
echo -e "\n${CYAN}── Flatpak apps ──${NC}"
check_flatpak "org.gnome.baobab"
check_flatpak "org.torproject.torbrowser-launcher"
check_flatpak "org.gimp.GIMP"
check_flatpak "com.obsproject.Studio"

# ── Step 2: Debloat (opt-in) ──────────────────────────────────────────────
if [[ "${UBUNTU_DEBLOAT:-0}" == "1" ]]; then
  echo -e "\n${CYAN}── Debloat (UBUNTU_DEBLOAT=1) ──${NC}"
  for pkg in gnome-mahjongg gnome-mines aisleriot gnome-sudoku \
             xterm parole rhythmbox hexchat thunderbird; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
      _fail "Should be removed but still installed: ${pkg}"
    else
      _pass "Correctly absent: ${pkg}"
    fi
  done
else
  _skip "Debloat check skipped (UBUNTU_DEBLOAT not set)"
fi

# ── Snap (opt-in) ─────────────────────────────────────────────────────────
if [[ "${UBUNTU_SNAP:-0}" == "1" ]]; then
  echo -e "\n${CYAN}── Snap (UBUNTU_SNAP=1) ──${NC}"
  check_cmd snap
  check_snap htop
  check_snap flameshot
  check_snap vlc
else
  _skip "Snap checks skipped (UBUNTU_SNAP not set)"
fi

# ── NVIDIA (opt-in) ───────────────────────────────────────────────────────
if [[ "${UBUNTU_NVIDIA:-0}" == "1" ]]; then
  echo -e "\n${CYAN}── NVIDIA (UBUNTU_NVIDIA=1) ──${NC}"
  check_cmd ubuntu-drivers
  if lspci 2>/dev/null | grep -qi nvidia; then
    # Check driver loaded
    if lsmod 2>/dev/null | grep -q nvidia; then
      _pass "nvidia kernel module loaded"
    else
      _fail "nvidia module NOT loaded — reboot required or driver failed"
    fi
  else
    _skip "No NVIDIA GPU detected — skipping module check"
  fi
else
  _skip "NVIDIA checks skipped (UBUNTU_NVIDIA not set)"
fi

# ── Script syntax ─────────────────────────────────────────────────────────
echo -e "\n${CYAN}── Script syntax ──${NC}"
for script in \
  "${_ROOT_DIR}/install.sh" \
  "${_ROOT_DIR}/lib/colors.sh" \
  "${_ROOT_DIR}/lib/lock.sh" \
  "${_ROOT_DIR}/lib/backup.sh" \
  "${_ROOT_DIR}/scripts/linux/common.sh" \
  "${_ROOT_DIR}/scripts/linux/ubuntu.sh" \
  "${_ROOT_DIR}/scripts/linux/kali.sh" \
  "${_ROOT_DIR}/scripts/linux/arch.sh" \
  "${_ROOT_DIR}/scripts/linux/fedora.sh"; do
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
      || echo -e "${RED}[FAIL]${NC} ${lib}.sh: guard missing"
  )
done

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}Results: ${GREEN}${_PASS} passed${NC}  ${RED}${_FAIL} failed${NC}\n"
[[ $_FAIL -eq 0 ]] && exit 0 || exit 1
