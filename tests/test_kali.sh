#!/usr/bin/env bash
# =============================================================================
# tests/test_kali.sh — Smoke tests for scripts/linux/kali.sh
#
# Run AFTER install.sh on a live Kali box, or inside a Docker container.
#
# Usage:
#   bash tests/test_kali.sh
#   POSTINSTALL_YES=1 bash tests/test_kali.sh   # CI / non-interactive
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
_fail() { echo -e "${RED}[FAIL]${NC} $*"; (( _FAIL++ )) || true; }
_skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; }

check_cmd()  { command -v "$1" &>/dev/null  && _pass "binary on PATH: $1"          || _fail "binary missing: $1"; }
check_dir()  { [[ -d "$1" ]]               && _pass "directory exists: $1"          || _fail "directory missing: $1"; }
check_file() { [[ -f "$1" ]]               && _pass "file exists: $1"               || _fail "file missing: $1"; }
check_link() { [[ -L "$1" ]]               && _pass "symlink exists: $1"             || _fail "symlink missing: $1"; }
check_grep() { grep -qF "$2" "$1" 2>/dev/null && _pass "found '$2' in $1"           || _fail "missing '$2' in $1"; }

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}PostInstallHUB — Kali Smoke Tests${NC}\n"

# ── Step 2: Folder structure ───────────────────────────────────────────────
echo -e "${CYAN}── Folder structure ──${NC}"
for d in Tools Docs Notes Scripts Trash Temps Wordlists; do
  check_dir "${HOME}/${d}"
done

# ── Step 3: Shell aliases ──────────────────────────────────────────────────
echo -e "\n${CYAN}── Shell aliases ──${NC}"
SHELL_RC="${HOME}/.zshrc"
[[ ! -f "$SHELL_RC" ]] && SHELL_RC="${HOME}/.bashrc"
check_grep "$SHELL_RC" "# PostInstallHUB — Kali aliases BEGIN"
check_grep "$SHELL_RC" "alias yep="
check_grep "$SHELL_RC" "alias updatekali="
check_grep "$SHELL_RC" "alias lss="

# ── Step 4: ZSH auto-suggestions ──────────────────────────────────────────
echo -e "\n${CYAN}── ZSH auto-suggestions ──${NC}"
if command -v zsh &>/dev/null; then
  check_grep "$SHELL_RC" "zsh-autosuggestions.zsh"
else
  _skip "zsh not on PATH — skipping autosuggestions check"
fi

# ── Step 5: UFW ───────────────────────────────────────────────────────────
echo -e "\n${CYAN}── UFW ──${NC}"
check_cmd ufw
if command -v ufw &>/dev/null; then
  sudo ufw status 2>/dev/null | grep -q "Status: active" \
    && _pass "UFW is active" \
    || _fail "UFW is NOT active"
fi

# ── Step 6: Wordlists ─────────────────────────────────────────────────────
echo -e "\n${CYAN}── Wordlists ──${NC}"
check_link "${HOME}/Wordlists"
if [[ -L "${HOME}/Wordlists" ]]; then
  target="$(readlink "${HOME}/Wordlists")"
  [[ "$target" == "/usr/share/wordlists" ]] \
    && _pass "$HOME/Wordlists → /usr/share/wordlists" \
    || _fail "$HOME/Wordlists points to wrong target: ${target}"
fi

# ── Step 7: Editors ───────────────────────────────────────────────────────
echo -e "\n${CYAN}── Editors ──${NC}"
for e in vim nvim nano; do
  check_cmd "$e"
done

# ── Step 8: Terminal tools ────────────────────────────────────────────────
echo -e "\n${CYAN}── Terminal tools ──${NC}"
for t in tmux htop tree flameshot keepassxc; do
  check_cmd "$t"
done

# ── Step 9: Recon tools ───────────────────────────────────────────────────
echo -e "\n${CYAN}── Recon tools ──${NC}"
for t in ffuf wfuzz dirb feroxbuster amass recon-ng enum4linux jq ripgrep; do
  check_cmd "$t"
done

# ── Step 10: Python3 libraries ────────────────────────────────────────────
echo -e "\n${CYAN}── Python3 libraries ──${NC}"
for lib in requests termcolor colorama cffi bs4; do
  python3 -c "import ${lib}" 2>/dev/null \
    && _pass "python3 import ok: ${lib}" \
    || _fail "python3 import failed: ${lib}"
done
# dns.resolver lives in dnspython package
python3 -c "import dns.resolver" 2>/dev/null \
  && _pass "python3 import ok: dns.resolver (dnspython)" \
  || _fail "python3 import failed: dns.resolver (dnspython)"
# tldextract
python3 -c "import tldextract" 2>/dev/null \
  && _pass "python3 import ok: tldextract" \
  || _fail "python3 import failed: tldextract"

# ── Step 11: GitHub clones ────────────────────────────────────────────────
echo -e "\n${CYAN}── GitHub clones (~/Tools) ──${NC}"
for tool in XSStrike tlshelpers shosubgo SubDomainizer dnmasscan dorks-eye blue_eye ghost_eye; do
  check_dir "${HOME}/Tools/${tool}"
done

# ── Step 12: Go + Go tools ────────────────────────────────────────────────
echo -e "\n${CYAN}── Go tools ──${NC}"
check_grep "$SHELL_RC" "# PostInstallHUB — Go PATH"
if command -v go &>/dev/null; then
  _pass "go on PATH: $(go version 2>/dev/null)"
  for t in assetfinder gau subfinder httprobe shuffledns; do
    ( command -v "$t" &>/dev/null || [[ -f "${HOME}/go/bin/${t}" ]] ) \
      && _pass "go tool installed: ${t}" \
      || _fail "go tool missing:   ${t}"
  done
else
  _fail "go binary not found on PATH"
fi

# ── lib/ source guard sanity ──────────────────────────────────────────────
echo -e "\n${CYAN}── lib/ double-source guards ──${NC}"
(
  # shellcheck source=/dev/null
  source "${_ROOT_DIR}/lib/colors.sh"
  source "${_ROOT_DIR}/lib/colors.sh"  # second source must be no-op
  [[ -n "${_COLORS_LOADED:-}" ]] \
    && echo -e "${GREEN}[PASS]${NC} colors.sh: double-source guard works" \
    || echo -e "${RED}[FAIL]${NC} colors.sh: guard variable missing"
)
(
  source "${_ROOT_DIR}/lib/lock.sh"
  source "${_ROOT_DIR}/lib/lock.sh"
  [[ -n "${_LOCK_LOADED:-}" ]] \
    && echo -e "${GREEN}[PASS]${NC} lock.sh: double-source guard works" \
    || echo -e "${RED}[FAIL]${NC} lock.sh: guard variable missing"
)

# ── install.sh syntax ─────────────────────────────────────────────────────
echo -e "\n${CYAN}── Script syntax ──${NC}"
for script in \
  "${_ROOT_DIR}/install.sh" \
  "${_ROOT_DIR}/lib/colors.sh" \
  "${_ROOT_DIR}/lib/lock.sh" \
  "${_ROOT_DIR}/lib/backup.sh" \
  "${_ROOT_DIR}/scripts/linux/common.sh" \
  "${_ROOT_DIR}/scripts/linux/kali.sh"; do
  bash -n "$script" 2>/dev/null \
    && _pass "syntax OK: $(basename "$script")" \
    || _fail "syntax ERR: $(basename "$script")"
done

# ---------------------------------------------------------------------------
echo -e "\n${BOLD}Results: ${GREEN}${_PASS} passed${NC}  ${RED}${_FAIL} failed${NC}\n"
[[ $_FAIL -eq 0 ]] && exit 0 || exit 1
