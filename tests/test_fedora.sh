#!/usr/bin/env bash
# =============================================================================
# tests/test_fedora.sh — Smoke tests for scripts/linux/fedora.sh
#
# Run AFTER install.sh on a live Fedora box.
#
# Usage:
#   bash tests/test_fedora.sh
#   POSTINSTALL_YES=1 bash tests/test_fedora.sh
#   FEDORA_NVIDIA=1 FEDORA_DNS=1 bash tests/test_fedora.sh
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

check_cmd()  { command -v "$1" &>/dev/null  && _pass "binary on PATH: $1"     || _fail "binary missing: $1"; }
check_file() { [[ -f "$1" ]]                && _pass "file exists: $1"          || _fail "file missing: $1"; }
check_rpm()  { rpm -q "$1" &>/dev/null      && _pass "rpm installed: $1"        || _fail "rpm missing: $1"; }
check_svc()  {
  systemctl is-enabled "$1" &>/dev/null \
    && _pass "service enabled: $1" \
    || _fail "service NOT enabled: $1"
}
check_grep() { grep -qF "$2" "$1" 2>/dev/null && _pass "found in $1: $2"       || _fail "missing in $1: $2"; }
check_svc_disabled() {
  ! systemctl is-enabled "$1" &>/dev/null \
    && _pass "service disabled: $1" \
    || _fail "service NOT disabled (should be): $1"
}

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}PostInstallHUB — Fedora Smoke Tests${NC}\n"

# ── Step 1: RPM Fusion ────────────────────────────────────────────────────
echo -e "${CYAN}── RPM Fusion ──${NC}"
check_rpm rpmfusion-free-release
check_rpm rpmfusion-nonfree-release

# ── Step 4: Flatpak ───────────────────────────────────────────────────────
echo -e "\n${CYAN}── Flatpak ──${NC}"
check_cmd flatpak
flatpak remotes 2>/dev/null | grep -q "^flathub" \
  && _pass "Flatpak remote: flathub" \
  || _fail "Flatpak remote: flathub NOT configured"

# ── Step 5: AppImage ──────────────────────────────────────────────────────
echo -e "\n${CYAN}── AppImage ──${NC}"
check_rpm fuse-libs

# ── Step 6: Media codecs ──────────────────────────────────────────────────
echo -e "\n${CYAN}── Media codecs ──${NC}"
# Check ffmpeg (full, not free)
if rpm -q ffmpeg &>/dev/null && ! rpm -q ffmpeg-free &>/dev/null; then
  _pass "ffmpeg (full RPM Fusion build) installed; ffmpeg-free removed"
elif rpm -q ffmpeg-free &>/dev/null; then
  _fail "ffmpeg-free still present — swap to full ffmpeg not done"
else
  _fail "ffmpeg not installed at all"
fi

# ── Step 7: HW Video ──────────────────────────────────────────────────────
echo -e "\n${CYAN}── HW Video Acceleration ──${NC}"
check_rpm ffmpeg-libs
check_rpm libva
check_rpm libva-utils
check_rpm openh264
check_rpm gstreamer1-plugin-openh264

# GPU-specific checks
GPU="unknown"
command -v lspci &>/dev/null && {
  lspci 2>/dev/null | grep -qi nvidia  && GPU="nvidia"
  lspci 2>/dev/null | grep -qiE 'amd|radeon' && GPU="amd"
  lspci 2>/dev/null | grep -qiE 'intel.*graphics|intel.*uhd' && GPU="intel"
}
log_info() { echo -e "${BLUE}[INFO]${NC}    $*"; }
log_info "GPU: ${GPU}"

case "$GPU" in
  intel)
    rpm -q intel-media-driver &>/dev/null \
      && _pass "Intel: intel-media-driver installed" \
      || _fail "Intel: intel-media-driver missing"
    check_rpm libva-intel-driver
    ;;
  amd)
    check_rpm mesa-va-drivers-freeworld
    ;;
  nvidia)
    _skip "NVIDIA VA-API handled by NVIDIA driver — check FEDORA_NVIDIA=1 section"
    ;;
  *)
    _skip "Unknown GPU — skipping GPU-specific VA-API check"
    ;;
esac

# ── Step 9: Optimizations ─────────────────────────────────────────────────
echo -e "\n${CYAN}── Optimizations ──${NC}"
check_svc_disabled "NetworkManager-wait-online.service"

# GNOME Software autostart
AUTOSTART_FILE="${HOME}/.config/autostart/org.gnome.Software.desktop"
if command -v gnome-shell &>/dev/null; then
  if [[ -f "$AUTOSTART_FILE" ]]; then
    check_grep "$AUTOSTART_FILE" "X-GNOME-Autostart-enabled=false"
  else
    _fail "GNOME Software autostart file not found: ${AUTOSTART_FILE}"
  fi
else
  _skip "GNOME not detected — skipping GNOME Software autostart check"
fi

# ── Step 11: UTC time ─────────────────────────────────────────────────────
echo -e "\n${CYAN}── UTC Hardware Clock ──${NC}"
local_rtc="$(timedatectl show --property=LocalRTC --value 2>/dev/null || echo unknown)"
[[ "$local_rtc" == "no" ]] \
  && _pass "Hardware clock: UTC (LocalRTC=no)" \
  || _fail "Hardware clock not UTC (LocalRTC=${local_rtc})"

# ── Step 12: Essential packages ───────────────────────────────────────────
echo -e "\n${CYAN}── Essential packages ──${NC}"
for pkg in unzip wget curl git htop; do
  check_cmd "$pkg"
done
check_rpm p7zip
check_rpm unrar

# ── NVIDIA (optional) ─────────────────────────────────────────────────────
if [[ "${FEDORA_NVIDIA:-0}" == "1" ]]; then
  echo -e "\n${CYAN}── NVIDIA (FEDORA_NVIDIA=1) ──${NC}"
  if [[ "$GPU" == "nvidia" ]]; then
    check_rpm akmod-nvidia
    # Check if module is built
    if modinfo -F version nvidia &>/dev/null; then
      _pass "NVIDIA kmod built: $(modinfo -F version nvidia)"
    else
      _fail "NVIDIA kmod not yet built — wait 5 min and check: modinfo -F version nvidia"
    fi
    if [[ "${FEDORA_CUDA:-0}" == "1" ]]; then
      check_rpm xorg-x11-drv-nvidia-cuda
    fi
  else
    _skip "FEDORA_NVIDIA=1 but no NVIDIA GPU detected — NVIDIA tests skipped"
  fi
fi

# ── DNS over TLS (optional) ───────────────────────────────────────────────
if [[ "${FEDORA_DNS:-0}" == "1" ]]; then
  echo -e "\n${CYAN}── DNS over TLS (FEDORA_DNS=1) ──${NC}"
  DNS_CONF="/etc/systemd/resolved.conf.d/99-dns-over-tls.conf"
  check_file "$DNS_CONF"
  if [[ -f "$DNS_CONF" ]]; then
    check_grep "$DNS_CONF" "DNSOverTLS=yes"
    check_grep "$DNS_CONF" "1.1.1.2"
  fi
fi

# ── Script syntax ─────────────────────────────────────────────────────────
echo -e "\n${CYAN}── Script syntax ──${NC}"
for script in \
  "${_ROOT_DIR}/install.sh" \
  "${_ROOT_DIR}/lib/colors.sh" \
  "${_ROOT_DIR}/lib/lock.sh" \
  "${_ROOT_DIR}/lib/backup.sh" \
  "${_ROOT_DIR}/scripts/linux/common.sh" \
  "${_ROOT_DIR}/scripts/linux/kali.sh" \
  "${_ROOT_DIR}/scripts/linux/arch.sh" \
  "${_ROOT_DIR}/scripts/linux/fedora.sh"; do
  bash -n "$script" 2>/dev/null \
    && _pass "syntax OK: $(basename "$script")" \
    || _fail "syntax ERR: $(basename "$script")"
done

# ── lib/ source guards ────────────────────────────────────────────────────
echo -e "\n${CYAN}── lib/ double-source guards ──${NC}"
for lib in colors lock backup; do
  (
    source "${_ROOT_DIR}/lib/${lib}.sh"
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
