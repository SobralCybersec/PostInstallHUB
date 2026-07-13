#!/usr/bin/env bash
# =============================================================================
# tests/test_arch.sh — Smoke tests for scripts/linux/arch.sh
#
# Run AFTER install.sh on a live Arch box, or inside a Docker container.
#
# Usage:
#   bash tests/test_arch.sh
#   POSTINSTALL_YES=1 bash tests/test_arch.sh   # CI / non-interactive
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
check_dir()  { [[ -d "$1" ]]                && _pass "directory exists: $1"    || _fail "directory missing: $1"; }
check_file() { [[ -f "$1" ]]                && _pass "file exists: $1"          || _fail "file missing: $1"; }
check_link() { [[ -L "$1" ]]                && _pass "symlink exists: $1"       || _fail "symlink missing: $1"; }
check_grep() { grep -qF "$2" "$1" 2>/dev/null && _pass "found in $1: $2"       || _fail "missing in $1: $2"; }
check_svc()  {
  systemctl is-enabled "$1" &>/dev/null \
    && _pass "service enabled: $1" \
    || _fail "service NOT enabled: $1"
}

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}PostInstallHUB — Arch Linux Smoke Tests${NC}\n"

# ── Step 2: Core packages ──────────────────────────────────────────────────
echo -e "${CYAN}── Core packages ──${NC}"
for pkg in git curl wget rsync fd fzf bat tree htop btop ncdu nmap nano; do
  check_cmd "$pkg"
done
check_cmd fastfetch
check_cmd duf
check_cmd nnn

# ── Step 3: yay ───────────────────────────────────────────────────────────
echo -e "\n${CYAN}── yay AUR helper ──${NC}"
check_cmd yay
if command -v yay &>/dev/null; then
  _pass "yay version: $(yay --version 2>/dev/null | head -1)"
fi

# ── Step 4: pacman.conf ───────────────────────────────────────────────────
echo -e "\n${CYAN}── pacman.conf ──${NC}"
check_grep "/etc/pacman.conf" "^Color"
check_grep "/etc/pacman.conf" "^ParallelDownloads"

# ── Step 5: makepkg.conf ──────────────────────────────────────────────────
echo -e "\n${CYAN}── makepkg.conf ──${NC}"
check_grep "/etc/makepkg.conf" "^MAKEFLAGS="
# PKGEXT no compression check
grep -q "PKGEXT='.pkg.tar'" /etc/makepkg.conf 2>/dev/null \
  && _pass "makepkg.conf: PKGEXT no compression" \
  || _fail "makepkg.conf: PKGEXT still using compression"

# ── Step 6: Security ──────────────────────────────────────────────────────
echo -e "\n${CYAN}── Security ──${NC}"
check_grep "/etc/security/faillock.conf" "deny = 10"
check_file "/etc/sudoers.d/10-wheel"
if [[ -f "/etc/sudoers.d/10-wheel" ]]; then
  check_grep "/etc/sudoers.d/10-wheel" "%wheel ALL=(ALL:ALL) ALL"
fi
check_file "/etc/sudoers.d/20-${USER}-nopasswd"

# ── Step 7: Services ──────────────────────────────────────────────────────
echo -e "\n${CYAN}── Services ──${NC}"
for svc in sshd.service plocate-updatedb.timer cronie.service \
           fstrim.timer paccache.timer reflector.timer logrotate.timer; do
  check_svc "$svc"
done
check_grep "/etc/xdg/reflector/reflector.conf" "--protocol https"

# ── Step 9: micro editor ──────────────────────────────────────────────────
echo -e "\n${CYAN}── micro editor ──${NC}"
check_cmd micro
check_file "${HOME}/.config/micro/settings.json"
check_grep "${HOME}/.config/micro/settings.json" '"clipboard": "terminal"'
check_file "${HOME}/.config/micro/bindings.json"
BASHRC="${HOME}/.bashrc"
check_grep "$BASHRC" "export EDITOR=micro"

# ── Step 10: Network / DNSSEC ─────────────────────────────────────────────
echo -e "\n${CYAN}── Network / DNSSEC ──${NC}"
check_grep "/etc/systemd/resolved.conf" "DNSSEC=no"

# ── Step 11: ZSH ──────────────────────────────────────────────────────────
echo -e "\n${CYAN}── ZSH + zimfw ──${NC}"
check_cmd zsh
# Default shell check
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
[[ "$CURRENT_SHELL" == "/usr/bin/zsh" ]] || [[ "$CURRENT_SHELL" == "/bin/zsh" ]] \
  && _pass "Default shell: zsh" \
  || _fail "Default shell is NOT zsh: ${CURRENT_SHELL}"

# .myownrc
check_file "${HOME}/.myownrc"
check_grep "${HOME}/.myownrc" "alias zz='yazi'"
check_grep "${HOME}/.myownrc" "alias pac='sudo pacman'"
check_grep "${HOME}/.myownrc" "bindkey '^S' add_sudo"

# .zshrc sources .myownrc
ZSHRC="${HOME}/.zshrc"
if [[ -f "$ZSHRC" ]]; then
  check_grep "$ZSHRC" "source ~/.myownrc"
else
  _skip ".zshrc not found (zsh not yet started to generate it)"
fi

# .zimrc theme
ZIMRC="${HOME}/.zimrc"
if [[ -f "$ZIMRC" ]]; then
  check_grep "$ZIMRC" "steeef"
else
  _skip ".zimrc not found — zimfw not yet initialised"
fi

# ── Docker (only if ARCH_DOCKER=1 was set) ────────────────────────────────
if [[ "${ARCH_DOCKER:-0}" == "1" ]]; then
  echo -e "\n${CYAN}── Docker ──${NC}"
  check_cmd docker
  check_cmd docker-compose
  check_svc "docker.service"
  groups "$USER" | grep -q docker \
    && _pass "User ${USER} in docker group" \
    || _fail "User ${USER} NOT in docker group"
  check_file "/etc/docker/daemon.json"
  check_grep "/etc/docker/daemon.json" '"max-size"'
fi

# ── LTS kernel (only if ARCH_LTS=1 was set) ───────────────────────────────
if [[ "${ARCH_LTS:-0}" == "1" ]]; then
  echo -e "\n${CYAN}── LTS Kernel ──${NC}"
  [[ -f /boot/vmlinuz-linux-lts ]] \
    && _pass "linux-lts kernel image present" \
    || _fail "linux-lts kernel image NOT found at /boot/vmlinuz-linux-lts"
fi

# ── Script syntax ─────────────────────────────────────────────────────────
echo -e "\n${CYAN}── Script syntax ──${NC}"
for script in \
  "${_ROOT_DIR}/install.sh" \
  "${_ROOT_DIR}/lib/colors.sh" \
  "${_ROOT_DIR}/lib/lock.sh" \
  "${_ROOT_DIR}/lib/backup.sh" \
  "${_ROOT_DIR}/scripts/linux/common.sh" \
  "${_ROOT_DIR}/scripts/linux/arch.sh" \
  "${_ROOT_DIR}/scripts/linux/kali.sh"; do
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
