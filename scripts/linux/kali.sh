#!/usr/bin/env bash
# =============================================================================
# scripts/linux/kali.sh — Kali Linux 2025.x post-install setup
#
# Called by install.sh:
#   source scripts/linux/kali.sh && run_install
#
# Or run directly (still needs sudo):
#   bash scripts/linux/kali.sh
#
# Based on: Kalyan Dev's Kali 2025.2 setup guide
# Adapted to PostInstallHUB standards: idempotent · logged · safe
#
# Optional env flags:
#   POSTINSTALL_DOTFILES=none|zerodaygym|caelestia
#     zerodaygym  — i3-gaps Kali security desktop (Kali-only, recommended)
#     caelestia   — Quickshell Hyprland shell (via Nix)
#   POSTINSTALL_YES=1  — non-interactive; skip all prompts; skip dotfiles
# =============================================================================
set -euo pipefail

_KALI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_KALI_SCRIPT_DIR}/common.sh"
source "${_KALI_SCRIPT_DIR}/dotfiles.sh"

# ============================================================================
# STEP 1 — System Update
# ============================================================================
_step_update() {
  log_step "1 · System Update"
  sudo apt-get update -y
  sudo apt-get upgrade -y
  sudo apt-get autoremove -y
  log_success "System is up to date."
}

# ============================================================================
# STEP 2 — Folder Structure
# ============================================================================
_step_folders() {
  log_step "2 · Folder Structure"
  local dirs=(
    "${HOME}/Tools"
    "${HOME}/Docs"
    "${HOME}/Notes"
    "${HOME}/Scripts"
    "${HOME}/Trash"
    "${HOME}/Temps"
    "${HOME}/Wordlists"
  )
  for d in "${dirs[@]}"; do
    if [[ -d "$d" ]]; then
      log_info "Exists: ${d}"
    else
      mkdir -p "$d"
      log_success "Created: ${d}"
    fi
  done
}

# ============================================================================
# STEP 3 — Shell Aliases
# ============================================================================
_ALIAS_MARKER="# PostInstallHUB — Kali aliases BEGIN"

_step_aliases() {
  log_step "3 · Shell Aliases"

  local shell_rc="${HOME}/.zshrc"
  if [[ ! -f "$shell_rc" ]]; then
    log_warning "~/.zshrc not found — falling back to ~/.bashrc"
    shell_rc="${HOME}/.bashrc"
  fi

  if grep -qF "$_ALIAS_MARKER" "$shell_rc" 2>/dev/null; then
    log_info "Aliases already present in ${shell_rc} — skipping."
    return 0
  fi

  backup_warning "$shell_rc"

  cat >> "$shell_rc" << 'ALIASES'

# PostInstallHUB — Kali aliases BEGIN
# ── Directory shortcuts ──────────────────────────────────────────
alias scripts="cd ~/Scripts"
alias notes="cd ~/Notes"
alias docsh="cd ~/Docs"
alias tools="cd ~/Tools"
alias wordlists="cd ~/Wordlists"
alias trash="cd ~/Trash"
alias temps="cd ~/Temps"
alias down="cd ~/Downloads"
alias doc="cd ~/Documents"
alias desk="cd ~/Desktop"

# ── Package management ───────────────────────────────────────────
alias yep="sudo apt install"
alias nope="sudo apt remove"
alias updatekali="sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y"

# ── Navigation ───────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias root="sudo -i"

# ── Shell UX ─────────────────────────────────────────────────────
alias c="clear"
alias cls='clear && echo "Welcome back, $(whoami)! Stay sharp 🔥"'
alias hg="history | grep"
alias lss='ls -lah --color=auto'
alias lt='ls -lt --color=auto'
alias run="bash"
alias notepad="nano ~/Notes/quick_notes.txt"

# ── Cleanup ──────────────────────────────────────────────────────
alias emptytrash='rm -rf ~/Trash/*'
alias cleantemps='rm -rf ~/Temps/*'

# ── Network ──────────────────────────────────────────────────────
alias ports="nmap localhost"

# ── Services (if installed) ──────────────────────────────────────
alias nessus-start="sudo /bin/systemctl start nessusd.service"
alias nessus-stop="sudo /bin/systemctl stop nessusd.service"
# PostInstallHUB — Kali aliases END
ALIASES

  log_success "Aliases written to ${shell_rc}"
  log_info "Run:  source ${shell_rc}  (or open a new terminal)"
}

# ============================================================================
# STEP 4 — ZSH Auto-Suggestions
# ============================================================================
_ZSH_SUGGEST_MARKER="# PostInstallHUB — zsh-autosuggestions"

_step_zsh_autosuggest() {
  log_step "4 · ZSH Auto-Suggestions"

  apt_install zsh-autosuggestions

  local shell_rc="${HOME}/.zshrc"
  if [[ ! -f "$shell_rc" ]]; then
    log_warning "~/.zshrc not found — skipping autosuggestions config block."
    return 0
  fi

  if grep -qF "$_ZSH_SUGGEST_MARKER" "$shell_rc" 2>/dev/null; then
    log_info "Auto-suggestions already configured — skipping."
    return 0
  fi

  backup_warning "$shell_rc"
  cat >> "$shell_rc" << 'AUTOSUGGEST'

# PostInstallHUB — zsh-autosuggestions
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999'
# To disable: comment the two lines above
AUTOSUGGEST
  log_success "ZSH auto-suggestions configured."
}

# ============================================================================
# STEP 5 — UFW Firewall
# ============================================================================
_step_ufw() {
  log_step "5 · UFW Firewall"

  apt_install ufw

  if sudo ufw status | grep -q "Status: active"; then
    log_info "UFW is already active."
  else
    log_info "Applying UFW rules..."
    sudo ufw --force default deny incoming
    sudo ufw --force default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 80/tcp
    sudo ufw --force enable
    log_success "UFW enabled."
  fi
  sudo ufw status verbose
}

# ============================================================================
# STEP 6 — rockyou.txt + ~/Wordlists symlink
# ============================================================================
_step_wordlists() {
  log_step "6 · Wordlists"

  local rockyou="/usr/share/wordlists/rockyou.txt"
  local rockyou_gz="${rockyou}.gz"
  local symlink="${HOME}/Wordlists"

  if [[ -f "$rockyou" ]]; then
    log_info "rockyou.txt already extracted."
  elif [[ -f "$rockyou_gz" ]]; then
    log_info "Extracting rockyou.txt..."
    sudo gunzip "$rockyou_gz"
    log_success "rockyou.txt extracted."
  else
    log_warning "rockyou.txt.gz not found at ${rockyou_gz}."
    log_warning "Install 'seclists' package first, then re-run this step."
  fi

  # Symlink ~/Wordlists → /usr/share/wordlists (skip if already a dir the user made)
  if [[ -L "$symlink" ]]; then
    log_info "~/Wordlists symlink already exists → $(readlink "$symlink")"
  elif [[ -d "$symlink" ]]; then
    log_warning "~/Wordlists is a real directory — not replacing with symlink."
  else
    ln -s /usr/share/wordlists "$symlink"
    log_success "Created ~/Wordlists → /usr/share/wordlists"
  fi
}

# ============================================================================
# STEP 7 — Editors
# ============================================================================
_step_editors() {
  log_step "7 · Editors (apt)"
  apt_install gedit vim neovim nano
  log_success "Editors ready."
  log_info "For VS Code / Sublime: download .deb and run  sudo dpkg -i <file>.deb"
}

# ============================================================================
# STEP 8 — Terminal Tools
# ============================================================================
_step_terminal_tools() {
  log_step "8 · Terminal Tools"
  apt_install \
    terminator tmux \
    htop tree fonts-hack-ttf \
    tor torbrowser-launcher openvpn \
    flameshot keepassxc \
    kali-wallpapers-all
  log_success "Terminal tools installed."
}

# ============================================================================
# STEP 9 — Recon & Pentesting Tools
# ============================================================================
_step_recon_tools() {
  log_step "9 · Recon & Pentesting Tools"

  apt_install \
    dirsearch sublist3r amass \
    assetfinder httprobe \
    ffuf wfuzz dirb feroxbuster \
    eyewitness recon-ng \
    enum4linux wifite \
    seclists jq massdns \
    ripgrep nodejs npm

  # bat — binary name differs on some Kali versions
  if ! is_installed bat && ! is_installed batcat; then
    apt_install bat 2>/dev/null || apt_install batcat 2>/dev/null \
      || log_warning "bat/batcat not available — skipping."
  fi
  # Create 'bat' alias if only batcat is present
  if is_installed batcat && ! is_installed bat; then
    local shell_rc="${HOME}/.zshrc"
    [[ ! -f "$shell_rc" ]] && shell_rc="${HOME}/.bashrc"
    append_once "alias bat='batcat'" "$shell_rc" "alias bat='batcat'"
  fi

  # fd-find
  if ! is_installed fd && ! is_installed fdfind; then
    apt_install fd-find 2>/dev/null || log_warning "fd-find not available — skipping."
  fi

  log_success "Recon tools installed."
}

# ============================================================================
# STEP 10 — Python3 Libraries
# ============================================================================
_step_python_libs() {
  log_step "10 · Python3 Libraries"
  apt_install \
    python3-requests \
    python3-dnspython \
    python3-termcolor \
    python3-tldextract \
    python3-colorama \
    python3-cffi \
    python3-bs4
  log_success "Python3 libraries installed."
}

# ============================================================================
# STEP 11 — GitHub Tool Clones → ~/Tools
# ============================================================================
_step_github_tools() {
  log_step "11 · GitHub Tools (→ ~/Tools)"

  # name → repo URL
  local -A repos=(
    [XSStrike]="https://github.com/s0md3v/XSStrike.git"
    [tlshelpers]="https://github.com/hannob/tlshelpers.git"
    [shosubgo]="https://github.com/incogbyte/shosubgo.git"
    [SubDomainizer]="https://github.com/nsonaniya2010/SubDomainizer.git"
    [dnmasscan]="https://github.com/rastating/dnmasscan.git"
    [dorks-eye]="https://github.com/BullsEye0/dorks-eye.git"
    [blue_eye]="https://github.com/BullsEye0/blue_eye.git"
    [ghost_eye]="https://github.com/BullsEye0/ghost_eye.git"
  )

  for name in "${!repos[@]}"; do
    git_clone_once "${repos[$name]}" "${HOME}/Tools/${name}"
  done

  log_success "GitHub tools cloned to ~/Tools"
}

# ============================================================================
# STEP 12 — Go + Go Tools
# ============================================================================
_GO_PATH_MARKER="# PostInstallHUB — Go PATH"

_step_go_tools() {
  log_step "12 · Go + Go Tools"

  # Install Go if not present
  if ! is_installed go; then
    log_info "Installing golang-go from apt..."
    apt_install golang-go
    log_warning "apt Go may not be latest. For latest version: https://go.dev/dl/"
  else
    log_info "Go already installed: $(go version)"
  fi

  # Add ~/go/bin to PATH
  local shell_rc="${HOME}/.zshrc"
  [[ ! -f "$shell_rc" ]] && shell_rc="${HOME}/.bashrc"

  if grep -qF "$_GO_PATH_MARKER" "$shell_rc" 2>/dev/null; then
    log_info "Go PATH already in ${shell_rc}."
  else
    backup_warning "$shell_rc"
    cat >> "$shell_rc" << 'GOPATH'

# PostInstallHUB — Go PATH
export PATH=$PATH:$HOME/go/bin
GOPATH
    log_success "Go PATH added to ${shell_rc}"
  fi

  # Export now so go install works in this session
  export PATH="${PATH}:${HOME}/go/bin"

  if ! is_installed go; then
    log_warning "go not on PATH — skipping Go tool installs. Re-run after opening a new terminal."
    return 0
  fi

  local go_tools=(
    "github.com/tomnomnom/assetfinder@latest"
    "github.com/lc/gau/v2/cmd/gau@latest"
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    "github.com/tomnomnom/httprobe@latest"
    "github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest"
  )

  for tool_path in "${go_tools[@]}"; do
    local bin_name
    bin_name="$(basename "${tool_path%%@*}")"
    if is_installed "$bin_name" || [[ -f "${HOME}/go/bin/${bin_name}" ]]; then
      log_info "Go tool already installed: ${bin_name}"
    else
      log_info "go install ${tool_path}"
      go install "$tool_path" \
        && log_success "Installed: ${bin_name}" \
        || log_warning "Failed: ${tool_path} — check your network / Go version."
    fi
  done
}

# ============================================================================
# Manual steps summary (printed at end)
# ============================================================================
_print_manual_steps() {
  cat << 'MANUAL'

╔══════════════════════════════════════════════════════════════════╗
║            MANUAL STEPS — complete these yourself                ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  BROWSERS (download .deb → sudo dpkg -i <file>.deb)             ║
║    • Google Chrome  →  https://google.com/chrome                 ║
║    • Opera          →  https://opera.com/download                ║
║    • Chromium       →  sudo apt install chromium  (for Burp)     ║
║                                                                  ║
║  EDITORS                                                         ║
║    • VS Code        →  https://code.visualstudio.com             ║
║    • Sublime Text   →  https://sublimetext.com/download          ║
║                                                                  ║
║  BROWSER EXTENSIONS (install from browser store)                 ║
║    HackTools  ·  Cookie Editor  ·  Wappalyzer                    ║
║    User-Agent Switcher  ·  Dark Reader                           ║
║                                                                  ║
║  BURP SUITE                                                      ║
║    1. Set browser proxy → 127.0.0.1:8080                         ║
║    2. Import Burp CA certificate (Proxy → CA Certificate)        ║
║    3. Confirm intercept with Chromium                            ║
║                                                                  ║
║  RELOAD SHELL (aliases + Go PATH take effect)                    ║
║    source ~/.zshrc                                               ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
MANUAL
}

# ============================================================================
# run_install — called by install.sh
# ============================================================================
run_install() {
  require_os kali
  check_sudo

  log_step "PostInstallHUB · Kali Linux 2025.x"
  echo -e "${DIM}User: $(whoami)  ·  Host: $(hostname)  ·  Non-interactive: ${POSTINSTALL_YES:-0}${NC}\n"

  _step_update
  _step_folders
  _step_aliases
  _step_zsh_autosuggest
  _step_ufw
  _step_wordlists
  _step_editors
  _step_terminal_tools
  _step_recon_tools
  _step_python_libs
  _step_github_tools
  _step_go_tools

  step_dotfiles

  echo ""
  log_success "All automated steps complete!"
  _print_manual_steps
}

# Allow direct execution: bash scripts/linux/kali.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_install "$@"
fi
