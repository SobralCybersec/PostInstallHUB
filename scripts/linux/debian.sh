#!/usr/bin/env bash
# =============================================================================
# scripts/linux/debian.sh — Debian 13 Trixie post-install setup
#
# Workstation profile: video editing · photography · web content creation
# Default DE: KDE Plasma (adjust flatpak backend if using GNOME)
#
# Based on: github.com/eddiecsilva/debian-post-install
#
# Called by install.sh:
#   source scripts/linux/debian.sh && run_install
#
# Or run directly:
#   bash scripts/linux/debian.sh
#
# Optional env flags:
#   DEBIAN_NVIDIA=1        — install NVIDIA open driver (nvidia-open)
#   DEBIAN_NVIDIA_CUDA=1   — install full CUDA toolkit (implies DEBIAN_NVIDIA=1)
#   DEBIAN_GAMING=1        — install Steam · Heroic · MangoJuice via Flatpak
#   DEBIAN_DEBLOAT=1       — remove LibreOffice, KMail, Juk, Dragon, etc.
#   DEBIAN_ZSWAP=1         — enable ZSWAP kernel parameter (systemd-boot)
#   POSTINSTALL_YES=1      — non-interactive, skip all prompts; skips dotfiles
#   POSTINSTALL_DOTFILES=none|jakoolit|caelestia
#     jakoolit   — Hyprland desktop (LinuxBeginnings/Hyprland-Dots, Debian-supported)
#     caelestia  — Quickshell Hyprland desktop (via Nix flake)
# =============================================================================
set -euo pipefail

_DEBIAN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_DEBIAN_SCRIPT_DIR}/common.sh"
source "${_DEBIAN_SCRIPT_DIR}/dotfiles.sh"

# ============================================================================
# Helpers
# ============================================================================

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

# ufw_allow_idempotent RULE — only adds if not already present
ufw_allow_idempotent() {
  local rule="$1"
  if sudo ufw status 2>/dev/null | grep -qF "${rule%%/*}"; then
    log_info "UFW rule already exists: ${rule}"
    return 0
  fi
  sudo ufw allow $rule
  log_success "UFW rule added: ${rule}"
}

# deb822_source_write PATH CONTENT — writes /etc/apt/sources.list.d/*.sources idempotently
deb822_source_write() {
  local path="$1"
  shift
  if [[ -f "$path" ]]; then
    log_info "apt source already exists: ${path}"
    return 0
  fi
  sudo tee "$path" >/dev/null <<"EOF"
$*
EOF
  log_success "apt source written: ${path}"
}

# ============================================================================
# STEP 1 — System Update
# ============================================================================
_step_update() {
  log_step "1 · System Update"
  sudo apt-get update -q
  sudo apt-get upgrade -y
  sudo apt-get full-upgrade -y
  log_success "System up to date."
}

# ============================================================================
# STEP 2 — UFW Firewall
# Ports: KDEConnect · Touch Portal · Warpinator
# ============================================================================
_step_ufw() {
  log_step "2 · UFW Firewall"

  apt_install ufw

  # Enable if not already active
  if ! sudo ufw status | grep -q "Status: active"; then
    sudo ufw enable
    log_success "UFW enabled."
  else
    log_info "UFW already active."
  fi

  # KDEConnect — file/clipboard sharing between phone and desktop
  ufw_allow_idempotent "1714:1764/udp"
  ufw_allow_idempotent "1714:1764/tcp"

  # Touch Portal — stream deck alternative
  ufw_allow_idempotent "12135/tcp"

  # Warpinator — LAN file transfer (GNOME/KDE)
  ufw_allow_idempotent "42000:42001/udp"
  ufw_allow_idempotent "42000:42001/tcp"

  sudo ufw status numbered
  log_success "UFW configured."
}

# ============================================================================
# STEP 3 — DebMultimedia Repository
# Third-party repo with codecs + FFMPEG hw-accel (not in official Debian)
# Keyring: deb-multimedia-keyring_2024.9.1_all.deb
# ============================================================================
_DMO_KEYRING_URL="https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2024.9.1_all.deb"
_DMO_KEYRING_DEB="/tmp/deb-multimedia-keyring.deb"
_DMO_SOURCE="/etc/apt/sources.list.d/dmo.sources"

_step_debmultimedia() {
  log_step "3 · DebMultimedia Repository"

  if [[ -f "$_DMO_SOURCE" ]]; then
    log_info "DebMultimedia already configured at ${_DMO_SOURCE}."
    return 0
  fi

  log_info "Downloading DebMultimedia keyring..."
  wget -qO "$_DMO_KEYRING_DEB" "$_DMO_KEYRING_URL"
  sudo dpkg -i "$_DMO_KEYRING_DEB"
  rm -f "$_DMO_KEYRING_DEB"
  log_success "DebMultimedia keyring installed."

  log_info "Writing dmo.sources (DEB822)..."
  sudo tee "$_DMO_SOURCE" >/dev/null <<'DMO'
Types: deb
URIs: https://www.deb-multimedia.org
Suites: trixie
Components: main non-free
Signed-By: /usr/share/keyrings/deb-multimedia-keyring.pgp
Enabled: yes
DMO

  sudo apt-get update -q
  log_success "DebMultimedia repository enabled."
  log_warning "DebMultimedia is a third-party repository — review packages before installing."
}

# ============================================================================
# STEP 4 — NVIDIA Drivers (DEBIAN_NVIDIA=1 or DEBIAN_NVIDIA_CUDA=1)
# Uses NVIDIA's own repository (not distro packages — driver 550 in Debian 13
# is insufficient for DaVinci Resolve 20.x which requires CUDA 12.8 / driver 570+)
# ============================================================================
_CUDA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb"
_CUDA_KEYRING_DEB="/tmp/cuda-keyring.deb"
_NVIDIA_PREF="/etc/apt/preferences.d/nvidia-repo"

_step_nvidia() {
  log_step "4 · NVIDIA Drivers"

  # Dependencies for DKMS module build
  log_info "Installing kernel build dependencies..."
  apt_install dkms libdw-dev clang lld llvm build-essential linux-headers-amd64 \
    pipewire-audio-client-libraries

  # NVIDIA CUDA repo keyring (reuses Debian 12 repo — works on Trixie)
  if ! dpkg -l cuda-keyring &>/dev/null 2>&1; then
    log_info "Installing CUDA repository keyring..."
    wget -qO "$_CUDA_KEYRING_DEB" "$_CUDA_KEYRING_URL"
    sudo dpkg -i "$_CUDA_KEYRING_DEB"
    rm -f "$_CUDA_KEYRING_DEB"
    sudo apt-get update -q
    log_success "CUDA repository added."
  else
    log_info "cuda-keyring already installed."
  fi

  # APT pin: NVIDIA repo takes priority over Debian packages for same pkgs
  if [[ ! -f "$_NVIDIA_PREF" ]]; then
    log_info "Setting NVIDIA repo priority (pin 900)..."
    sudo tee "$_NVIDIA_PREF" >/dev/null <<'PREF'
Package: *
Pin: origin https://developer.download.nvidia.com
Pin-Priority: 900
PREF
    log_success "NVIDIA repo pinned at priority 900."
  else
    log_info "NVIDIA pin already exists: ${_NVIDIA_PREF}"
  fi

  # Install driver
  if [[ "${DEBIAN_NVIDIA_CUDA:-0}" == "1" ]]; then
    log_info "Installing CUDA toolkit + drivers (full)..."
    sudo apt-get install -y cuda-drivers cuda-toolkit
    log_success "CUDA toolkit installed."
    log_warning "DaVinci Resolve 20.x requires CUDA 12.8+ (driver 570+) — verify: nvidia-smi"
  else
    log_info "Installing nvidia-open (basic driver)..."
    sudo apt-get install -y nvidia-open
    log_success "nvidia-open installed."
  fi

  log_warning "REBOOT required before the NVIDIA driver takes effect."
}

# ============================================================================
# STEP 5 — Flatpak + Flathub
# KDE Plasma: uses plasma-discover-backend-flatpak
# GNOME:      uses gnome-software-plugin-flatpak instead
# ============================================================================
_step_flatpak() {
  log_step "5 · Flatpak + Flathub"

  apt_install flatpak

  # KDE backend
  if is_installed plasmashell; then
    apt_install plasma-discover-backend-flatpak
  elif is_pkg_installed gnome-software 2>/dev/null; then
    apt_install gnome-software-plugin-flatpak
  fi

  flatpak_remote_add flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  log_success "Flathub enabled."
  log_info "A logout/login may be required before Flatpak apps appear in the menu."
}

# ============================================================================
# STEP 6 — Productivity Applications
# Flatpak apps: GIMP · Inkscape · Shotcut · OBS · browsers · misc
# apt apps:     vim · btop · fish · yt-dlp · chromium · aria2 · tmux · fonts
# ============================================================================
_FLATPAK_PRODUCTIVITY=(
  # Creative
  "org.gimp.GIMP"
  "org.inkscape.Inkscape"
  "org.shotcut.Shotcut"
  "com.obsproject.Studio"
  # Browsers
  "com.google.Chrome"
  "com.microsoft.Edge"
  "org.mozilla.firefox"
  "app.zen_browser.zen"
  # Office / productivity
  "md.obsidian.Obsidian"
  "org.onlyoffice.desktopeditors"
  # System tools
  "com.github.tchx84.Flatseal"
  "io.missioncenter.MissionCenter"
  # Media
  "fr.handbrake.ghb"
  "io.github.celluloid_player.Celluloid"
  # Misc
  "com.usebottles.bottles"
  "org.gnome.Boxes"
  "com.dec05eba.gpu_screen_recorder"
)

_APT_PRODUCTIVITY=(
  vim btop fish tmux
  yt-dlp
  aria2
  chromium
  fonts-bebas-neue
  gstreamer1.0-plugins-ugly
  gstreamer1.0-plugins-bad
  gpm # mouse in TTY
)

_step_productivity() {
  log_step "6 · Productivity Applications"

  # apt packages
  log_info "Installing apt packages..."
  apt_install "${_APT_PRODUCTIVITY[@]}"

  # Flatpak apps
  log_info "Installing Flatpak apps..."
  for app in "${_FLATPAK_PRODUCTIVITY[@]}"; do
    flatpak_install "$app"
  done

  log_success "Productivity apps installed."
}

# ============================================================================
# STEP 7 — DaVinci Resolve helper notes
# Cannot automate the download (requires free account at blackmagicdesign.com)
# Prints all known workarounds / dependency fixes.
# ============================================================================
_step_davinci_resolve_deps() {
  log_step "7 · DaVinci Resolve Dependencies"

  log_info "Installing DaVinci Resolve runtime dependencies..."
  apt_install libxcb-composite0 libxcb-cursor0 libxcb-xinerama0 libxcb-xinput0 pkexec libfuse2

  log_success "DaVinci Resolve dependencies installed."

  cat <<'DR_NOTES'

╔══════════════════════════════════════════════════════════════════╗
║          DaVinci Resolve — Manual Install Notes                  ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  1. Download from: blackmagicdesign.com/products/davinciresolve  ║
║     Resolve 20.x requires CUDA 12.8 → driver 570+ (NVIDIA)      ║
║                                                                  ║
║  2. Installer won't start? Run with package check bypassed:      ║
║     SKIP_PACKAGE_CHECK=1 ./DaVinci_Resolve_Studio_20.x_Linux.run ║
║                                                                  ║
║  3. libfuse error? Already fixed above (libfuse2 installed).     ║
║                                                                  ║
║  4. glib/gio/gmodule conflicts inside /opt/resolve/libs:         ║
║     # Backup first:                                              ║
║     tar -cvhzf ~/backup-libs-resolve.tar.gz \                   ║
║       /opt/resolve/libs/libgmodule-2.0.so* \                    ║
║       /opt/resolve/libs/libglib-2.0.so* \                       ║
║       /opt/resolve/libs/libgio-2.0.so*                           ║
║     # Then remove bundled libs (conflicts with system):          ║
║     sudo rm /opt/resolve/libs/libgmodule-2.0.so*                ║
║     sudo rm /opt/resolve/libs/libglib-2.0.so*                   ║
║     sudo rm /opt/resolve/libs/libgio-2.0.so*                    ║
║                                                                  ║
║  5. Alternative: MakeResolveDeb converts installer to .deb       ║
║     https://www.danieltufvesson.com/makeresolvedeb               ║
║                                                                  ║
║  Arch Wiki has additional troubleshooting:                       ║
║  https://wiki.archlinux.org/title/DaVinci_Resolve                ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
DR_NOTES
}

# ============================================================================
# STEP 8 — Gaming (DEBIAN_GAMING=1)
# Steam · Heroic Games Launcher · vkBasalt · MangoJuice · Protontricks
# ============================================================================
_FLATPAK_GAMING=(
  "com.valvesoftware.Steam"
  "com.valvesoftware.Steam.Utility.vkBasalt"
  "com.heroicgameslauncher.hgl"
  "com.github.Matoking.protontricks"
  "com.github.tchx84.Flatseal"
  "io.github.radiolamp.mangojuice"
  "org.vinegarhq.Sober" # Roblox on Linux
)

_step_gaming() {
  log_step "8 · Gaming (DEBIAN_GAMING=1)"

  for app in "${_FLATPAK_GAMING[@]}"; do
    flatpak_install "$app"
  done

  log_success "Gaming apps installed."
  log_info "Use Flatseal to grant Steam access to additional drives."
  log_info "MangoHUD guide: plus.diolinux.com.br/t/configurando-a-steam-flatpak-discos-mangohud-gamemode-e-remote-play/47160"
}

# ============================================================================
# STEP 9 — Debloat (DEBIAN_DEBLOAT=1)
# Removes KDE/GNOME apps not needed on a workstation
# ============================================================================
_DEBLOAT_PKGS=(
  libreoffice-common # replaced by OnlyOffice flatpak
  akregator          # RSS reader
  kontrast           # color contrast checker
  kmouth             # text-to-speech
  dragonplayer       # video player (replaced by Celluloid)
  kmail              # email client
  juk                # music player
  xterm              # legacy terminal
  firefox-esr        # replaced by flatpak Firefox
  konqueror          # legacy browser/file manager
)

_step_debloat() {
  log_step "9 · Debloat (DEBIAN_DEBLOAT=1)"

  for pkg in "${_DEBLOAT_PKGS[@]}"; do
    if is_pkg_installed "$pkg" 2>/dev/null; then
      log_info "Removing: ${pkg}"
      sudo apt-get --purge remove -y "$pkg" 2>/dev/null || true
    else
      log_info "Not installed (skip): ${pkg}"
    fi
  done

  # LibreOffice wildcard
  sudo apt-get --purge remove -y 'libreoffice*' 2>/dev/null || true

  log_success "Debloat complete."
}

# ============================================================================
# STEP 10 — ZSWAP (DEBIAN_ZSWAP=1)
# Adds kernel parameter to systemd-boot entry for current Debian install
# Improves memory pressure performance — especially on systems with ≤16GB RAM
# ============================================================================
_step_zswap() {
  log_step "10 · ZSWAP (DEBIAN_ZSWAP=1)"

  local boot_entries
  boot_entries="$(find /boot/efi/loader/entries/ -name "*.conf" 2>/dev/null || true)"

  if [[ -z "$boot_entries" ]]; then
    log_warning "No systemd-boot entries found at /boot/efi/loader/entries/"
    log_warning "ZSWAP must be configured manually for your bootloader."
    return 0
  fi

  local changed=false
  while IFS= read -r entry; do
    if grep -q "zswap.enabled=1" "$entry" 2>/dev/null; then
      log_info "ZSWAP already enabled in: ${entry}"
      continue
    fi
    backup_warning "$entry"
    # Append to the 'options' line
    sudo sed -i '/^options / s/$/ zswap.enabled=1 quiet/' "$entry"
    log_success "ZSWAP enabled in: ${entry}"
    changed=true
  done <<<"$boot_entries"

  if [[ "$changed" == true ]]; then
    sudo bootctl update 2>/dev/null || log_warning "bootctl update failed — run manually."
    log_success "bootctl updated."
    log_warning "Reboot to activate ZSWAP."
  fi

  log_info "ZSWAP docs: wiki.debian.org/Zswap | wiki.archlinux.org/title/Zswap"
}

# ============================================================================
# STEP 11 — Cleanup
# ============================================================================
_step_cleanup() {
  log_step "11 · Cleanup"
  sudo apt-get autoremove -y
  sudo apt-get autoclean
  sudo apt-get clean
  flatpak update -y 2>/dev/null || true
  flatpak uninstall --unused -y 2>/dev/null || true
  log_success "System clean."
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
║  REBOOT — required after NVIDIA driver / kernel changes         ║
║    systemctl reboot                                              ║
║                                                                  ║
║  DAVINCI RESOLVE — download from blackmagicdesign.com           ║
║    Requires CUDA 12.8+ → driver 570+ (DEBIAN_NVIDIA_CUDA=1)     ║
║    SKIP_PACKAGE_CHECK=1 ./DaVinci_Resolve_*.run                  ║
║                                                                  ║
║  DEBMULTIMEDIA — verify apt modernize-sources after adding      ║
║    sudo apt modernize-sources                                    ║
║                                                                  ║
║  FLATPAK apps appear after logout/login (KDE/GNOME menu)        ║
║                                                                  ║
║  STEAM — use Flatseal to grant access to other drives           ║
║    flatpak run com.github.tchx84.Flatseal                        ║
║                                                                  ║
║  ZSWAP — check it's active after reboot                         ║
║    cat /sys/module/zswap/parameters/enabled   → Y               ║
║                                                                  ║
║  KDECONNECT — pair phone via KDE Connect app                    ║
║    Ports already opened in UFW (1714-1764 tcp/udp)               ║
║                                                                  ║
║  NON-FREE REPOS — if not enabled during install                 ║
║    sudo dpkg-reconfigure apt-setup                               ║
║    or edit /etc/apt/sources.list to add non-free non-free-firmware║
║                                                                  ║
║  ALPACA (local AI): flatpak install com.jeffser.Alpaca           ║
║  VESKTOP (Discord): flatpak install dev.vencord.Vesktop          ║
║  FLATSWEEP (cleanup): flatpak install io.github.giantpinkrobots.flatsweep
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
MANUAL
}

# ============================================================================
# run_install — orchestrator (called by install.sh)
# ============================================================================
run_install() {
  require_os debian
  check_sudo

  log_step "PostInstallHUB · Debian 13 Trixie"
  echo -e "${DIM}User: $(whoami)  ·  Host: $(hostname)${NC}"
  echo -e "${DIM}POSTINSTALL_YES=${POSTINSTALL_YES:-0}  ·  DEBIAN_NVIDIA=${DEBIAN_NVIDIA:-0}  ·  DEBIAN_NVIDIA_CUDA=${DEBIAN_NVIDIA_CUDA:-0}${NC}"
  echo -e "${DIM}DEBIAN_GAMING=${DEBIAN_GAMING:-0}  ·  DEBIAN_DEBLOAT=${DEBIAN_DEBLOAT:-0}  ·  DEBIAN_ZSWAP=${DEBIAN_ZSWAP:-0}${NC}\n"

  # Always run
  _step_update
  _step_ufw
  _step_debmultimedia
  _step_flatpak
  _step_productivity
  _step_davinci_resolve_deps
  _step_cleanup

  # Opt-in
  if [[ "${DEBIAN_NVIDIA:-0}" == "1" ]] || [[ "${DEBIAN_NVIDIA_CUDA:-0}" == "1" ]]; then
    _step_nvidia
  fi

  if [[ "${DEBIAN_GAMING:-0}" == "1" ]]; then
    _step_gaming
  fi

  if [[ "${DEBIAN_DEBLOAT:-0}" == "1" ]]; then
    _step_debloat
  fi

  if [[ "${DEBIAN_ZSWAP:-0}" == "1" ]]; then
    _step_zswap
  fi

  step_dotfiles

  echo ""
  log_success "All automated steps complete!"
  _print_manual_steps
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_install "$@"
fi
