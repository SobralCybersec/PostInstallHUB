#!/usr/bin/env bash
# =============================================================================
# scripts/linux/endeavour.sh — EndeavourOS / CachyOS post-install setup
#
# Supports Arch-family distros: EndeavourOS, CachyOS, Arch, Manjaro, Garuda
#
# Based on:
#   https://raw.githubusercontent.com/BrandowLucas/Post-Install-Script/refs/heads/main/PostInstallScript.sh
#
# Called by install.sh:
#   source scripts/linux/endeavour.sh && run_install
#
# Or run directly:
#   bash scripts/linux/endeavour.sh
#   ENDEAVOUR_GAMING=1 POSTINSTALL_YES=1 bash scripts/linux/endeavour.sh
#
# Optional env flags:
#   ENDEAVOUR_PLYMOUTH=1  — install + configure Plymouth boot splash
#   ENDEAVOUR_WAYDROID=1  — install Waydroid (Android container)
#   ENDEAVOUR_GAMING=1    — install Steam, Lutris, gamemode, GPU drivers
#   ENDEAVOUR_FISH=1      — configure fisher plugin manager for fish
#   ENDEAVOUR_ZRAM=1      — zram compressed swap + earlyoom OOM killer
#   POSTINSTALL_YES=1     — non-interactive (skip all prompts); skips dotfiles
#   POSTINSTALL_DOTFILES=none|jakoolit|caelestia
#     jakoolit   — Hyprland desktop (LinuxBeginnings/Hyprland-Dots, Arch-supported)
#     caelestia  — Quickshell Hyprland desktop (yay: caelestia-shell-git, preferred)
# =============================================================================
set -euo pipefail

_ENDEAVOUR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_ENDEAVOUR_SCRIPT_DIR}/common.sh"
source "${_ENDEAVOUR_SCRIPT_DIR}/dotfiles.sh"
source "${_ENDEAVOUR_SCRIPT_DIR}/../lib/shells.sh"

# ============================================================================
# OS family guard — require Arch-based distro
# (require_os does exact match, so we write our own family check)
# ============================================================================
_require_arch_family() {
  local actual
  actual="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release 2>/dev/null |
    tr -d '"' || echo unknown)"
  case "$actual" in
    arch | endeavouros | cachyos | manjaro | garuda)
      log_info "OS detected: ${actual} (Arch family — OK)"
      ;;
    *)
      log_error "Wrong OS family: got '${actual}'." \
        "Expected one of: arch, endeavouros, cachyos, manjaro, garuda."
      exit 5
      ;;
  esac
}

# Returns 0 (true) if running on Manjaro
_is_manjaro() {
  local id
  id="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release 2>/dev/null |
    tr -d '"' || echo unknown)"
  [[ "$id" == "manjaro" ]]
}

# ============================================================================
# Pacman / AUR helpers
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
  [[ ${#to_install[@]} -eq 0 ]] && return 0
  log_info "pacman installing: ${to_install[*]}"
  local nc="--noconfirm"
  [[ "${POSTINSTALL_YES:-0}" != "1" ]] && nc=""
  # shellcheck disable=SC2086
  sudo pacman -S --needed ${nc} "${to_install[@]}"
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
  [[ ${#to_install[@]} -eq 0 ]] && return 0
  log_info "yay installing: ${to_install[*]}"
  yay -S --needed --noconfirm "${to_install[@]}"
}

# service_enable_now SVC — enable+start only if not already enabled
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
  log_step "1 · System Update"

  log_info "Refreshing archlinux-keyring first (avoids signature errors)..."
  sudo pacman -S --needed --noconfirm archlinux-keyring

  log_info "Running full system upgrade (pacman -Syu)..."
  local nc="--noconfirm"
  [[ "${POSTINSTALL_YES:-0}" != "1" ]] && nc=""
  # shellcheck disable=SC2086
  sudo pacman -Syu ${nc}

  log_success "System up to date."
}

# ============================================================================
# STEP 2 — Mirror Optimisation
#   Manjaro: pacman-mirrors --fasttrack
#   All others: reflector — skipped if mirrorlist touched within last 24 h
# ============================================================================
_step_mirrors() {
  log_step "2 · Mirror Optimisation"

  if _is_manjaro; then
    log_info "Manjaro detected — using pacman-mirrors --fasttrack"
    if ! is_installed pacman-mirrors; then
      log_warning "pacman-mirrors not found — skipping."
      return 0
    fi
    sudo pacman-mirrors --fasttrack
    sudo pacman -Syy --noconfirm
    log_success "Manjaro mirrors updated."
    return 0
  fi

  # Non-Manjaro: use reflector
  if ! is_installed reflector; then
    pacman_install reflector
  fi

  # Skip if mirrorlist was already updated today (< 86400 s ago)
  local mirrorlist="/etc/pacman.d/mirrorlist"
  if [[ -f "$mirrorlist" ]]; then
    local mtime now age
    mtime="$(stat -c %Y "$mirrorlist")"
    now="$(date +%s)"
    age=$((now - mtime))
    if ((age < 86400)); then
      log_info "Mirrorlist updated less than 24 h ago (${age}s) — skipping reflector."
      return 0
    fi
  fi

  log_info "Running reflector to find fastest HTTPS mirrors..."
  sudo reflector \
    --protocol https \
    --latest 20 \
    --sort rate \
    --save "$mirrorlist"

  sudo pacman -Syy --noconfirm
  log_success "Mirrorlist updated via reflector."
}

# ============================================================================
# STEP 3 — yay AUR helper
# ============================================================================
_step_yay() {
  log_step "3 · yay AUR Helper"

  if is_installed yay; then
    log_info "yay already installed: $(yay --version 2>/dev/null | head -1)"
    return 0
  fi

  pacman_install git base-devel

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '${tmp_dir}'" RETURN

  log_info "Cloning yay from AUR..."
  git clone --depth=1 https://aur.archlinux.org/yay.git "${tmp_dir}/yay"

  log_info "Building yay (makepkg as current user — must not be root)..."
  pushd "${tmp_dir}/yay" >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null

  yay --save --removemake --cleanafter --sudoloop
  log_success "yay installed: $(yay --version 2>/dev/null | head -1)"
}

# ============================================================================
# STEP 4 — Chaotic-AUR repository
# ============================================================================
_step_chaotic_aur() {
  log_step "4 · Chaotic-AUR Repository"

  local conf="/etc/pacman.conf"

  if grep -qF "[chaotic-aur]" "$conf" 2>/dev/null; then
    log_info "Chaotic-AUR already present in ${conf} — skipping."
    return 0
  fi

  log_info "Importing Chaotic-AUR signing key from keyserver.ubuntu.com..."
  sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
  sudo pacman-key --lsign-key 3056513887B78AEB

  log_info "Installing chaotic-keyring + chaotic-mirrorlist packages..."
  sudo pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
  sudo pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

  log_info "Appending [chaotic-aur] section to ${conf}..."
  sudo cp "$conf" "${conf}.postinstallhub.bak"
  printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' |
    sudo tee -a "$conf" >/dev/null

  sudo pacman -Syy --noconfirm
  log_success "Chaotic-AUR repository added and database synced."
}

# ============================================================================
# STEP 5 — UFW Firewall
# ============================================================================
_step_ufw() {
  log_step "5 · UFW Firewall"

  pacman_install ufw

  # Enable UFW (--force skips the interactive "y/n" prompt)
  if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    log_info "UFW already active."
  else
    sudo ufw --force enable
    log_success "UFW enabled."
  fi

  # Helper: add rule only if not already present in verbose status
  _ufw_allow_once() {
    local rule="$1"
    if sudo ufw status verbose 2>/dev/null | grep -qF "$rule"; then
      log_info "UFW rule already present: ${rule}"
    else
      # shellcheck disable=SC2086
      sudo ufw allow ${rule}
      log_success "UFW rule added: ${rule}"
    fi
  }

  _ufw_allow_once "ssh"
  _ufw_allow_once "1714:1764/udp"   # KDE Connect
  _ufw_allow_once "1714:1764/tcp"   # KDE Connect
  _ufw_allow_once "42000:42001/udp" # Warpinator
  _ufw_allow_once "42000:42001/tcp" # Warpinator

  service_enable_now ufw.service
  log_success "UFW configured: SSH, KDE Connect (1714:1764), Warpinator (42000:42001)."
}

# ============================================================================
# STEP 6 — ZSH + oh-my-zsh + plugins
# ============================================================================
ZSH_CONFIG_FILE="${HOME}/.zshrc"
ZSH_CUSTOM="${HOME}/.oh-my-zsh/custom"

_step_zsh() {
  log_step "6 · ZSH + oh-my-zsh"

  pacman_install zsh

  # Set as default shell if not already zsh
  local current_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current_shell" == *"/zsh" ]]; then
    log_info "ZSH already the default shell: ${current_shell}"
  else
    log_info "Changing default shell to zsh (chsh)..."
    chsh -s "$(command -v zsh)"
    log_success "Default shell → zsh (takes effect on next login)."
  fi

  # Install oh-my-zsh if ~/.oh-my-zsh doesn't exist
  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    log_info "oh-my-zsh already installed at ~/.oh-my-zsh"
  else
    log_info "Installing oh-my-zsh (unattended)..."
    RUNZSH=no CHSH=no \
      sh -c "$(curl -fsSL \
        https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    log_success "oh-my-zsh installed."
  fi

  # zsh-autosuggestions — prefer AUR package, fall back to git clone
  local autosug_dir="${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
  if [[ -d "$autosug_dir" ]] || pacman -Qi zsh-autosuggestions &>/dev/null; then
    log_info "zsh-autosuggestions already present."
  else
    if is_installed yay; then
      yay_install zsh-autosuggestions
    else
      git clone --depth=1 \
        https://github.com/zsh-users/zsh-autosuggestions.git \
        "$autosug_dir"
      log_success "zsh-autosuggestions cloned to ${autosug_dir}"
    fi
  fi

  # zsh-syntax-highlighting — prefer AUR package, fall back to git clone
  local synhi_dir="${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
  if [[ -d "$synhi_dir" ]] || pacman -Qi zsh-syntax-highlighting &>/dev/null; then
    log_info "zsh-syntax-highlighting already present."
  else
    if is_installed yay; then
      yay_install zsh-syntax-highlighting
    else
      git clone --depth=1 \
        https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "$synhi_dir"
      log_success "zsh-syntax-highlighting cloned to ${synhi_dir}"
    fi
  fi

  # Enable plugins in ZSH_CONFIG_FILE
  local zshrc="${ZSH_CONFIG_FILE}"
  if [[ -f "$zshrc" ]]; then
    if grep -qF "zsh-autosuggestions" "$zshrc"; then
      log_info "${zshrc}: plugins already configured."
    elif grep -qE '^plugins=\(' "$zshrc"; then
      backup_warning "$zshrc"
      # Append into existing plugins=(...) line
      sed -i \
        's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/' \
        "$zshrc"
      log_success "${zshrc}: zsh-autosuggestions + zsh-syntax-highlighting added to plugins."
    else
      append_once "# PostInstallHUB — ZSH plugins" "$zshrc" \
        "# PostInstallHUB — ZSH plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)"
    fi
  else
    log_warning "${zshrc} not found — oh-my-zsh may not have created it yet."
  fi

  log_success "ZSH + oh-my-zsh configured. Re-login to activate."
}

# ============================================================================
# STEP 7 — Fish shell
#   Delegates full setup to lib/shells.sh::setup_fish().
#   setup_fish() handles: install → /etc/shells → chsh → fisher → plugins →
#   ~/.config/fish/conf.d/postinstallhub.fish
#
#   The chsh + full plugin setup only runs when ENDEAVOUR_FISH=1; when the
#   flag is off we still install the package and register it in /etc/shells so
#   the user can switch manually, matching the original behaviour.
# ============================================================================
_step_fish() {
  if [[ "${ENDEAVOUR_FISH:-0}" == "1" ]]; then
    # Full setup: install + chsh + fisher + plugins + config
    setup_fish
  else
    # Minimal: install fish + register in /etc/shells only
    log_step "7 · Fish Shell (install only — set ENDEAVOUR_FISH=1 for full setup)"
    pacman_install fish
    local fish_path
    fish_path="$(command -v fish)"
    if grep -qF "$fish_path" /etc/shells 2>/dev/null; then
      log_info "fish already in /etc/shells."
    else
      echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
      log_success "fish added to /etc/shells: ${fish_path}"
    fi
    log_success "Fish shell ready."
    log_info "To set fish as default: chsh -s ${fish_path}"
    log_info "For full fisher + plugin setup, re-run with ENDEAVOUR_FISH=1."
  fi
}

# ============================================================================
# STEP 8 — Essential packages
# ============================================================================
_ENDEAVOUR_PACKAGES=(
  btop htop
  fastfetch
  git vim neovim
  tmux
  curl wget unzip p7zip
  ark dolphin kate konsole ghostty
  yt-dlp aria2
  flameshot
  keepassxc
)

_step_packages() {
  log_step "8 · Essential Packages"
  pacman_install "${_ENDEAVOUR_PACKAGES[@]}"
  log_success "Essential packages installed."
}

# ============================================================================
# STEP 9 — Flatpak + Flathub
# ============================================================================
_FLATPAK_APPS=(
  com.brave.Browser
  com.discordapp.Discord
  com.spotify.Client
  org.videolan.VLC
  com.obsproject.Studio
  md.obsidian.Obsidian
)

_step_flatpak() {
  log_step "9 · Flatpak + Flathub"

  pacman_install flatpak

  if flatpak remotes 2>/dev/null | grep -q "^flathub"; then
    log_info "Flathub remote already configured."
  else
    sudo flatpak remote-add --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo
    log_success "Flathub remote added."
  fi

  local app
  for app in "${_FLATPAK_APPS[@]}"; do
    if flatpak list --app 2>/dev/null | grep -qF "$app"; then
      log_info "Flatpak already installed: ${app}"
    else
      log_info "Installing Flatpak app: ${app}"
      sudo flatpak install -y flathub "$app" 2>/dev/null &&
        log_success "Installed: ${app}" ||
        log_warning "Failed to install ${app} — skipping."
    fi
  done

  log_success "Flatpak + Flathub configured."
}

# ============================================================================
# STEP 10 — Plymouth boot splash  (ENDEAVOUR_PLYMOUTH=1)
# ============================================================================
_step_plymouth() {
  log_step "10 · Plymouth Boot Splash (ENDEAVOUR_PLYMOUTH=1)"

  pacman_install plymouth

  # Add 'plymouth' hook to /etc/mkinitcpio.conf (after 'udev')
  local mkinit="/etc/mkinitcpio.conf"
  if grep -qF "plymouth" "$mkinit" 2>/dev/null; then
    log_info "plymouth already present in mkinitcpio.conf HOOKS."
  else
    sudo cp "$mkinit" "${mkinit}.postinstallhub.bak"
    sudo sed -i 's/\(HOOKS=.*\)udev/\1udev plymouth/' "$mkinit"
    log_success "plymouth added to mkinitcpio.conf HOOKS."
  fi

  # GRUB: add 'quiet splash' to GRUB_CMDLINE_LINUX_DEFAULT
  local grub_conf="/etc/default/grub"
  if [[ -f "$grub_conf" ]]; then
    if grep -qF "splash" "$grub_conf" 2>/dev/null; then
      log_info "GRUB_CMDLINE_LINUX_DEFAULT already contains 'splash'."
    else
      sudo cp "$grub_conf" "${grub_conf}.postinstallhub.bak"
      sudo sed -i \
        's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 quiet splash"/' \
        "$grub_conf"
      log_success "GRUB_CMDLINE_LINUX_DEFAULT: appended 'quiet splash'."
      if is_installed grub-mkconfig; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        log_success "grub.cfg regenerated."
      fi
    fi
  else
    log_warning "${grub_conf} not found — may use systemd-boot; add 'quiet splash' to kernel options manually."
  fi

  # Regenerate initramfs
  sudo mkinitcpio -P
  log_success "Plymouth installed. Reboot to see the boot splash."
}

# ============================================================================
# STEP 11 — Waydroid  (ENDEAVOUR_WAYDROID=1)
# ============================================================================
_step_waydroid() {
  log_step "11 · Waydroid (Android Container) (ENDEAVOUR_WAYDROID=1)"

  if is_installed waydroid; then
    log_info "waydroid already installed."
  else
    if is_installed yay; then
      yay_install waydroid
    else
      log_error "yay not found — cannot install waydroid from AUR. Run _step_yay first."
      return 1
    fi
  fi

  service_enable_now waydroid-container.service

  # Initialise Waydroid image if not already done
  if [[ -f /var/lib/waydroid/images/system.img ]]; then
    log_info "Waydroid already initialised (system.img present)."
  else
    if [[ "${POSTINSTALL_YES:-0}" == "1" ]]; then
      sudo waydroid init
      log_success "Waydroid initialised."
    else
      echo -e "Initialise Waydroid now? (~800 MB Android image download) [y/N]"
      read -r _wyd_yn
      if [[ "${_wyd_yn:-N}" =~ ^[Yy]$ ]]; then
        sudo waydroid init
        log_success "Waydroid initialised."
      else
        log_info "Skipped waydroid init — run 'sudo waydroid init' later."
      fi
    fi
  fi

  log_success "Waydroid ready."
  log_info "Start: waydroid session start && waydroid show-full-ui"
}

# ============================================================================
# STEP 12 — Gaming  (ENDEAVOUR_GAMING=1)
# ============================================================================
_step_gaming() {
  log_step "12 · Gaming Stack (ENDEAVOUR_GAMING=1)"

  # Auto-detect GPU
  local gpu="unknown"
  if command -v lspci &>/dev/null; then
    lspci 2>/dev/null | grep -qiE 'amd|radeon' && gpu="amd"
    lspci 2>/dev/null | grep -qi nvidia && gpu="nvidia"
    lspci 2>/dev/null | grep -qiE 'intel.*graphics|intel.*uhd' && gpu="intel"
  fi
  log_info "GPU detected: ${gpu}"

  # GPU-specific drivers (lib32 requires [multilib])
  case "$gpu" in
    amd)
      pacman_install lib32-mesa vulkan-radeon lib32-vulkan-radeon \
        vulkan-icd-loader lib32-vulkan-icd-loader
      log_success "AMD Vulkan + lib32 drivers installed."
      ;;
    nvidia)
      pacman_install nvidia-utils lib32-nvidia-utils
      log_success "NVIDIA utils installed."
      ;;
    intel)
      pacman_install vulkan-intel lib32-vulkan-intel
      log_success "Intel Vulkan drivers installed."
      ;;
    *)
      log_warning "Unknown GPU — skipping GPU-specific Vulkan drivers."
      ;;
  esac

  # Warn if [multilib] isn't enabled (needed for lib32 packages + Steam)
  if ! grep -qF "[multilib]" /etc/pacman.conf 2>/dev/null; then
    log_warning "[multilib] not in /etc/pacman.conf — uncomment it, run 'sudo pacman -Sy', then re-run."
  fi

  pacman_install steam lutris gamemode lib32-gamemode mangohud

  log_success "Gaming stack installed: steam, lutris, gamemode, lib32-gamemode, mangohud."
  log_info "Enable Proton: Steam → Settings → Compatibility → Enable Steam Play for all titles."
}

# ============================================================================
# STEP 13 — zram + earlyoom (optional — set ENDEAVOUR_ZRAM=1 to run)
# ============================================================================
_step_zram() {
  log_step "13 · zram + earlyoom (ENDEAVOUR_ZRAM=1)"

  # zram-generator — compressed in-RAM swap managed by systemd
  pacman_install zram-generator \
    || { log_warning "zram-generator install failed — skipping zram setup."; return 0; }

  local zram_conf="/etc/systemd/zram-generator.conf"
  if [[ -f "$zram_conf" ]] && grep -q '\[zram0\]' "$zram_conf"; then
    log_info "zram-generator: ${zram_conf} already configured."
  else
    sudo tee "$zram_conf" >/dev/null <<'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
EOF
    log_success "zram-generator: configured (ram/2, zstd, priority 100)."
  fi

  # Activate without reboot
  if ! swapon --show 2>/dev/null | grep -q zram; then
    sudo systemctl start systemd-zram-setup@zram0.service 2>/dev/null \
      || log_warning "zram service start failed — will activate on next boot."
  else
    log_info "zram swap: already active."
  fi

  # Recommended sysctl tuning for zram (per zram-generator upstream docs)
  local sysctl_conf="/etc/sysctl.d/99-zram.conf"
  if [[ ! -f "$sysctl_conf" ]]; then
    sudo tee "$sysctl_conf" >/dev/null <<'EOF'
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF
    sudo sysctl --system &>/dev/null \
      || log_warning "sysctl --system failed — reboot to apply zram tuning."
    log_success "zram sysctl tuning applied (swappiness=180)."
  else
    log_info "zram sysctl: ${sysctl_conf} already present — skipped."
  fi

  # earlyoom — kills worst-offender process before kernel OOM fires
  pacman_install earlyoom \
    && { service_enable_now earlyoom.service \
         || log_warning "earlyoom.service enable failed — run: sudo systemctl enable --now earlyoom"; } \
    || log_warning "earlyoom install failed — continuing without it."

  log_success "zram + earlyoom configured."
}

# ============================================================================
# Manual steps banner
# ============================================================================
_print_manual_steps() {
  cat <<'MANUAL'

╔══════════════════════════════════════════════════════════════════╗
║         MANUAL STEPS — complete these yourself                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  RE-LOGIN — needed for: zsh shell, UFW, sudo group              ║
║                                                                  ║
║  ZSH — open a new terminal to activate oh-my-zsh               ║
║    If plugins don't load: source ~/.zshrc                        ║
║                                                                  ║
║  FISH — set as default shell manually if desired:               ║
║    chsh -s $(which fish)                                         ║
║                                                                  ║
║  REFLECTOR — set your nearest country codes:                    ║
║    sudo nano /etc/xdg/reflector/reflector.conf                   ║
║    Change: --country US,DE,FR → your nearest countries           ║
║    sudo systemctl start reflector.service                        ║
║                                                                  ║
║  GAMING — enable [multilib] if not done:                        ║
║    sudo nano /etc/pacman.conf   (uncomment [multilib] + Include) ║
║    sudo pacman -Sy                                               ║
║    Steam → Settings → Compatibility → Enable Steam Play          ║
║                                                                  ║
║  WAYDROID (if installed):                                        ║
║    waydroid session start && waydroid show-full-ui               ║
║                                                                  ║
║  PLYMOUTH — reboot to see splash screen                         ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
MANUAL
}

# ============================================================================
# run_install — orchestrator (called by install.sh)
# ============================================================================
run_install() {
  _require_arch_family
  check_sudo

  log_step "PostInstallHUB · EndeavourOS / CachyOS"
  echo -e "${DIM}User: $(whoami)  ·  Host: $(hostname)${NC}"
  echo -e "${DIM}POSTINSTALL_YES=${POSTINSTALL_YES:-0}  ·  ENDEAVOUR_GAMING=${ENDEAVOUR_GAMING:-0}  ·  ENDEAVOUR_PLYMOUTH=${ENDEAVOUR_PLYMOUTH:-0}${NC}"
  echo -e "${DIM}ENDEAVOUR_WAYDROID=${ENDEAVOUR_WAYDROID:-0}  ·  ENDEAVOUR_FISH=${ENDEAVOUR_FISH:-0}  ·  ENDEAVOUR_ZRAM=${ENDEAVOUR_ZRAM:-0}${NC}\n"

  # Core steps — always run
  _step_update
  _step_mirrors
  _step_yay
  _step_chaotic_aur
  _step_ufw
  _step_zsh
  _step_fish
  _step_packages
  _step_flatpak

  # Optional steps — gated by env flags
  if [[ "${ENDEAVOUR_PLYMOUTH:-0}" == "1" ]]; then
    _step_plymouth
  fi

  if [[ "${ENDEAVOUR_WAYDROID:-0}" == "1" ]]; then
    _step_waydroid
  fi

  if [[ "${ENDEAVOUR_GAMING:-0}" == "1" ]]; then
    _step_gaming
  fi

  if [[ "${ENDEAVOUR_ZRAM:-0}" == "1" ]]; then
    _step_zram
  fi

  step_dotfiles

  echo ""
  log_success "All automated steps complete!"
  _print_manual_steps
}

# Allow direct execution: bash scripts/linux/endeavour.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_install "$@"
fi
