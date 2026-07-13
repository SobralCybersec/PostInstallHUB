#!/usr/bin/env bash
# =============================================================================
# tests/test_endeavour.sh — Smoke tests for scripts/linux/endeavour.sh
#
# Run AFTER install.sh on a live EndeavourOS / CachyOS / Arch-family box.
#
# Usage:
#   bash tests/test_endeavour.sh
#   POSTINSTALL_YES=1 bash tests/test_endeavour.sh
#   ENDEAVOUR_GAMING=1 ENDEAVOUR_PLYMOUTH=1 bash tests/test_endeavour.sh
#   ENDEAVOUR_WAYDROID=1 ENDEAVOUR_FISH=1 bash tests/test_endeavour.sh
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
_fail() { echo -e "${RED}[FAIL]${NC} $*";   (( _FAIL++ )) || true; }
_skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; }

check_cmd()  { command -v "$1" &>/dev/null \
                 && _pass "binary on PATH: $1" \
                 || _fail "binary missing: $1"; }
check_file() { [[ -f "$1" ]] \
                 && _pass "file exists: $1" \
                 || _fail "file missing: $1"; }
check_dir()  { [[ -d "$1" ]] \
                 && _pass "directory exists: $1" \
                 || _fail "directory missing: $1"; }
check_grep() { grep -qF "$2" "$1" 2>/dev/null \
                 && _pass "found in $1: $2" \
                 || _fail "missing in $1: $2"; }
check_svc()  {
  systemctl is-enabled "$1" &>/dev/null \
    && _pass "service enabled: $1" \
    || _fail "service NOT enabled: $1"
}
check_pacman() {
  pacman -Qi "$1" &>/dev/null \
    && _pass "pacman pkg installed: $1" \
    || _fail "pacman pkg missing: $1"
}

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}PostInstallHUB — EndeavourOS / CachyOS Smoke Tests${NC}\n"

# ── OS Family ────────────────────────────────────────────────────────────────
echo -e "${CYAN}── OS Family (Arch-based) ──${NC}"
_os_id="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release 2>/dev/null | tr -d '"' || echo unknown)"
case "$_os_id" in
  arch|endeavouros|cachyos|manjaro|garuda)
    _pass "OS family: Arch-based (ID=${_os_id})"
    ;;
  *)
    _fail "OS family: not Arch-based (ID=${_os_id})"
    ;;
esac

# ── Step 3: yay ──────────────────────────────────────────────────────────────
echo -e "\n${CYAN}── yay AUR Helper ──${NC}"
check_cmd yay
if command -v yay &>/dev/null; then
  _pass "yay version: $(yay --version 2>/dev/null | head -1)"
fi

# ── Step 4: Chaotic-AUR ──────────────────────────────────────────────────────
echo -e "\n${CYAN}── Chaotic-AUR Repository ──${NC}"
check_grep "/etc/pacman.conf" "[chaotic-aur]"
check_grep "/etc/pacman.conf" "chaotic-mirrorlist"

# ── Step 5: UFW ──────────────────────────────────────────────────────────────
echo -e "\n${CYAN}── UFW Firewall ──${NC}"
check_cmd ufw
check_svc ufw.service

if command -v ufw &>/dev/null; then
  _ufw_status="$(sudo ufw status 2>/dev/null || true)"

  echo "$_ufw_status" | grep -q "Status: active" \
    && _pass "UFW status: active" \
    || _fail "UFW status: NOT active"

  # Check each required rule
  _ufw_verbose="$(sudo ufw status verbose 2>/dev/null || true)"

  echo "$_ufw_verbose" | grep -qiE "22/tcp|ssh" \
    && _pass "UFW rule present: SSH" \
    || _fail "UFW rule missing: SSH"

  echo "$_ufw_verbose" | grep -qF "1714:1764/tcp" \
    && _pass "UFW rule present: KDE Connect TCP (1714:1764)" \
    || _fail "UFW rule missing: KDE Connect TCP (1714:1764)"

  echo "$_ufw_verbose" | grep -qF "1714:1764/udp" \
    && _pass "UFW rule present: KDE Connect UDP (1714:1764)" \
    || _fail "UFW rule missing: KDE Connect UDP (1714:1764)"

  echo "$_ufw_verbose" | grep -qF "42000:42001/tcp" \
    && _pass "UFW rule present: Warpinator TCP (42000:42001)" \
    || _fail "UFW rule missing: Warpinator TCP (42000:42001)"

  echo "$_ufw_verbose" | grep -qF "42000:42001/udp" \
    && _pass "UFW rule present: Warpinator UDP (42000:42001)" \
    || _fail "UFW rule missing: Warpinator UDP (42000:42001)"
else
  _fail "ufw not on PATH — cannot check rules"
fi

# ── Step 6: ZSH + oh-my-zsh ──────────────────────────────────────────────────
echo -e "\n${CYAN}── ZSH + oh-my-zsh ──${NC}"
check_cmd zsh
check_dir "${HOME}/.oh-my-zsh"

# oh-my-zsh marker file
[[ -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]] \
  && _pass "oh-my-zsh: oh-my-zsh.sh present" \
  || _fail "oh-my-zsh: oh-my-zsh.sh missing"

# Plugins directory
_omz_custom="${HOME}/.oh-my-zsh/custom"
[[ -d "$_omz_custom" ]] \
  && _pass "oh-my-zsh: custom dir exists (ZSH_CUSTOM)" \
  || _fail "oh-my-zsh: custom dir missing"

# Plugin: zsh-autosuggestions (either AUR pkg or cloned)
if pacman -Qi zsh-autosuggestions &>/dev/null \
   || [[ -d "${_omz_custom}/plugins/zsh-autosuggestions" ]]; then
  _pass "zsh-autosuggestions: installed"
else
  _fail "zsh-autosuggestions: neither AUR pkg nor custom plugin dir found"
fi

# Plugin: zsh-syntax-highlighting (either AUR pkg or cloned)
if pacman -Qi zsh-syntax-highlighting &>/dev/null \
   || [[ -d "${_omz_custom}/plugins/zsh-syntax-highlighting" ]]; then
  _pass "zsh-syntax-highlighting: installed"
else
  _fail "zsh-syntax-highlighting: neither AUR pkg nor custom plugin dir found"
fi

# .zshrc exists (ZSH_CONFIG_FILE)
check_file "${HOME}/.zshrc"

# ── Step 8: Essential packages ───────────────────────────────────────────────
echo -e "\n${CYAN}── Essential Packages (_step_packages) ──${NC}"
for _pkg in btop htop fastfetch git vim neovim tmux curl wget unzip p7zip \
            ark dolphin kate konsole yt-dlp aria2 flameshot keepassxc; do
  check_pacman "$_pkg"
done

# Binary spot-checks for key tools
for _bin in btop htop git vim nvim tmux curl wget unzip flameshot; do
  check_cmd "$_bin"
done

# ── Step 9: Flatpak + Flathub ────────────────────────────────────────────────
echo -e "\n${CYAN}── Flatpak + Flathub ──${NC}"
check_cmd flatpak

if command -v flatpak &>/dev/null; then
  flatpak remotes 2>/dev/null | grep -q "^flathub" \
    && _pass "Flatpak remote: flathub configured" \
    || _fail "Flatpak remote: flathub NOT configured"
else
  _fail "flatpak not on PATH — cannot check remotes"
fi

# ── Plymouth (optional — ENDEAVOUR_PLYMOUTH=1) ───────────────────────────────
if [[ "${ENDEAVOUR_PLYMOUTH:-0}" == "1" ]]; then
  echo -e "\n${CYAN}── Plymouth (ENDEAVOUR_PLYMOUTH=1) ──${NC}"
  check_pacman plymouth

  check_grep "/etc/mkinitcpio.conf" "plymouth"

  if [[ -f "/etc/default/grub" ]]; then
    check_grep "/etc/default/grub" "splash"
  else
    _skip "GRUB config not found — may use systemd-boot (manual check required)"
  fi
else
  _skip "ENDEAVOUR_PLYMOUTH not set — skipping Plymouth checks"
fi

# ── Waydroid (optional — ENDEAVOUR_WAYDROID=1) ───────────────────────────────
if [[ "${ENDEAVOUR_WAYDROID:-0}" == "1" ]]; then
  echo -e "\n${CYAN}── Waydroid (ENDEAVOUR_WAYDROID=1) ──${NC}"
  check_cmd waydroid
  check_svc waydroid-container.service

  [[ -f "/var/lib/waydroid/images/system.img" ]] \
    && _pass "Waydroid: system.img present (fully initialised)" \
    || _skip "Waydroid: system.img not found — run 'sudo waydroid init' to initialise"
else
  _skip "ENDEAVOUR_WAYDROID not set — skipping Waydroid checks"
fi

# ── Gaming (optional — ENDEAVOUR_GAMING=1) ────────────────────────────────────
if [[ "${ENDEAVOUR_GAMING:-0}" == "1" ]]; then
  echo -e "\n${CYAN}── Gaming (ENDEAVOUR_GAMING=1) ──${NC}"
  for _pkg in steam lutris gamemode lib32-gamemode mangohud; do
    check_pacman "$_pkg"
  done
  check_cmd steam 2>/dev/null || _fail "steam binary not on PATH"
  check_cmd lutris

  # Check GPU-specific drivers
  _gpu="unknown"
  command -v lspci &>/dev/null && {
    lspci 2>/dev/null | grep -qiE 'amd|radeon'              && _gpu="amd"
    lspci 2>/dev/null | grep -qi nvidia                      && _gpu="nvidia"
    lspci 2>/dev/null | grep -qiE 'intel.*graphics|intel.*uhd' && _gpu="intel"
  }
  echo -e "  ${DIM}GPU detected: ${_gpu}${NC}"

  case "$_gpu" in
    amd)
      check_pacman lib32-mesa
      check_pacman vulkan-radeon
      check_pacman lib32-vulkan-radeon
      ;;
    nvidia)
      check_pacman nvidia-utils
      check_pacman lib32-nvidia-utils
      ;;
    intel)
      check_pacman vulkan-intel
      ;;
    *)
      _skip "Unknown GPU — skipping GPU driver checks"
      ;;
  esac
else
  _skip "ENDEAVOUR_GAMING not set — skipping gaming checks"
fi

# ── Script syntax — all .sh files in repo ────────────────────────────────────
echo -e "\n${CYAN}── Script syntax (bash -n) ──${NC}"
while IFS= read -r -d '' _script; do
  bash -n "$_script" 2>/dev/null \
    && _pass "syntax OK: ${_script#"${_ROOT_DIR}/"}" \
    || _fail "syntax ERR: ${_script#"${_ROOT_DIR}/"}"
done < <(find "${_ROOT_DIR}" -name "*.sh" -not -path "*/\.*" -print0 | sort -z)

# ── lib/ double-source guards ────────────────────────────────────────────────
echo -e "\n${CYAN}── lib/ double-source guards ──${NC}"
for _lib in colors lock backup; do
  (
    # shellcheck source=/dev/null
    source "${_ROOT_DIR}/lib/${_lib}.sh"
    # shellcheck source=/dev/null
    source "${_ROOT_DIR}/lib/${_lib}.sh"
    _var="_$(echo "$_lib" | tr '[:lower:]' '[:upper:]')_LOADED"
    [[ -n "${!_var:-}" ]] \
      && echo -e "${GREEN}[PASS]${NC} ${_lib}.sh: double-source guard works" \
      || echo -e "${RED}[FAIL]${NC}  ${_lib}.sh: guard variable missing"
  )
done

# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}Results: ${GREEN}${_PASS} passed${NC}  ${RED}${_FAIL} failed${NC}"
echo ""
[[ $_FAIL -eq 0 ]] && exit 0 || exit 1
