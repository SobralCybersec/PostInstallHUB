#!/usr/bin/env bash
# =============================================================================
# scripts/linux/ubuntu.sh — Ubuntu / Ubuntu-based OS post-install setup
#
# Covers: Ubuntu · Zorin OS · Linux Mint · Pop!_OS · elementary OS ·
#         KDE Neon · and any distro with ID_LIKE=ubuntu in /etc/os-release
#
# Inspired by: github.com/mryujitanaka/Ubuntu-Post-Install-Script
#
# Called by install.sh:
#   source scripts/linux/ubuntu.sh && run_install
#
# Or run directly:
#   bash scripts/linux/ubuntu.sh
#
# Optional env flags:
#   UBUNTU_DEBLOAT=1   — remove common pre-installed bloatware (GNOME-focused)
#   UBUNTU_SNAP=1      — install Snap daemon + snap apps
#   UBUNTU_NVIDIA=1    — install NVIDIA proprietary drivers (ubuntu-drivers)
#   POSTINSTALL_YES=1  — non-interactive (skip all prompts)
# =============================================================================
set -euo pipefail

_UBUNTU_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_UBUNTU_SCRIPT_DIR}/common.sh"

# ============================================================================
# Ubuntu-based OS detection
# require_os strict-matches ID=ubuntu only; ubuntu.sh also handles distros
# where ID_LIKE contains "ubuntu" (Zorin, Mint, Pop!_OS, elementary…)
# ============================================================================
_require_ubuntu_family() {
  local id id_like
  id="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release 2>/dev/null | tr -d '"' || echo unknown)"
  id_like="$(grep -oP '(?<=^ID_LIKE=)[^\n]+' /etc/os-release 2>/dev/null | tr -d '"' || echo '')"

  if [[ "$id" == "ubuntu" ]] || echo "$id_like" | grep -qw "ubuntu" || [[ "$id" == "debian" ]] || echo "$id_like" | grep -qw "debian"; then
    log_info "Detected OS: ${id} (ID_LIKE: ${id_like:-none})"
    return 0
  fi

  log_error "Wrong OS: ubuntu.sh requires Ubuntu or an Ubuntu-based distro."
  log_error "Detected ID='${id}' ID_LIKE='${id_like}'"
  exit 5
}

# ============================================================================
# Helpers
# ============================================================================

# ppa_add PPA_NAME — idempotent add-apt-repository
ppa_add() {
  local ppa="$1"
  local ppa_list
  # Check if the PPA is already in sources
  ppa_list="$(find /etc/apt/sources.list.d/ -name "*.list" -exec grep -l "${ppa##ppa:}" {} \; 2>/dev/null || true)"
  if [[ -n "$ppa_list" ]]; then
    log_info "PPA already present: ${ppa}"
    return 0
  fi
  # Also check /etc/apt/sources.list.d/*.sources (deb822 format, Ubuntu 24+)
  if find /etc/apt/sources.list.d/ -name "*.sources" -exec grep -l "${ppa##ppa:}" {} \; 2>/dev/null | grep -q .; then
    log_info "PPA already present (deb822): ${ppa}"
    return 0
  fi
  log_info "Adding PPA: ${ppa}"
  sudo add-apt-repository -y "$ppa"
  log_success "PPA added: ${ppa}"
}

# flatpak_remote_add NAME URL — idempotent
flatpak_remote_add() {
  local name="$1" url="$2"
  if flatpak remotes 2>/dev/null | grep -q "^${name}"; then
    log_info "Flatpak remote already present: ${name}"
    return 0
  fi
  flatpak remote-add --if-not-exists "$name" "$url"
  log_success "Flatpak remote added: ${name}"
}

# flatpak_install APP_ID — idempotent
flatpak_install() {
  local app="$1"
  if flatpak list 2>/dev/null | grep -q "$app"; then
    log_info "Flatpak already installed: ${app}"
    return 0
  fi
  flatpak install -y flathub "$app"
  log_success "Flatpak installed: ${app}"
}

# snap_install PACKAGE [flags…] — idempotent
snap_install() {
  local pkg="$1"; shift
  if snap list 2>/dev/null | awk '{print $1}' | grep -qx "$pkg"; then
    log_info "Snap already installed: ${pkg}"
    return 0
  fi
  sudo snap install "$pkg" "$@"
  log_success "Snap installed: ${pkg} ${*}"
}

# apt_purge PKG — remove + purge, idempotent
apt_purge() {
  if is_pkg_installed "$1" 2>/dev/null; then
    log_info "Purging: $1"
    sudo apt-get --purge remove -y "$1" 2>/dev/null || true
  else
    log_info "Not installed (skip purge): $1"
  fi
}

# ============================================================================
# STEP 1 — System Update & Upgrade
# ============================================================================
_step_update() {
  log_step "1 · System Update & Upgrade"
  sudo apt-get update -q
  sudo apt-get install --fix-missing -y
  sudo apt-get upgrade --allow-downgrades -y
  sudo apt-get full-upgrade --allow-downgrades -y
  log_success "System up to date."
}

# ============================================================================
# STEP 2 — Debloat  (UBUNTU_DEBLOAT=1 only)
# List curated from mryujitanaka's 1.Setup.sh — Zorin/Ubuntu GNOME focus.
# Adapt for your distro — all purges are idempotent (skip if not installed).
# ============================================================================
_BLOATWARE_PKGS=(
  # GNOME helpers most users never open
  yelp gnome-logs seahorse gnome-contacts geary gnome-weather
  gucharmap simple-scan
  # Media / entertainment
  totem parole rhythmbox rhythmbox-data celluloid hypnotix
  # Games
  aisleriot gnome-mahjongg gnome-mines quadrapassel gnome-sudoku
  # Hardware/imaging tools
  lm-sensors xsane popsicle popsicle-gtk brasero
  # Audio
  xfburn exfalso quodlibet gnome-sound-recorder
  # Comms
  hexchat thunderbird
  # Misc
  hv3 xterm redshift drawing transmission webapp-manager
  cheese pitivi remmina gimp gnome-todo gnome-photos sgt-puzzles gigolo
  # Mozilla replacements (Snap version preferred or user installs own)
  firefox-esr
  # Mint-specific
  mintbackup mintreport
  # ibus input (Japanese — comment out if you need it)
  ibus-mozc mozc-utils-gui
)

_step_debloat() {
  log_step "2 · Debloat — removing pre-installed bloatware"
  log_warning "This is opt-in (UBUNTU_DEBLOAT=1). Purging ${#_BLOATWARE_PKGS[@]} packages."
  log_warning "Comment out any package you want to keep before running."

  for pkg in "${_BLOATWARE_PKGS[@]}"; do
    apt_purge "$pkg"
  done

  # Wildcard packages (must use apt-get directly — can't check with dpkg-query easily)
  for pattern in "totem*" "rhythmbox*" "librhythmbox-core*" "remmina*" "gimp*" \
                 "gnome-photos*" "sgt-puzzles*" "evolution*" "xsane*" \
                 "hexchat*" "thunderbird*" "cheese*" "brasero*" "lm-sensors*"; do
    sudo apt-get --purge remove -y "$pattern" 2>/dev/null || true
  done

  # Snap: remove Thunderbird snap if snap is available
  if is_installed snap; then
    if snap list 2>/dev/null | awk '{print $1}' | grep -qx thunderbird; then
      sudo snap remove --purge thunderbird
      log_success "Snap thunderbird removed."
    fi
  fi

  log_success "Debloat complete."
}

# ============================================================================
# STEP 3 — Flatpak + Flathub
# ============================================================================
_step_flatpak() {
  log_step "3 · Flatpak + Flathub"

  apt_install flatpak

  # GNOME Software plugin (only if gnome-software is present)
  if is_pkg_installed gnome-software; then
    apt_install gnome-software-plugin-flatpak
  fi

  flatpak_remote_add flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  log_success "Flathub enabled."
}

# ============================================================================
# STEP 4 — Snap (UBUNTU_SNAP=1 only)
# ============================================================================
_step_snap() {
  log_step "4 · Snap Daemon"
  apt_install snapd
  sudo systemctl enable --now snapd.socket 2>/dev/null || true
  # Create /snap symlink (needed on some distros)
  if [[ ! -L /snap ]] && [[ ! -d /snap ]]; then
    sudo ln -s /var/lib/snapd/snap /snap
    log_success "/snap symlink created."
  fi
  log_success "Snap daemon ready."
}

# ============================================================================
# STEP 5 — System Backup (Timeshift)
# ============================================================================
_step_timeshift() {
  log_step "5 · System Backup — Timeshift"
  apt_install timeshift
  log_success "Timeshift installed."
  log_info "Configure your first snapshot via: sudo timeshift-gtk"
  log_info "  or: sudo timeshift --create --comments 'Post-install baseline'"
}

# ============================================================================
# STEP 6 — PPAs + apt packages
# PPAs are idempotent via ppa_add().
# ============================================================================
_PPA_LIST=(
  "ppa:zhangsongcui3371/fastfetch"   # Fastfetch — fast neofetch replacement
  "ppa:danielrichter2007/grub-customizer"  # Grub Customizer
  "ppa:papirus/papirus"              # Papirus icon theme
  "ppa:git-core/ppa"                 # Latest stable Git
  "ppa:sebastian-stenzel/cryptomator" # Cryptomator
  "ppa:phoerious/keepassxc"          # KeePassXC
)

_PPA_PACKAGES=(
  fastfetch          # Fast system info (neofetch replacement)
  grub-customizer    # GUI for GRUB settings
  papirus-icon-theme # Papirus icon theme
  qbittorrent        # BitTorrent client
  git                # Version control
  cryptomator        # Client-side encryption for cloud
  keepassxc          # Password manager
)

_APT_PACKAGES=(
  synaptic                # Graphical package manager
  adb                     # Android Debug Bridge
  inetutils-traceroute    # traceroute
  curl                    # HTTP client
  wget                    # File downloader
  blueman                 # Bluetooth manager (GTK)
  fuse3                   # FUSE3 (Cryptomator dependency)
)

_step_ppa_apps() {
  log_step "6 · PPAs + apt Applications"

  # 6a — Core apt packages (no PPA needed)
  log_info "Installing core apt packages..."
  apt_install "${_APT_PACKAGES[@]}"

  # 6b — Add PPAs
  log_info "Adding PPAs..."
  for ppa in "${_PPA_LIST[@]}"; do
    ppa_add "$ppa"
  done

  # 6c — Update after PPAs
  sudo apt-get update -qq

  # 6d — Install PPA-sourced packages
  log_info "Installing PPA packages..."
  apt_install "${_PPA_PACKAGES[@]}"

  log_success "apt + PPA packages installed."
}

# ============================================================================
# STEP 7 — Flatpak apps
# ============================================================================
_FLATPAK_APPS=(
  "org.gnome.baobab"                  # Disk Usage Analyzer
  "org.torproject.torbrowser-launcher" # Tor Browser
  "org.gimp.GIMP"                     # Image editor
  "com.obsproject.Studio"             # Screen recorder / streaming
)

# Optional — uncomment to include:
# "org.qbittorrent.qBittorrent"
# "com.discordapp.Discord"
# "org.audacityteam.Audacity"
# "org.filezillaproject.Filezilla"
# "us.zoom.Zoom"
# "org.chromium.Chromium"

_step_flatpak_apps() {
  log_step "7 · Flatpak Applications"

  for app in "${_FLATPAK_APPS[@]}"; do
    flatpak_install "$app"
  done

  log_success "Flatpak apps installed."
}

# ============================================================================
# STEP 8 — Snap apps (UBUNTU_SNAP=1 only)
# ============================================================================
_step_snap_apps() {
  log_step "8 · Snap Applications"

  snap_install htop
  snap_install flameshot
  snap_install vlc
  # snap_install intellij-idea-community --classic  # uncomment if needed

  log_success "Snap apps installed."
}

# ============================================================================
# STEP 9 — System + package manager cleanup
# ============================================================================
_step_cleanup() {
  log_step "9 · Cleanup"

  # apt
  sudo apt-get install -f -y 2>/dev/null || true
  sudo apt-get autoremove -y
  sudo apt-get autoclean
  sudo apt-get clean

  # Flatpak
  flatpak update -y 2>/dev/null || true
  flatpak uninstall --delete-data -y 2>/dev/null || true
  flatpak uninstall --unused -y 2>/dev/null || true

  # Snap (if present)
  if is_installed snap; then
    sudo snap refresh 2>/dev/null || true
    sudo rm -rf /var/lib/snapd/cache/* 2>/dev/null || true
  fi

  log_success "System clean."
}

# ============================================================================
# Manual steps banner
# ============================================================================
_print_manual_steps() {
  cat << 'MANUAL'

╔══════════════════════════════════════════════════════════════════╗
║         MANUAL STEPS — complete these yourself                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  REBOOT — recommended after a full upgrade                      ║
║    systemctl reboot                                              ║
║                                                                  ║
║  TIMESHIFT — create your first snapshot                         ║
║    sudo timeshift --create --comments "Post-install baseline"    ║
║                                                                  ║
║  BROWSER                                                         ║
║    Chrome:  wget -c https://dl.google.com/linux/direct/          ║
║             google-chrome-stable_current_amd64.deb               ║
║             sudo dpkg -i google-chrome*.deb                      ║
║    Brave:   flatpak install flathub com.brave.Browser            ║
║                                                                  ║
║  NVIDIA (if UBUNTU_NVIDIA=1 was not set)                        ║
║    ubuntu-drivers devices                                        ║
║    sudo ubuntu-drivers autoinstall                               ║
║    # or select version: sudo apt install nvidia-driver-570       ║
║                                                                  ║
║  GRUB CUSTOMIZER — set theme / resolution                       ║
║    grub-customizer  (launch from app menu)                       ║
║                                                                  ║
║  PAPIRUS ICON THEME — apply in appearance settings              ║
║    GNOME: gnome-tweaks → Appearance → Icons → Papirus            ║
║    XFCE:  xfce4-appearance-settings                             ║
║                                                                  ║
║  CRYPTOMATOR — add your cloud vault                             ║
║    cryptomator  (launch from app menu)                           ║
║                                                                  ║
║  KEEPASSXC — create or open your password database              ║
║    keepassxc                                                     ║
║                                                                  ║
║  ZORIN OS — pinned Flatpak runtimes error fix                   ║
║    flatpak pin --remove runtime/org.gtk.Gtk3theme.<Name>/…      ║
║    See: reddit.com/r/flatpak/comments/zx1ilh                    ║
║         askubuntu.com/questions/1488710                          ║
║                                                                  ║
║  SNAP INTELLIJ (optional)                                        ║
║    sudo snap install intellij-idea-community --classic           ║
║                                                                  ║
║  TERMINAL UNLIMITED SCROLLBACK                                  ║
║    GNOME Terminal: Edit → Preferences → [profile] → Scrolling   ║
║    → Uncheck "Limit scrollback to N lines"                       ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
MANUAL
}

# ============================================================================
# STEP (optional) — NVIDIA drivers
# ============================================================================
_step_nvidia() {
  log_step "(opt) · NVIDIA Drivers"
  apt_install ubuntu-drivers-common
  log_info "Detecting NVIDIA driver..."
  sudo ubuntu-drivers devices 2>/dev/null || true
  sudo ubuntu-drivers autoinstall
  log_success "NVIDIA drivers installed."
  log_warning "Reboot required for driver to take effect."
}

# ============================================================================
# run_install — orchestrator (called by install.sh)
# ============================================================================
run_install() {
  _require_ubuntu_family
  check_sudo

  local id
  id="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release 2>/dev/null | tr -d '"' || echo ubuntu)"

  log_step "PostInstallHUB · Ubuntu / ${id}"
  echo -e "${DIM}User: $(whoami)  ·  Host: $(hostname)${NC}"
  echo -e "${DIM}POSTINSTALL_YES=${POSTINSTALL_YES:-0}  ·  UBUNTU_DEBLOAT=${UBUNTU_DEBLOAT:-0}  ·  UBUNTU_SNAP=${UBUNTU_SNAP:-0}  ·  UBUNTU_NVIDIA=${UBUNTU_NVIDIA:-0}${NC}\n"

  # Always run
  _step_update
  _step_flatpak
  _step_timeshift
  _step_ppa_apps
  _step_flatpak_apps
  _step_cleanup

  # Opt-in: debloat
  if [[ "${UBUNTU_DEBLOAT:-0}" == "1" ]]; then
    _step_debloat
  else
    log_info "Debloat skipped (set UBUNTU_DEBLOAT=1 to enable)."
  fi

  # Opt-in: snap
  if [[ "${UBUNTU_SNAP:-0}" == "1" ]]; then
    _step_snap
    _step_snap_apps
  else
    log_info "Snap skipped (set UBUNTU_SNAP=1 to enable)."
  fi

  # Opt-in: NVIDIA
  if [[ "${UBUNTU_NVIDIA:-0}" == "1" ]]; then
    _step_nvidia
  fi

  echo ""
  log_success "All automated steps complete!"
  _print_manual_steps
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_install "$@"
fi
