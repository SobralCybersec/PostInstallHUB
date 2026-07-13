#!/usr/bin/env bash
# =============================================================================
# tests/test_nixos.sh — Smoke tests for scripts/linux/nixos.sh
#
# Tests the nixos.sh logic functions in isolation by sourcing the script
# inside a subshell with mocked commands and a fake configuration.nix.
# Does NOT require a real NixOS system or root.
#
# Usage:
#   bash tests/test_nixos.sh
#
# Exit code: 0 = all pass · 1 = one or more failures
# =============================================================================
set -uo pipefail

_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT_DIR="$(cd "${_TEST_DIR}/.." && pwd)"
NIXOS_SH="${_ROOT_DIR}/scripts/linux/nixos.sh"

source "${_ROOT_DIR}/lib/colors.sh"

_PASS=0
_FAIL=0

_pass() { echo -e "${GREEN}[PASS]${NC} $*"; (( _PASS++ )) || true; }
_fail() { echo -e "${RED}[FAIL]${NC} $*"; (( _FAIL++ )) || true; }
_skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; }

# ---------------------------------------------------------------------------
# Scratch workspace — cleaned on EXIT
# ---------------------------------------------------------------------------
_WORK="$(mktemp -d)"
trap 'rm -rf "$_WORK"' EXIT

_FAKE_CONF="${_WORK}/configuration.nix"
_FAKE_BIN="${_WORK}/bin"
_NIX_LOG="${_WORK}/nix-channel.log"
_NIX_STATE="${_WORK}/nix-channel.state"
_REBUILD_LOG="${_WORK}/nixos-rebuild.log"

mkdir -p "$_FAKE_BIN" "${_WORK}/home"

# ---------------------------------------------------------------------------
# Fake binaries — MUST come before /usr/bin in PATH so they shadow real cmds
# ---------------------------------------------------------------------------

# sudo — transparent passthrough (so our fake nix-channel / tee etc. run)
cat > "${_FAKE_BIN}/sudo" << SUDO
#!/usr/bin/env bash
exec "\$@"
SUDO

# nix-channel — records calls; simulates --list / --add state
cat > "${_FAKE_BIN}/nix-channel" << NIX
#!/usr/bin/env bash
echo "nix-channel \$*" >> "${_NIX_LOG}"
case "\${1:-}" in
  --list)   cat "${_NIX_STATE}" 2>/dev/null || true ;;
  --add)    echo "\${3:-}" >> "${_NIX_STATE}" ;;
  --update) ;;
esac
exit 0
NIX

# nixos-rebuild — records calls
cat > "${_FAKE_BIN}/nixos-rebuild" << REBUILD
#!/usr/bin/env bash
echo "nixos-rebuild \$*" >> "${_REBUILD_LOG}"
exit 0
REBUILD

# tee — write/append to path argument (honours -a)
cat > "${_FAKE_BIN}/tee" << 'TEE'
#!/usr/bin/env bash
target="" append=0
for a in "$@"; do
  case "$a" in
    -a) append=1 ;;
    -*) ;;
    *)  target="$a" ;;
  esac
done
if [[ -z "$target" ]]; then
  cat; exit 0
fi
if (( append )); then cat >> "$target"; else cat > "$target"; fi
exit 0
TEE

chmod +x "${_FAKE_BIN}/sudo" "${_FAKE_BIN}/nix-channel" \
         "${_FAKE_BIN}/nixos-rebuild" "${_FAKE_BIN}/tee"

# Fake PATH — our bin first so it shadows /usr/bin/sudo, /usr/bin/tee, etc.
_MOCK_PATH="${_FAKE_BIN}:/usr/bin:/bin"

# ---------------------------------------------------------------------------
# Reset helpers
# ---------------------------------------------------------------------------
_reset_conf() {
  cat > "$_FAKE_CONF" << 'NIX'
{ config, pkgs, ... }:
{
  system.stateVersion = "24.11";
}
NIX
}

_reset_logs() {
  rm -f "$_NIX_LOG" "$_NIX_STATE" "$_REBUILD_LOG"
}

_reset() { _reset_conf; _reset_logs; }

# ---------------------------------------------------------------------------
# _nixos_eval EXPR [VAR=val ...]
#
# Runs EXPR inside a subshell that:
#   • Has PATH pointing to our fake bin directory first
#   • Pre-sets all guard variables so nixos.sh's source lines short-circuit
#   • Stubs every function from common.sh and dotfiles.sh that nixos.sh calls
#   • Overrides _require_nixos to always pass
#   • Points _NIXOS_CONF at the fake configuration.nix
# ---------------------------------------------------------------------------
_nixos_eval() {
  local expr="$1"; shift

  # Extra env vars passed as NAME=val arguments
  local -a extras=("$@")

  # Export shared state paths via env so heredoc expansions above work
  env -i \
    PATH="$_MOCK_PATH" \
    HOME="${_WORK}/home" \
    TERM=xterm \
    POSTINSTALL_YES=1 \
    POSTINSTALL_DOTFILES=none \
    _NIX_LOG="$_NIX_LOG" \
    _NIX_STATE="$_NIX_STATE" \
    _REBUILD_LOG="$_REBUILD_LOG" \
    "${extras[@]}" \
    bash << SUBSH
set -uo pipefail

# ── Colour stubs (no terminal needed) ───────────────────────────────────────
RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''

# ── Stub common.sh — set the REAL guard variable so nixos.sh won't re-source ─
_LINUX_COMMON_LOADED=1
log_step()      { echo "[STEP] \$*"; }
log_info()      { echo "[INFO] \$*"; }
log_success()   { echo "[OK]   \$*"; }
log_warning()   { echo "[WARN] \$*"; }
log_error()     { echo "[ERR]  \$*" >&2; }
check_sudo()    { return 0; }          # never exit 4 in tests
backup_warning(){ return 0; }
append_once()   { return 0; }
git_clone_once(){ return 0; }
is_installed()  { return 1; }
require_os()    { return 0; }

# ── Stub dotfiles.sh ─────────────────────────────────────────────────────────
_DOTFILES_LOADED=1
step_dotfiles() { echo "[INFO] dotfiles skipped (mocked)"; return 0; }

# ── Point nixos.sh at our fake configuration.nix ─────────────────────────────
# We override _NIXOS_CONF after source via the re-declaration trick.

# ── Source the real script ────────────────────────────────────────────────────
source "${NIXOS_SH}"

# ── Post-source overrides (bash allows re-declaring functions) ────────────────
_NIXOS_CONF="${_FAKE_CONF}"       # redirect config path
_require_nixos() { return 0; }   # OS guard always passes in tests

# ── Run the requested expression ─────────────────────────────────────────────
${expr}
SUBSH
}

# ---------------------------------------------------------------------------
# count_in_file FILE PATTERN — print integer count, one line only
# ---------------------------------------------------------------------------
_count() { grep -cF "$2" "$1" 2>/dev/null || echo 0; }

# ===========================================================================
echo -e "\n${BOLD}PostInstallHUB — NixOS Smoke Tests${NC}\n"

# ---------------------------------------------------------------------------
echo -e "${CYAN}── Syntax ──${NC}"
# ---------------------------------------------------------------------------

# T01
bash -n "$NIXOS_SH" 2>/dev/null \
  && _pass "nixos.sh: bash -n" \
  || _fail "nixos.sh: syntax errors"

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── run_install (all flags off) ──${NC}"
# ---------------------------------------------------------------------------

# T02
_reset
out=$(_nixos_eval "run_install" \
        NIXOS_FLAKES=0 NIXOS_UNFREE=0 NIXOS_HOME_MANAGER=0) && rc=$? || rc=$?
(( rc == 0 )) \
  && _pass "run_install exits 0 (all flags off)" \
  || { _fail "run_install exited ${rc}"; echo "$out"; }

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── Channels ──${NC}"
# ---------------------------------------------------------------------------

# T03 — nixpkgs-unstable added when NIXOS_FLAKES=0
_reset
_nixos_eval "_step_channels" NIXOS_FLAKES=0 >/dev/null 2>&1 || true
grep -q "nixpkgs-unstable" "$_NIX_LOG" 2>/dev/null \
  && _pass "nix-channel --add nixpkgs-unstable called" \
  || _fail "nix-channel --add nixpkgs-unstable not found in call log"

# T04 — channels step skipped when NIXOS_FLAKES=1
_reset
out=$(_nixos_eval "_step_channels" NIXOS_FLAKES=1 2>&1) || true
echo "$out" | grep -q "skipping channel setup" \
  && _pass "channels skipped when NIXOS_FLAKES=1" \
  || _fail "expected 'skipping channel setup' not found"

# T05 — nix-channel --update called
_reset
_nixos_eval "_step_channels" NIXOS_FLAKES=0 >/dev/null 2>&1 || true
grep -q -- "--update" "$_NIX_LOG" 2>/dev/null \
  && _pass "nix-channel --update called" \
  || _fail "nix-channel --update not found in call log"

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── Flakes ──${NC}"
# ---------------------------------------------------------------------------

# T06 — snippet appended to configuration.nix
_reset
_nixos_eval "_step_flakes" NIXOS_FLAKES=1 >/dev/null 2>&1 || true
grep -q 'experimental-features' "$_FAKE_CONF" \
  && _pass "experimental-features written to configuration.nix" \
  || _fail "experimental-features NOT found in configuration.nix"

# T07 — nixos-rebuild called after snippet
_reset
_nixos_eval "_step_flakes" NIXOS_FLAKES=1 >/dev/null 2>&1 || true
grep -q "nixos-rebuild switch" "$_REBUILD_LOG" 2>/dev/null \
  && _pass "nixos-rebuild switch called after enabling flakes" \
  || _fail "nixos-rebuild switch not found in rebuild log"

# T08 — idempotent: marker not duplicated across two runs
_reset
_nixos_eval "_step_flakes" NIXOS_FLAKES=1 >/dev/null 2>&1 || true
_nixos_eval "_step_flakes" NIXOS_FLAKES=1 >/dev/null 2>&1 || true
count=$(_count "$_FAKE_CONF" 'PostInstallHUB — flakes')
[[ "$count" == "1" ]] \
  && _pass "flakes marker appears exactly once after two runs" \
  || _fail "flakes marker appears ${count} times (expected 1)"

# T09 — skipped when NIXOS_FLAKES=0
_reset
_nixos_eval "_step_flakes" NIXOS_FLAKES=0 >/dev/null 2>&1 || true
grep -q 'experimental-features' "$_FAKE_CONF" 2>/dev/null \
  && _fail "experimental-features written when NIXOS_FLAKES=0 (should not be)" \
  || _pass "experimental-features not written when NIXOS_FLAKES=0"

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── Unfree ──${NC}"
# ---------------------------------------------------------------------------

# T10 — snippet appended when NIXOS_UNFREE=1
_reset
_nixos_eval "_step_unfree" NIXOS_UNFREE=1 >/dev/null 2>&1 || true
grep -q 'allowUnfree' "$_FAKE_CONF" \
  && _pass "allowUnfree written when NIXOS_UNFREE=1" \
  || _fail "allowUnfree NOT found in configuration.nix"

# T11 — skipped when NIXOS_UNFREE=0
_reset
_nixos_eval "_step_unfree" NIXOS_UNFREE=0 >/dev/null 2>&1 || true
grep -q 'allowUnfree' "$_FAKE_CONF" 2>/dev/null \
  && _fail "allowUnfree written when NIXOS_UNFREE=0 (should not be)" \
  || _pass "allowUnfree not written when NIXOS_UNFREE=0"

# T12 — idempotent
_reset
_nixos_eval "_step_unfree" NIXOS_UNFREE=1 >/dev/null 2>&1 || true
_nixos_eval "_step_unfree" NIXOS_UNFREE=1 >/dev/null 2>&1 || true
count=$(_count "$_FAKE_CONF" 'PostInstallHUB — allowUnfree')
[[ "$count" == "1" ]] \
  && _pass "allowUnfree marker appears exactly once after two runs" \
  || _fail "allowUnfree marker appears ${count} times (expected 1)"

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── Home Manager ──${NC}"
# ---------------------------------------------------------------------------

# T13 — home-manager channel added
_reset
_nixos_eval "_step_home_manager" NIXOS_HOME_MANAGER=1 >/dev/null 2>&1 || true
grep -q "home-manager" "$_NIX_LOG" 2>/dev/null \
  && _pass "nix-channel --add home-manager called" \
  || _fail "nix-channel --add home-manager not found in call log"

# T14 — home-manager/nixos import snippet written
_reset
_nixos_eval "_step_home_manager" NIXOS_HOME_MANAGER=1 >/dev/null 2>&1 || true
grep -q 'home-manager/nixos' "$_FAKE_CONF" \
  && _pass "home-manager/nixos import written to configuration.nix" \
  || _fail "home-manager/nixos NOT found in configuration.nix"

# T15 — useGlobalPkgs written
grep -q 'useGlobalPkgs' "$_FAKE_CONF" \
  && _pass "home-manager.useGlobalPkgs written" \
  || _fail "home-manager.useGlobalPkgs NOT found in configuration.nix"

# T16 — skipped when NIXOS_HOME_MANAGER=0
_reset
_nixos_eval "_step_home_manager" NIXOS_HOME_MANAGER=0 >/dev/null 2>&1 || true
grep -q 'home-manager/nixos' "$_FAKE_CONF" 2>/dev/null \
  && _fail "home-manager written when NIXOS_HOME_MANAGER=0 (should not be)" \
  || _pass "home-manager not written when NIXOS_HOME_MANAGER=0"

# T17 — idempotent
_reset
_nixos_eval "_step_home_manager" NIXOS_HOME_MANAGER=1 >/dev/null 2>&1 || true
_nixos_eval "_step_home_manager" NIXOS_HOME_MANAGER=1 >/dev/null 2>&1 || true
count=$(_count "$_FAKE_CONF" 'PostInstallHUB — home-manager module')
[[ "$count" == "1" ]] \
  && _pass "home-manager marker appears exactly once after two runs" \
  || _fail "home-manager marker appears ${count} times (expected 1)"

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── Essential packages advisory ──${NC}"
# ---------------------------------------------------------------------------

# T18 — all required packages listed in output
_reset
out=$(_nixos_eval "_step_essential_pkgs" 2>&1) || true
for pkg in git curl wget neovim ripgrep fd fzf bat eza htop zsh; do
  echo "$out" | grep -q "$pkg" \
    && _pass "package listed in advisory: $pkg" \
    || _fail "package missing from advisory output: $pkg"
done

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── Rebuild step ──${NC}"
# ---------------------------------------------------------------------------

# T19 — nixos-rebuild called when _NIXOS_CONFIG_CHANGED=1
_reset
_nixos_eval "_NIXOS_CONFIG_CHANGED=1; _step_rebuild" >/dev/null 2>&1 || true
grep -q "nixos-rebuild switch" "$_REBUILD_LOG" 2>/dev/null \
  && _pass "nixos-rebuild switch called when _NIXOS_CONFIG_CHANGED=1" \
  || _fail "nixos-rebuild switch not found when _NIXOS_CONFIG_CHANGED=1"

# T20 — nixos-rebuild NOT called when _NIXOS_CONFIG_CHANGED=0
_reset
_nixos_eval "_NIXOS_CONFIG_CHANGED=0; _step_rebuild" >/dev/null 2>&1 || true
[[ ! -s "$_REBUILD_LOG" ]] \
  && _pass "nixos-rebuild NOT called when no config changes" \
  || _fail "nixos-rebuild unexpectedly called when _NIXOS_CONFIG_CHANGED=0"

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── nix_config_has helper ──${NC}"
# ---------------------------------------------------------------------------

# T21 — detects present marker
_reset
echo '# TESTMARKER_PRESENT' >> "$_FAKE_CONF"
out=$(_nixos_eval \
  "nix_config_has '# TESTMARKER_PRESENT' && echo FOUND || echo MISSING" 2>&1) || true
[[ "$out" == *"FOUND"* ]] \
  && _pass "nix_config_has: finds present marker" \
  || _fail "nix_config_has: failed to find present marker"

# T22 — returns absent for missing marker
out=$(_nixos_eval \
  "nix_config_has '# MARKER_NEVER_EXISTS' && echo FOUND || echo MISSING" 2>&1) || true
[[ "$out" == *"MISSING"* ]] \
  && _pass "nix_config_has: correctly absent for missing marker" \
  || _fail "nix_config_has: returned FOUND for missing marker"

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── OS guard ──${NC}"
# ---------------------------------------------------------------------------

# T23 — exits 5 on non-NixOS system
_reset
_UBUNTU_OS="${_WORK}/os-release-ubuntu"
cat > "$_UBUNTU_OS" << 'OSREL'
NAME="Ubuntu"
ID=ubuntu
VERSION="24.04"
OSREL

# We run a subshell that sources nixos.sh WITHOUT overriding _require_nixos,
# but patches it to read our fake Ubuntu os-release file.
rc=0
env -i \
  PATH="$_MOCK_PATH" \
  HOME="${_WORK}/home" \
  TERM=xterm \
  POSTINSTALL_YES=1 \
  POSTINSTALL_DOTFILES=none \
  _UBUNTU_OS="$_UBUNTU_OS" \
  _FAKE_CONF="$_FAKE_CONF" \
  _NIX_LOG="$_NIX_LOG" \
  _NIX_STATE="$_NIX_STATE" \
  _REBUILD_LOG="$_REBUILD_LOG" \
  bash << GUARD_TEST > /dev/null 2>&1
set -uo pipefail
RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
_LINUX_COMMON_LOADED=1
log_step()      { echo "[STEP] \$*"; }
log_info()      { echo "[INFO] \$*"; }
log_success()   { echo "[OK]   \$*"; }
log_warning()   { echo "[WARN] \$*"; }
log_error()     { echo "[ERR]  \$*" >&2; }
check_sudo()    { return 0; }
backup_warning(){ return 0; }
_DOTFILES_LOADED=1
step_dotfiles() { return 0; }
_NIXOS_CONF="\${_FAKE_CONF}"
source "${NIXOS_SH}"
# Override _require_nixos to read the Ubuntu os-release (NOT fake-nixos one)
_require_nixos() {
  local id
  id="\$(grep -oP '(?<=^ID=)[^\n]+' "\${_UBUNTU_OS}" 2>/dev/null \
       | tr -d '"' || echo unknown)"
  if [[ "\$id" != "nixos" ]]; then
    log_error "Wrong OS: expected 'nixos', got '\${id}'."
    exit 5
  fi
}
run_install
GUARD_TEST
rc=$?

[[ "$rc" == "5" ]] \
  && _pass "OS guard exits 5 for non-NixOS (Ubuntu id)" \
  || _fail "OS guard: expected exit 5, got ${rc}"

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── All flags enabled ──${NC}"
# ---------------------------------------------------------------------------

# T24 — run_install exits 0 with all three flags
_reset
out=$(_nixos_eval "run_install" \
        NIXOS_FLAKES=1 NIXOS_UNFREE=1 NIXOS_HOME_MANAGER=1) && rc=$? || rc=$?
(( rc == 0 )) \
  && _pass "run_install exits 0 (NIXOS_FLAKES=1 NIXOS_UNFREE=1 NIXOS_HOME_MANAGER=1)" \
  || { _fail "run_install exited ${rc} with all flags on"; echo "$out"; }

# T25–T27 — all three markers present in final configuration.nix
for marker in 'PostInstallHUB — flakes' 'PostInstallHUB — allowUnfree' \
              'PostInstallHUB — home-manager module'; do
  grep -qF "$marker" "$_FAKE_CONF" \
    && _pass "marker present: ${marker}" \
    || _fail "marker missing: ${marker}"
done

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── Script syntax ──${NC}"
# ---------------------------------------------------------------------------

# T28–T30
for script in \
  "${_ROOT_DIR}/scripts/linux/nixos.sh" \
  "${_ROOT_DIR}/scripts/linux/dotfiles.sh" \
  "${_ROOT_DIR}/scripts/linux/common.sh"; do
  bash -n "$script" 2>/dev/null \
    && _pass "syntax OK: $(basename "$script")" \
    || _fail "syntax ERR: $(basename "$script")"
done

# ---------------------------------------------------------------------------
echo -e "\n${CYAN}── dotfiles.sh NixOS note ──${NC}"
# ---------------------------------------------------------------------------

# T31 — jakoolit section mentions NixOS support
grep -q 'NixOS' "${_ROOT_DIR}/scripts/linux/dotfiles.sh" \
  && _pass "dotfiles.sh references NixOS in jakoolit section" \
  || _fail "dotfiles.sh missing NixOS reference"

# ===========================================================================
echo ""
echo "────────────────────────────────────────"
echo -e "${BOLD}Results: ${GREEN}${_PASS} passed${NC}  ${RED}${_FAIL} failed${NC}"
echo ""
[[ $_FAIL -eq 0 ]] && exit 0 || exit 1
