#!/usr/bin/env bash
# =============================================================================
# tests/test_debian.sh — Smoke tests for scripts/linux/debian.sh
#
# Run AFTER install.sh on a live Debian 13 Trixie box or Docker container.
#
# Usage:
#   bash tests/test_debian.sh
#   POSTINSTALL_YES=1 bash tests/test_debian.sh   # CI / non-interactive
#
# Exit code: 0 = all pass · 1 = one or more failures
# =============================================================================
set -uo pipefail

_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT_DIR="$(cd "${_TEST_DIR}/.." && pwd)"

source "${_ROOT_DIR}/lib/colors.sh"

# ---------------------------------------------------------------------------
# Test counters + helpers
# ---------------------------------------------------------------------------
_PASS=0
_FAIL=0

_pass() { echo -e "${GREEN}[PASS]${NC} $*"; (( _PASS++ )) || true; }
_fail() { echo -e "${RED}[FAIL]${NC} $*";  (( _FAIL++ )) || true; }
_skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; }

check_cmd()  { command -v "$1" &>/dev/null  && _pass "binary on PATH: $1"         || _fail "binary missing: $1"; }
check_pkg()  { dpkg -l "$1" 2>/dev/null | grep -q "^ii"  && _pass "deb installed: $1"  || _fail "deb missing:    $1"; }
check_file() { [[ -f "$1" ]]  && _pass "file exists: $1"   || _fail "file missing: $1"; }
check_grep() { grep -qF "$2" "$1" 2>/dev/null && _pass "found '$2' in $1" || _fail "missing '$2' in $1"; }

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}PostInstallHUB — Debian 13 Trixie Smoke Tests${NC}\n"

# ── OS guard ──────────────────────────────────────────────────────────────
echo -e "${CYAN}── OS check ──${NC}"
if [[ -f /etc/os-release ]]; then
  _ID="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release | tr -d '"')"
  if [[ "$_ID" == "debian" ]]; then
    _pass "OS is Debian (ID=${_ID})"
  else
    _skip "OS is '${_ID}' — not Debian; some checks may fail"
  fi
else
  _skip "No /etc/os-release found"
fi

# ── Step 1: apt packages ──────────────────────────────────────────────────
echo -e "\n${CYAN}── apt packages ──${NC}"
for pkg in ufw flatpak vim btop fish tmux aria2 chromium; do
  check_pkg "$pkg"
done

# ── Step 2: UFW ───────────────────────────────────────────────────────────
echo -e "\n${CYAN}── UFW ──${NC}"
check_cmd ufw
if command -v ufw &>/dev/null; then
  sudo ufw status 2>/dev/null | grep -q "Status: active" \
    && _pass "UFW is active" \
    || _fail "UFW is NOT active"
  # KDEConnect ports
  sudo ufw status 2>/dev/null | grep -q "1714" \
    && _pass "UFW: KDEConnect port range present" \
    || _fail "UFW: KDEConnect port range missing (1714:1764)"
fi

# ── Step 3: DebMultimedia ─────────────────────────────────────────────────
echo -e "\n${CYAN}── DebMultimedia Repository ──${NC}"
check_file "/etc/apt/sources.list.d/dmo.sources"
check_pkg  "deb-multimedia-keyring"

# ── Step 4: NVIDIA (opt-in) ───────────────────────────────────────────────
echo -e "\n${CYAN}── NVIDIA (opt-in) ──${NC}"
if [[ "${DEBIAN_NVIDIA:-0}" == "1" ]] || [[ "${DEBIAN_NVIDIA_CUDA:-0}" == "1" ]]; then
  check_pkg "cuda-keyring"
  check_file "/etc/apt/preferences.d/nvidia-repo"
  if [[ "${DEBIAN_NVIDIA_CUDA:-0}" == "1" ]]; then
    check_pkg "cuda-toolkit"
  else
    check_pkg "nvidia-open"
  fi
else
  _skip "DEBIAN_NVIDIA / DEBIAN_NVIDIA_CUDA not set — skipping NVIDIA checks"
fi

# ── Step 5: Flatpak ───────────────────────────────────────────────────────
echo -e "\n${CYAN}── Flatpak ──${NC}"
check_cmd flatpak
if command -v flatpak &>/dev/null; then
  flatpak remotes 2>/dev/null | grep -q "flathub" \
    && _pass "Flathub remote present" \
    || _fail "Flathub remote missing"
fi

# ── Step 6: Productivity Flatpak apps ────────────────────────────────────
echo -e "\n${CYAN}── Flatpak apps (productivity) ──${NC}"
if command -v flatpak &>/dev/null; then
  for app in \
    org.gimp.GIMP \
    org.inkscape.Inkscape \
    org.shotcut.Shotcut \
    com.obsproject.Studio \
    com.google.Chrome \
    md.obsidian.Obsidian \
    com.github.tchx84.Flatseal; do
    flatpak list 2>/dev/null | grep -q "$app" \
      && _pass "flatpak installed: ${app}" \
      || _fail "flatpak missing:   ${app}"
  done
else
  _skip "flatpak not available — skipping Flatpak app checks"
fi

# ── Step 7: DaVinci Resolve deps ─────────────────────────────────────────
echo -e "\n${CYAN}── DaVinci Resolve runtime deps ──${NC}"
for pkg in libxcb-composite0 libxcb-cursor0 libxcb-xinerama0 libxcb-xinput0 libfuse2; do
  check_pkg "$pkg"
done

# ── Step 8: Gaming (opt-in) ───────────────────────────────────────────────
echo -e "\n${CYAN}── Gaming Flatpak apps (opt-in) ──${NC}"
if [[ "${DEBIAN_GAMING:-0}" == "1" ]] && command -v flatpak &>/dev/null; then
  for app in \
    com.valvesoftware.Steam \
    com.heroicgameslauncher.hgl \
    io.github.radiolamp.mangojuice; do
    flatpak list 2>/dev/null | grep -q "$app" \
      && _pass "flatpak installed: ${app}" \
      || _fail "flatpak missing:   ${app}"
  done
else
  _skip "DEBIAN_GAMING not set (or flatpak unavailable) — skipping gaming checks"
fi

# ── Step 9: Debloat (opt-in) ──────────────────────────────────────────────
echo -e "\n${CYAN}── Debloat (opt-in) ──${NC}"
if [[ "${DEBIAN_DEBLOAT:-0}" == "1" ]]; then
  for pkg in libreoffice-common akregator kmail juk dragonplayer; do
    dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" \
      && _fail "debloat pkg still installed: ${pkg}" \
      || _pass "debloat pkg removed: ${pkg}"
  done
else
  _skip "DEBIAN_DEBLOAT not set — skipping debloat checks"
fi

# ── Step 10: ZSWAP (opt-in) ───────────────────────────────────────────────
echo -e "\n${CYAN}── ZSWAP (opt-in) ──${NC}"
if [[ "${DEBIAN_ZSWAP:-0}" == "1" ]]; then
  if [[ -f /sys/module/zswap/parameters/enabled ]]; then
    val="$(cat /sys/module/zswap/parameters/enabled 2>/dev/null)"
    [[ "$val" == "Y" ]] \
      && _pass "ZSWAP is active (kernel reports Y)" \
      || _fail "ZSWAP not active (kernel reports: ${val})"
  else
    _skip "ZSWAP sysfs path not found — may need reboot"
  fi
  # Check that at least one boot entry has the parameter
  entries="$(grep -rl "zswap.enabled=1" /boot/efi/loader/entries/ 2>/dev/null || true)"
  [[ -n "$entries" ]] \
    && _pass "zswap.enabled=1 found in boot entry" \
    || _fail "zswap.enabled=1 missing from all boot entries"
else
  _skip "DEBIAN_ZSWAP not set — skipping ZSWAP checks"
fi

# ── lib/ source guard sanity ──────────────────────────────────────────────
echo -e "\n${CYAN}── lib/ double-source guards ──${NC}"
(
  # shellcheck source=/dev/null
  source "${_ROOT_DIR}/lib/colors.sh"
  source "${_ROOT_DIR}/lib/colors.sh"
  [[ -n "${_COLORS_LOADED:-}" ]] \
    && echo -e "${GREEN}[PASS]${NC} colors.sh: double-source guard works" \
    || echo -e "${RED}[FAIL]${NC}  colors.sh: guard variable missing"
)
(
  source "${_ROOT_DIR}/lib/lock.sh"
  source "${_ROOT_DIR}/lib/lock.sh"
  [[ -n "${_LOCK_LOADED:-}" ]] \
    && echo -e "${GREEN}[PASS]${NC} lock.sh: double-source guard works" \
    || echo -e "${RED}[FAIL]${NC}  lock.sh: guard variable missing"
)

# ── Script syntax ─────────────────────────────────────────────────────────
echo -e "\n${CYAN}── Script syntax ──${NC}"
for script in \
  "${_ROOT_DIR}/install.sh" \
  "${_ROOT_DIR}/lib/colors.sh" \
  "${_ROOT_DIR}/lib/lock.sh" \
  "${_ROOT_DIR}/lib/backup.sh" \
  "${_ROOT_DIR}/scripts/linux/common.sh" \
  "${_ROOT_DIR}/scripts/linux/debian.sh"; do
  bash -n "$script" 2>/dev/null \
    && _pass "syntax OK: $(basename "$script")" \
    || _fail "syntax ERR: $(basename "$script")"
done

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}Results: ${GREEN}${_PASS} passed${NC}  ${RED}${_FAIL} failed${NC}\n"
[[ $_FAIL -eq 0 ]] && exit 0 || exit 1
