#!/usr/bin/env bash
# =============================================================================
# scripts/linux/arch.sh — Arch Linux post-install setup
#
# Based on: github.com/DoTheEvo/ansible-arch
# Covers: core packages · yay · pacman/makepkg config · services ·
#         VM guest tools · micro editor · zsh + zimfw · docker (optional) ·
#         LTS kernel (optional)
#
# Called by install.sh:
#   source scripts/linux/arch.sh && run_install
#
# Or run directly:
#   bash scripts/linux/arch.sh
#
# Optional env flags:
#   ARCH_DOCKER=1      — also run _step_docker
#   ARCH_LTS=1         — also run _step_lts_kernel
#   POSTINSTALL_YES=1  — non-interactive (no prompts); skips dotfiles
#   POSTINSTALL_DOTFILES=none|jakoolit|caelestia
#     jakoolit   — Hyprland desktop (LinuxBeginnings/Hyprland-Dots, Arch-supported)
#     caelestia  — Quickshell Hyprland desktop (yay: caelestia-shell-git)
# =============================================================================
set -euo pipefail

_ARCH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_ARCH_SCRIPT_DIR}/common.sh"
source "${_ARCH_SCRIPT_DIR}/dotfiles.sh"

# ============================================================================
# Arch-specific package helpers (pacman doesn't have apt_install equivalent)
# ============================================================================

# pacman_install PKG [PKG…] — idempotent; only installs what's missing
pacman_install() {
  local to_install=()
  for pkg in "$@"; do
    if pacman -Qi "$pkg" &>/dev/null; then
      log_info "Already installed: ${pkg}"
    else
      to_install+=("$pkg")
    fi
  done
  if [[ ${#to_install[@]} -eq 0 ]]; then
    return 0
  fi
  log_info "pacman installing: ${to_install[*]}"
  local confirm_flag="--noconfirm"
  [[ "${POSTINSTALL_YES:-0}" != "1" ]] && confirm_flag=""
  sudo pacman -S --needed ${confirm_flag} "${to_install[@]}"
}

# yay_install PKG [PKG…] — idempotent AUR install via yay
yay_install() {
  if ! is_installed yay; then
    log_error "yay not installed. Run _step_yay first."
    return 1
  fi
  local to_install=()
  for pkg in "$@"; do
    if pacman -Qi "$pkg" &>/dev/null; then
      log_info "Already installed (AUR): ${pkg}"
    else
      to_install+=("$pkg")
    fi
  done
  if [[ ${#to_install[@]} -eq 0 ]]; then
    return 0
  fi
  log_info "yay installing: ${to_install[*]}"
  yay -S --needed --noconfirm "${to_install[@]}"
}

# service_enable_now SERVICE — enable+start only if not already active
service_enable_now() {
  local svc="$1"
  if systemctl is-enabled "$svc" &>/dev/null; then
    log_info "Service already enabled: ${svc}"
  else
    sudo systemctl enable --now "$svc"
    log_success "Enabled + started: ${svc}"
  fi
}

# ============================================================================
# STEP 1 — System Update
# ============================================================================
_step_update() {
  log_step "1 · System Update (pacman -Syu)"
  local confirm_flag="--noconfirm"
  [[ "${POSTINSTALL_YES:-0}" != "1" ]] && confirm_flag=""
  sudo pacman -Syu ${confirm_flag}
  log_success "System up to date."
}

# ============================================================================
# STEP 2 — Core Packages
# ============================================================================
_CORE_PACKAGES=(
  # Text editors
  nano micro
  # System docs
  man-db man-pages
  # Version control + network fetch
  git curl wget rsync
  # File managers / search
  nnn fd fzf
  # Terminal UX
  bat tree fastfetch duf ncdu
  # Archivers
  unarchiver
  # Monitoring
  htop btop iotop glances
  # Network tools
  nmap gnu-netcat tcpdump inetutils net-tools iperf3
  iproute2 bind nload
  # System
  sysfsutils lsof fuse arch-install-scripts
  # Python
  python-pip python-setuptools python-pexpect
  # Database
  sqlite
  # Misc
  reflector plocate cronie trash-cli logrotate
)

_step_packages() {
  log_step "2 · Core Packages"
  pacman_install "${_CORE_PACKAGES[@]}"
  log_success "Core packages installed."
}

# ============================================================================
# STEP 3 — yay (AUR helper)
# ============================================================================
_step_yay() {
  log_step "3 · yay AUR Helper"

  if is_installed yay; then
    log_info "yay already installed: $(yay --version 2>/dev/null | head -1)"
    return 0
  fi

  # Build deps
  pacman_install git base-devel

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '${tmp_dir}'" RETURN

  log_info "Cloning yay-bin from AUR..."
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "${tmp_dir}/yay-bin"

  log_info "Building yay-bin (makepkg as current user)..."
  # makepkg MUST NOT run as root
  pushd "${tmp_dir}/yay-bin" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null

  # Post-install yay config
  yay --save --removemake --cleanafter --sudoloop
  log_success "yay installed and configured."
}

# ============================================================================
# STEP 4 — pacman.conf
# ============================================================================
_step_pacman_config() {
  log_step "4 · pacman.conf (Color + ParallelDownloads)"

  local conf="/etc/pacman.conf"
  local changed=false

  if ! grep -q "^Color" "$conf"; then
    [[ "$changed" == false ]] && sudo cp "$conf" "${conf}.postinstallhub.bak"
    sudo sed -i 's/^#Color$/Color/' "$conf"
    log_success "pacman.conf: Color enabled."
    changed=true
  else
    log_info "pacman.conf: Color already on."
  fi

  if ! grep -q "^ParallelDownloads" "$conf"; then
    [[ "$changed" == false ]] && sudo cp "$conf" "${conf}.postinstallhub.bak"
    sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' "$conf"
    log_success "pacman.conf: ParallelDownloads enabled."
    changed=true
  else
    log_info "pacman.conf: ParallelDownloads already on."
  fi

  [[ "$changed" == false ]] && log_info "pacman.conf: already configured — skipped."
}

# ============================================================================
# STEP 5 — makepkg.conf (parallel compilation, no compression)
# ============================================================================
_step_makepkg_config() {
  log_step "5 · makepkg.conf"

  local conf="/etc/makepkg.conf"
  local cores
  cores="$(nproc)"
  local changed=false

  # Parallel compilation
  if ! grep -q "^MAKEFLAGS=" "$conf"; then
    [[ "$changed" == false ]] && sudo cp "$conf" "${conf}.postinstallhub.bak"
    sudo sed -i "s/^#MAKEFLAGS=.*/MAKEFLAGS=\"-j${cores}\"/" "$conf"
    log_success "makepkg.conf: MAKEFLAGS=-j${cores}"
    changed=true
  else
    log_info "makepkg.conf: MAKEFLAGS already set."
  fi

  # No compression — faster builds, slightly larger packages (local use only)
  if grep -q "PKGEXT='.pkg.tar.zst'" "$conf"; then
    [[ "$changed" == false ]] && sudo cp "$conf" "${conf}.postinstallhub.bak"
    sudo sed -i "s/PKGEXT='.pkg.tar.zst'/PKGEXT='.pkg.tar'/" "$conf"
    log_success "makepkg.conf: PKGEXT → .pkg.tar (no compression)"
    changed=true
  elif grep -q "^PKGEXT=" "$conf"; then
    log_info "makepkg.conf: PKGEXT already customised."
  fi

  [[ "$changed" == false ]] && log_info "makepkg.conf: already configured — skipped."
}

# ============================================================================
# STEP 6 — Security: failed login attempts + wheel sudo
# ============================================================================
_SUDOERS_WHEEL="/etc/sudoers.d/10-wheel"
_SUDOERS_NOPASS="/etc/sudoers.d/20-${USER}-nopasswd"

_step_security() {
  log_step "6 · Security (faillock + sudo)"

  # Increase lock-out threshold from default 3 → 10 attempts
  local faillock_conf="/etc/security/faillock.conf"
  if [[ -f "$faillock_conf" ]]; then
    if grep -q "^deny = 10" "$faillock_conf"; then
      log_info "faillock: deny=10 already set."
    else
      sudo cp "$faillock_conf" "${faillock_conf}.postinstallhub.bak"
      # Uncomment or replace the deny line
      if grep -q "^# deny" "$faillock_conf" || grep -q "^deny" "$faillock_conf"; then
        sudo sed -i 's/^#\? *deny = .*/deny = 10/' "$faillock_conf"
      else
        echo "deny = 10" | sudo tee -a "$faillock_conf" >/dev/null
      fi
      log_success "faillock: deny set to 10 attempts before lock."
    fi
  else
    log_warning "faillock.conf not found — skipping."
  fi

  # wheel group can sudo
  if [[ -f "$_SUDOERS_WHEEL" ]]; then
    log_info "sudoers wheel: already configured."
  else
    echo "%wheel ALL=(ALL:ALL) ALL" | sudo tee "$_SUDOERS_WHEEL" >/dev/null
    sudo chmod 440 "$_SUDOERS_WHEEL"
    log_success "sudoers: wheel group can sudo."
  fi

  # Current user: no password for sudo (personal machine convenience)
  if [[ -f "$_SUDOERS_NOPASS" ]]; then
    log_info "sudoers nopasswd: already set for ${USER}."
  else
    log_warning "Adding NOPASSWD sudo for ${USER} — personal machine only!"
    echo "${USER} ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee "$_SUDOERS_NOPASS" >/dev/null
    sudo chmod 440 "$_SUDOERS_NOPASS"
    log_success "sudoers: ${USER} can sudo without password."
  fi
}

# ============================================================================
# STEP 7 — Services
# ============================================================================
_step_services() {
  log_step "7 · Services"

  # SSH
  service_enable_now sshd.service

  # plocate (file locate)
  service_enable_now plocate-updatedb.timer

  # cronie (cron scheduler)
  service_enable_now cronie.service

  # archlinux-keyring weekly update
  service_enable_now archlinux-keyring-wkd-sync.timer

  # SSD trim
  service_enable_now fstrim.timer

  # paccache — weekly pacman cache cleanup (keeps last 3 versions)
  if pacman -Qi pacman-contrib &>/dev/null || pacman_install pacman-contrib; then
    service_enable_now paccache.timer
  fi

  # reflector — mirror list updater
  # !! EDIT /etc/xdg/reflector/reflector.conf — change country codes !!
  _configure_reflector
  service_enable_now reflector.timer

  # logrotate
  service_enable_now logrotate.timer

  log_success "All services enabled."
}

_configure_reflector() {
  local rconf="/etc/xdg/reflector/reflector.conf"
  local marker="# PostInstallHUB reflector config"

  if grep -qF "$marker" "$rconf" 2>/dev/null; then
    log_info "reflector.conf: already configured."
    return 0
  fi

  [[ -f "$rconf" ]] && sudo cp "$rconf" "${rconf}.postinstallhub.bak"

  sudo tee "$rconf" >/dev/null <<'REFLECTOR'
# PostInstallHUB reflector config
# !! Edit --country to your nearest countries for best mirrors !!
--save /etc/pacman.d/mirrorlist
--protocol https
--country US,DE,FR
--latest 10
--sort rate
REFLECTOR

  log_success "reflector.conf written — edit --country if needed: ${rconf}"
}

# ============================================================================
# STEP 8 — VM Guest Tools (auto-detect hypervisor)
# ============================================================================
_step_vm_support() {
  log_step "8 · VM Guest Tools"

  if ! is_installed systemd-detect-virt; then
    log_info "systemd-detect-virt not found — skipping VM detection."
    return 0
  fi

  local virt
  virt="$(systemd-detect-virt 2>/dev/null || echo "none")"
  log_info "Hypervisor detected: ${virt}"

  case "$virt" in
    vmware)
      pacman_install open-vm-tools
      service_enable_now vmtoolsd.service
      service_enable_now vmware-vmblock-fuse.service
      log_success "VMware guest tools installed."
      ;;
    microsoft) # Hyper-V
      pacman_install hyperv
      service_enable_now hv_fcopy_daemon.service
      service_enable_now hv_kvp_daemon.service
      service_enable_now hv_vss_daemon.service
      log_success "Hyper-V guest services installed."
      ;;
    oracle) # VirtualBox
      pacman_install virtualbox-guest-utils
      service_enable_now vboxservice.service
      log_success "VirtualBox guest utils installed."
      ;;
    xen) # XCP-ng / XenServer
      yay_install xe-guest-utilities-xcp-ng
      service_enable_now xe-linux-distribution.service
      log_success "XCP-ng guest utilities installed."
      ;;
    none | *)
      log_info "Running on bare metal (or unknown hypervisor) — skipping VM tools."
      ;;
  esac
}

# ============================================================================
# STEP 9 — micro text editor config
# ============================================================================
_MICRO_CONF_DIR="${HOME}/.config/micro"
_MICRO_CONF_MARKER="postinstallhub"

_step_micro() {
  log_step "9 · micro Editor"

  pacman_install micro

  # Create config directory
  mkdir -p "${_MICRO_CONF_DIR}"

  # settings.json
  local settings="${_MICRO_CONF_DIR}/settings.json"
  if [[ -f "$settings" ]] && grep -q "$_MICRO_CONF_MARKER" "$settings" 2>/dev/null; then
    log_info "micro settings.json: already configured."
  else
    [[ -f "$settings" ]] && cp "$settings" "${settings}.postinstallhub.bak"
    cat >"$settings" <<'MICRO_SETTINGS'
{
  "clipboard": "terminal",
  "colorscheme": "dracula",
  "tabsize": 4,
  "tabstospaces": true,
  "ruler": true,
  "savecursor": true,
  "saveundo": true,
  "softwrap": false,
  "autoclose": true,
  "rmtrailingws": true,
  "comment": "postinstallhub"
}
MICRO_SETTINGS
    log_success "micro: settings.json written (clipboard=terminal for OSC52 SSH copy-paste)"
  fi

  # keybindings.json — useful shortcuts
  local keybinds="${_MICRO_CONF_DIR}/bindings.json"
  if [[ -f "$keybinds" ]] && grep -q "$_MICRO_CONF_MARKER" "$keybinds" 2>/dev/null; then
    log_info "micro bindings.json: already configured."
  else
    [[ -f "$keybinds" ]] && cp "$keybinds" "${keybinds}.postinstallhub.bak"
    cat >"$keybinds" <<'MICRO_KEYS'
{
  "Ctrl-q": "Quit",
  "Ctrl-s": "Save",
  "comment": "postinstallhub"
}
MICRO_KEYS
    log_success "micro: bindings.json written."
  fi

  # Set micro as default EDITOR in ~/.bashrc
  local shell_rc="${HOME}/.bashrc"
  append_once "# PostInstallHUB — default EDITOR=micro" "$shell_rc" \
    "# PostInstallHUB — default EDITOR=micro
export EDITOR=micro
export VISUAL=micro"

  log_success "micro configured. Ctrl+q exits, clipboard works over SSH via OSC52."
}

# ============================================================================
# STEP 10 — Network: disable DNSSEC (broken since systemd Sep 2025 update)
# ============================================================================
_step_network() {
  log_step "10 · Network (DNSSEC disable)"

  local resolved_conf="/etc/systemd/resolved.conf"
  local marker="# PostInstallHUB — DNSSEC=no"

  if grep -qF "$marker" "$resolved_conf" 2>/dev/null; then
    log_info "resolved.conf: DNSSEC already disabled."
    return 0
  fi

  sudo cp "$resolved_conf" "${resolved_conf}.postinstallhub.bak" 2>/dev/null || true
  cat <<'RESOLVED' | sudo tee -a "$resolved_conf" >/dev/null

# PostInstallHUB — DNSSEC=no
# Disabled because DNSSEC was broken by default in systemd (September 2025)
# See: https://www.reddit.com/r/archlinux/comments/1nlg0wf
[Resolve]
DNSSEC=no
RESOLVED

  sudo systemctl restart systemd-resolved.service 2>/dev/null || true
  log_success "resolved.conf: DNSSEC=no applied and service restarted."
  log_info "Note: MAC-based network naming requires manual setup (interface-specific)."
  log_info "      See: docs/03-architecture/INTEGRATIONS.md"
}

# ============================================================================
# STEP 11 — ZSH + zimfw
# ============================================================================
_MYOWNRC_MARKER="# PostInstallHUB — .myownrc"

_step_zsh() {
  log_step "11 · ZSH + zimfw"

  pacman_install zsh

  # Copy bash history to zsh history if zhistory doesn't exist
  if [[ ! -f "${HOME}/.zhistory" ]] && [[ -f "${HOME}/.bash_history" ]]; then
    cp "${HOME}/.bash_history" "${HOME}/.zhistory"
    log_success "Copied .bash_history → .zhistory"
  fi

  # Change default shell to zsh
  local current_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current_shell" == "/usr/bin/zsh" ]] || [[ "$current_shell" == "/bin/zsh" ]]; then
    log_info "ZSH already the default shell."
  else
    log_info "Changing default shell to zsh (requires password)..."
    chsh -s /usr/bin/zsh
    log_success "Default shell → zsh (takes effect on next login)."
  fi

  # Install zimfw
  if [[ -f "${HOME}/.local/share/zimfw/zimfw.zsh" ]] ||
    [[ -f "${HOME}/.zimfw/zimfw.zsh" ]] ||
    is_installed zimfw; then
    log_info "zimfw already installed."
  else
    log_info "Installing zimfw..."
    curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh
    log_success "zimfw installed."
  fi

  # Set steeef theme in .zimrc
  local zimrc="${HOME}/.zimrc"
  if [[ -f "$zimrc" ]]; then
    if grep -q "steeef" "$zimrc"; then
      log_info ".zimrc: steeef theme already set."
    else
      backup_warning "$zimrc"
      # Comment out any existing prompt/theme module
      sed -i 's/^zmodule .*theme.*/# & # disabled by PostInstallHUB/' "$zimrc" 2>/dev/null || true
      sed -i 's/^zmodule eriner/#&/' "$zimrc" 2>/dev/null || true
      echo "zmodule steeef" >>"$zimrc"
      log_success ".zimrc: steeef theme added."
      log_info "Run 'zimfw install' in a new zsh session to apply."
    fi
  else
    log_warning ".zimrc not found — zimfw may not have installed properly."
  fi

  # Write .myownrc
  _write_myownrc

  # Source .myownrc from .zshrc
  local zshrc="${HOME}/.zshrc"
  if [[ -f "$zshrc" ]]; then
    append_once "$_MYOWNRC_MARKER" "$zshrc" \
      "$_MYOWNRC_MARKER
[[ -f ~/.myownrc ]] && source ~/.myownrc"
  fi

  log_success "ZSH configured. Open a new terminal to experience zsh + steeef."
}

_write_myownrc() {
  local myownrc="${HOME}/.myownrc"
  local marker="# PostInstallHUB — .myownrc BEGIN"

  if grep -qF "$marker" "$myownrc" 2>/dev/null; then
    log_info ".myownrc: already written."
    return 0
  fi

  [[ -f "$myownrc" ]] && cp "$myownrc" "${myownrc}.postinstallhub.bak"

  cat >"$myownrc" <<'MYOWNRC'
# PostInstallHUB — .myownrc BEGIN
# Based on github.com/DoTheEvo/ansible-arch
# ── Aliases ──────────────────────────────────────────────────────────────────

# File managers
alias n='nnn -de'
alias nnnn='sudo -E nnn -de'             # nnn as root, with user envs
alias zz='yazi'
alias yy='yazi'
alias zzz='sudo -E yazi'                 # yazi as root, with user envs
alias yyy='sudo -E yazi'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -alh --color=auto'
alias la='ls -A --color=auto'
alias lt='ls -lt --color=auto'

# Editors
alias e='micro'
alias se='sudo micro'

# Pacman
alias pac='sudo pacman'
alias pacs='sudo pacman -S'
alias pacsyu='sudo pacman -Syu'
alias pacr='sudo pacman -Rns'
alias paci='pacman -Qi'
alias pacss='pacman -Ss'

# locate — always case-insensitive
alias locate='plocate -i'

# Systemctl shortcuts
alias sc='sudo systemctl'
alias sce='sudo systemctl enable --now'
alias scs='sudo systemctl status'

# Journal
alias jf='sudo journalctl -p 3 -rxb'    # errors only, reverse, boot
alias jfu='sudo journalctl -fu'          # follow a unit

# Misc
alias c='clear'
alias h='history | grep'
alias myip='curl -s ipinfo.io'
alias ports='sudo ss -tulpn'
alias disk='duf'
alias top='btop'

# ── Functions ─────────────────────────────────────────────────────────────────

# yazi wrapper — start in ~/docker if it exists
yy() {
  local target="${HOME}/docker"
  [[ -d "$target" ]] && cd "$target"
  yazi "$@"
}

# ── ZSH key bindings ─────────────────────────────────────────────────────────

# Ctrl+S — prepend 'sudo' to current line
add_sudo() { BUFFER="sudo $BUFFER"; zle end-of-line; }
zle -N add_sudo
bindkey '^S' add_sudo

# Ctrl+F — prepend 'sudo micro' (quick file edit)
add_sudo_micro() { BUFFER="sudo micro $BUFFER"; zle end-of-line; }
zle -N add_sudo_micro
bindkey '^F' add_sudo_micro

# ── Prompt indicator for terminal opened inside yazi/nnn ─────────────────────
[ -n "$YAZI_LEVEL" ] && PS1="[Ψ] $PS1"
[ -n "$NNNLVL" ]     && PS1="[N${NNNLVL}] $PS1"

# PostInstallHUB — .myownrc END
MYOWNRC

  log_success ".myownrc written to ${myownrc}"
}

# ============================================================================
# STEP 12 — Docker (optional — set ARCH_DOCKER=1 to run)
# ============================================================================
_step_docker() {
  log_step "12 · Docker"

  pacman_install docker docker-compose

  # ctop — container monitoring (AUR)
  if is_installed yay; then
    yay_install ctop
  else
    log_warning "yay not available — skipping ctop (AUR package)."
  fi

  service_enable_now docker.service

  # Add current user to docker group (no sudo needed for docker commands)
  if groups "$USER" | grep -q docker; then
    log_info "User ${USER} already in docker group."
  else
    sudo usermod -aG docker "$USER"
    log_success "Added ${USER} to docker group (re-login to take effect)."
  fi

  # Set default log size + rotation in /etc/docker/daemon.json
  local daemon_json="/etc/docker/daemon.json"
  if [[ -f "$daemon_json" ]] && grep -q '"max-size"' "$daemon_json"; then
    log_info "docker daemon.json: logging already configured."
  else
    [[ -f "$daemon_json" ]] && sudo cp "$daemon_json" "${daemon_json}.postinstallhub.bak"
    sudo mkdir -p /etc/docker
    echo '{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "250m",
    "max-file": "3"
  }
}' | sudo tee "$daemon_json" >/dev/null
    log_success "docker: log rotation set to 250MB × 3 files."
    sudo systemctl reload-or-restart docker.service 2>/dev/null || true
  fi

  log_success "Docker ready. Re-login for group membership to take effect."
}

# ============================================================================
# STEP 13 — LTS Kernel (optional — set ARCH_LTS=1 to run)
# ============================================================================
_step_lts_kernel() {
  log_step "13 · LTS Kernel (RISKY — snapshot first!)"
  log_warning "This modifies your bootloader. Take a snapshot before proceeding."

  if [[ "${POSTINSTALL_YES:-0}" != "1" ]]; then
    echo -e "Type ${BOLD}yes${NC} to continue or anything else to skip:"
    read -r confirm
    [[ "$confirm" != "yes" ]] && {
      log_info "LTS kernel step skipped."
      return 0
    }
  fi

  pacman_install linux-lts linux-lts-headers

  # Detect bootloader
  local bootloader="unknown"
  if [[ -d /boot/loader/entries ]]; then
    bootloader="systemd-boot"
  elif is_installed grub && [[ -f /boot/grub/grub.cfg ]]; then
    bootloader="grub"
  fi

  log_info "Bootloader detected: ${bootloader}"

  case "$bootloader" in
    systemd-boot)
      log_info "systemd-boot: regenerating entries..."
      # Add lts entry if not present
      if ! ls /boot/loader/entries/ | grep -q lts; then
        local stock_entry
        stock_entry="$(ls /boot/loader/entries/*.conf 2>/dev/null | head -1)"
        if [[ -n "$stock_entry" ]]; then
          local lts_entry="/boot/loader/entries/arch-lts.conf"
          sudo cp "$stock_entry" "$lts_entry"
          sudo sed -i 's/vmlinuz-linux$/vmlinuz-linux-lts/' "$lts_entry"
          sudo sed -i 's/initramfs-linux/initramfs-linux-lts/' "$lts_entry"
          sudo sed -i 's/^title .*/title Arch Linux LTS/' "$lts_entry"
          log_success "Created systemd-boot LTS entry: ${lts_entry}"
        else
          log_warning "No existing boot entry found to base LTS entry on. Manual setup needed."
        fi
      else
        log_info "LTS boot entry already exists."
      fi
      ;;
    grub)
      log_info "grub: regenerating grub.cfg..."
      sudo grub-mkconfig -o /boot/grub/grub.cfg
      log_success "grub.cfg regenerated — LTS kernel will appear in menu on next boot."
      ;;
    *)
      log_warning "Unknown bootloader — cannot auto-configure LTS boot entry."
      log_warning "Install linux-lts was done; configure your bootloader manually."
      ;;
  esac

  log_success "LTS kernel installed. Reboot and select Arch Linux LTS from boot menu."
}

# ============================================================================
# Manual steps banner
# ============================================================================
_print_manual_steps() {
  cat <<'MANUAL'

╔══════════════════════════════════════════════════════════════════╗
║            MANUAL STEPS — complete these yourself                ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  REFLECTOR — set your country codes                             ║
║    sudo micro /etc/xdg/reflector/reflector.conf                  ║
║    Change: --country US,DE,FR → your nearest countries           ║
║    sudo systemctl start reflector.service                        ║
║                                                                  ║
║  REMOVE ANSIBLE (if you used it before) saves ~600MB            ║
║    sudo pacman -Rns ansible                                      ║
║                                                                  ║
║  YAZI (recommended file manager, personal workflow)             ║
║    sudo pacman -S yazi                                           ║
║    Start with: zz or yy  |  as root: zzz or yyy                 ║
║    In yazi: e=edit  !=terminal  f=filter  z=fzf  g=goto         ║
║                                                                  ║
║  ZSH — apply zimfw theme (after opening new terminal)           ║
║    zimfw install                                                  ║
║                                                                  ║
║  NNN plugins (no sudo needed)                                   ║
║    curl -Ls https://raw.githubusercontent.com/jarun/nnn/...     ║
║    (see: github.com/jarun/nnn/blob/master/plugins/README.md)    ║
║                                                                  ║
║  DOCKER (optional)                                               ║
║    ARCH_DOCKER=1 bash install.sh                                 ║
║                                                                  ║
║  LTS KERNEL (optional, risky — snapshot first!)                 ║
║    ARCH_LTS=1 bash install.sh                                    ║
║                                                                  ║
║  MICRO over SSH — add to ~/.config/micro/settings.json          ║
║    "clipboard": "terminal"                                       ║
║    Also enable OSC52 in your terminal (e.g. Alacritty):         ║
║    [terminal]                                                    ║
║    osc52 = "CopyPaste"                                           ║
║                                                                  ║
║  AFTER INSTALL — remove ansible if present                      ║
║    sudo pacman -Rns ansible  (~600MB freed)                      ║
║                                                                  ║
║  RE-LOGIN to activate: zsh · docker group · sudo nopasswd       ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
MANUAL
}

# ============================================================================
# run_install — orchestrator (called by install.sh)
# ============================================================================
run_install() {
  require_os arch
  check_sudo

  log_step "PostInstallHUB · Arch Linux"
  echo -e "${DIM}User: $(whoami)  ·  Host: $(hostname)${NC}"
  echo -e "${DIM}POSTINSTALL_YES=${POSTINSTALL_YES:-0}  ·  ARCH_DOCKER=${ARCH_DOCKER:-0}  ·  ARCH_LTS=${ARCH_LTS:-0}${NC}\n"

  # Core steps (always run)
  _step_update
  _step_packages
  _step_yay
  _step_pacman_config
  _step_makepkg_config
  _step_security
  _step_services
  _step_vm_support
  _step_micro
  _step_network
  _step_zsh

  # Optional steps
  if [[ "${ARCH_DOCKER:-0}" == "1" ]]; then
    _step_docker
  fi

  if [[ "${ARCH_LTS:-0}" == "1" ]]; then
    _step_lts_kernel
  fi

  step_dotfiles

  echo ""
  log_success "All automated steps complete!"
  _print_manual_steps
}

# Allow direct execution: bash scripts/linux/arch.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_install "$@"
fi
