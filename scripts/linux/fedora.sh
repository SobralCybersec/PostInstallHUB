#!/usr/bin/env bash
# =============================================================================
# scripts/linux/fedora.sh — Fedora 44 post-install setup
#
# Based on: github.com/devangshekhawat/Fedora-44-Post-Install-Guide
# Covers: RPM Fusion · update · firmware · flatpak · appimage · codecs ·
#         HW video accel · optimizations · UTC time · essential packages
#
# Called by install.sh:
#   source scripts/linux/fedora.sh && run_install
#
# Or run directly:
#   bash scripts/linux/fedora.sh
#
# Optional env flags:
#   FEDORA_NVIDIA=1    — install NVIDIA drivers (akmod-nvidia)
#   FEDORA_CUDA=1      — also install CUDA support (requires FEDORA_NVIDIA=1)
#   FEDORA_DNS=1       — configure Cloudflare DNS over TLS
#   POSTINSTALL_YES=1  — non-interactive (no prompts); skips dotfiles
#   POSTINSTALL_DOTFILES=none|jakoolit|caelestia
#     jakoolit   — Hyprland desktop (LinuxBeginnings/Hyprland-Dots, Fedora-supported)
#     caelestia  — Quickshell Hyprland desktop (via Nix flake)
# =============================================================================
set -euo pipefail

_FEDORA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_FEDORA_SCRIPT_DIR}/common.sh"
source "${_FEDORA_SCRIPT_DIR}/dotfiles.sh"

# ============================================================================
# Fedora-specific package helpers
# ============================================================================

# Detect dnf binary — Fedora 41+ ships dnf5 as `dnf`; dnf4 is compat binary
_DNF="$(command -v dnf5 2>/dev/null || command -v dnf 2>/dev/null || echo dnf)"
# Some group operations still need dnf4 on Fedora 44 (noted in guide)
_DNF4="$(command -v dnf4 2>/dev/null || echo "$_DNF")"

# dnf_install PKG [PKG…] — idempotent; only installs what's missing
dnf_install() {
  local to_install=()
  for pkg in "$@"; do
    if rpm -q "$pkg" &>/dev/null; then
      log_info "Already installed: ${pkg}"
    else
      to_install+=("$pkg")
    fi
  done
  [[ ${#to_install[@]} -eq 0 ]] && return 0
  log_info "dnf installing: ${to_install[*]}"
  sudo "$_DNF" install -y "${to_install[@]}"
}

# flatpak_remote_add NAME URL — idempotent flatpak remote add
flatpak_remote_add() {
  local name="$1"
  local url="$2"
  if flatpak remotes 2>/dev/null | grep -q "^${name}"; then
    log_info "Flatpak remote already exists: ${name}"
  else
    flatpak remote-add --if-not-exists "$name" "$url"
    log_success "Flatpak remote added: ${name}"
  fi
}

# detect_gpu — prints nvidia | intel | amd | unknown
detect_gpu() {
  if ! is_installed lspci; then
    dnf_install pciutils 2>/dev/null || true
  fi
  if lspci 2>/dev/null | grep -qi 'nvidia'; then
    echo "nvidia"
  elif lspci 2>/dev/null | grep -qiE 'amd|radeon'; then
    echo "amd"
  elif lspci 2>/dev/null | grep -qiE 'intel.*graphics|intel.*uhd|intel.*hd'; then
    echo "intel"
  else
    echo "unknown"
  fi
}

# service_enable_now SERVICE — idempotent
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
# STEP 1 — RPM Fusion (free + nonfree)
# Must come FIRST — enables repos that all later steps depend on
# ============================================================================
_step_rpmfusion() {
  log_step "1 · RPM Fusion Repositories"

  local fedora_ver
  fedora_ver="$(rpm -E %fedora)"

  # free
  if rpm -q rpmfusion-free-release &>/dev/null; then
    log_info "RPM Fusion free: already installed."
  else
    log_info "Installing RPM Fusion free (Fedora ${fedora_ver})..."
    sudo "$_DNF" install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm"
    log_success "RPM Fusion free enabled."
  fi

  # nonfree
  if rpm -q rpmfusion-nonfree-release &>/dev/null; then
    log_info "RPM Fusion nonfree: already installed."
  else
    log_info "Installing RPM Fusion nonfree (Fedora ${fedora_ver})..."
    sudo "$_DNF" install -y \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
    log_success "RPM Fusion nonfree enabled."
  fi

  # App-stream metadata (makes GNOME Software show RPM Fusion apps with icons/descriptions)
  log_info "Updating appstream metadata..."
  sudo "$_DNF" group upgrade -y core 2>/dev/null || true
  sudo "$_DNF4" group install -y core 2>/dev/null || true
  log_success "Appstream metadata updated."
}

# ============================================================================
# STEP 2 — System Update
# ============================================================================
_step_update() {
  log_step "2 · System Update (dnf update)"
  sudo "$_DNF" -y update
  log_success "System up to date."
  log_warning "A reboot is recommended before installing NVIDIA drivers."
}

# ============================================================================
# STEP 3 — Firmware Updates (fwupdmgr)
# ============================================================================
_step_firmware() {
  log_step "3 · Firmware Updates"

  if ! is_installed fwupdmgr; then
    dnf_install fwupd
  fi

  log_info "Refreshing firmware metadata..."
  sudo fwupdmgr refresh --force 2>/dev/null || log_warning "fwupdmgr refresh failed (may need network or LVFS support)"

  log_info "Checking for available firmware updates..."
  fwupdmgr get-updates 2>/dev/null || log_info "No firmware updates available (or device not listed)."

  if [[ "${POSTINSTALL_YES:-0}" == "1" ]]; then
    sudo fwupdmgr update -y 2>/dev/null || log_warning "fwupdmgr update returned non-zero — check manually."
  else
    echo -e "${YELLOW}Apply firmware updates? (y/N)${NC} "
    read -r fw_reply
    if [[ "${fw_reply,,}" == "y" ]]; then
      sudo fwupdmgr update 2>/dev/null || log_warning "fwupdmgr update returned non-zero — check manually."
    else
      log_info "Firmware update skipped."
    fi
  fi
}

# ============================================================================
# STEP 4 — Flatpak + Flathub
# ============================================================================
_step_flatpak() {
  log_step "4 · Flatpak + Flathub"

  dnf_install flatpak

  flatpak_remote_add flathub https://dl.flathub.org/repo/flathub.flatpakrepo

  log_success "Flathub enabled — run 'flatpak update' to sync."
}

# ============================================================================
# STEP 5 — AppImage Support
# ============================================================================
_step_appimage() {
  log_step "5 · AppImage Support"
  dnf_install fuse-libs
  log_success "AppImage support: fuse-libs installed."
  log_info "Optional: flatpak install it.mijorus.gearlever  (AppImage manager)"
}

# ============================================================================
# STEP 6 — Media Codecs (RPM Fusion required)
# ============================================================================
_step_media_codecs() {
  log_step "6 · Media Codecs"

  # multimedia group (guide specifies dnf4 for this)
  if "$_DNF" group list --installed 2>/dev/null | grep -qi "^multimedia"; then
    log_info "multimedia group already installed."
  else
    log_info "Installing multimedia group (dnf4)..."
    sudo "$_DNF4" group install -y multimedia
    log_success "multimedia group installed."
  fi

  # Swap ffmpeg-free → ffmpeg (full RPM Fusion build with all codecs)
  if rpm -q ffmpeg-free &>/dev/null; then
    log_info "Swapping ffmpeg-free → ffmpeg (RPM Fusion full build)..."
    sudo "$_DNF" swap -y 'ffmpeg-free' 'ffmpeg' --allowerasing
    log_success "ffmpeg swapped."
  elif rpm -q ffmpeg &>/dev/null; then
    log_info "Full ffmpeg already installed."
  else
    log_warning "Neither ffmpeg-free nor ffmpeg found — skipping swap."
  fi

  # Update @multimedia — gstreamer components
  log_info "Updating @multimedia group (gstreamer components)..."
  sudo "$_DNF" update -y @multimedia \
    --setopt="install_weak_deps=False" \
    --exclude=PackageKit-gstreamer-plugin 2>/dev/null || true

  # Sound and video complementary packages
  if "$_DNF" group list --installed 2>/dev/null | grep -qi "sound-and-video"; then
    log_info "sound-and-video group already installed."
  else
    log_info "Installing sound-and-video group..."
    sudo "$_DNF" group install -y sound-and-video
    log_success "sound-and-video group installed."
  fi

  log_success "Media codecs configured."
}

# ============================================================================
# STEP 7 — H/W Video Acceleration (VA-API)
# ============================================================================
_step_hw_video() {
  log_step "7 · H/W Video Acceleration (VA-API)"

  # Base VA-API packages
  dnf_install ffmpeg-libs libva libva-utils

  local gpu
  gpu="$(detect_gpu)"
  log_info "GPU detected: ${gpu}"

  case "$gpu" in
    intel)
      log_info "Intel GPU: installing intel-media-driver + libva-intel-driver..."
      # Swap to full intel driver (RPM Fusion nonfree)
      if rpm -q libva-intel-media-driver &>/dev/null && ! rpm -q intel-media-driver &>/dev/null; then
        sudo "$_DNF" swap -y libva-intel-media-driver intel-media-driver --allowerasing
        log_success "Intel media driver swapped."
      elif rpm -q intel-media-driver &>/dev/null; then
        log_info "intel-media-driver already installed."
      fi
      dnf_install libva-intel-driver
      ;;
    amd)
      log_info "AMD GPU: installing mesa VA-API freeworld drivers..."
      # mesa-va-drivers-freeworld has h264/h265 (removed from main Fedora in f38)
      dnf_install mesa-va-drivers-freeworld
      # 32-bit for Steam/Wine compatibility
      if rpm --eval '%{_arch}' 2>/dev/null | grep -q x86_64; then
        dnf_install mesa-va-drivers-freeworld.i686 2>/dev/null ||
          log_warning "mesa-va-drivers-freeworld.i686 not available — skipping 32-bit."
      fi
      ;;
    nvidia)
      log_info "NVIDIA GPU: VA-API handled by NVIDIA driver. Run with FEDORA_NVIDIA=1 to install."
      ;;
    *)
      log_warning "Unknown GPU — skipping GPU-specific VA-API drivers. Install manually if needed."
      ;;
  esac

  # OpenH264 for Firefox
  log_info "Installing OpenH264 for Firefox..."
  dnf_install openh264 gstreamer1-plugin-openh264 mozilla-openh264

  # Enable Cisco OpenH264 repo (uses setopt for dnf5, --enable for dnf4)
  if sudo "$_DNF" config-manager setopt fedora-cisco-openh264.enabled=1 2>/dev/null; then
    log_success "fedora-cisco-openh264 repo enabled (dnf5 setopt)."
  else
    sudo "$_DNF4" config-manager --enable fedora-cisco-openh264 2>/dev/null &&
      log_success "fedora-cisco-openh264 repo enabled (dnf4)." ||
      log_warning "Could not enable fedora-cisco-openh264 — enable in Firefox settings manually."
  fi

  log_info "After reboot: enable OpenH264 plugin in Firefox → Settings → Plugins."
  log_success "H/W video acceleration configured."
}

# ============================================================================
# STEP 8 — NVIDIA Drivers (optional — FEDORA_NVIDIA=1)
# ============================================================================
_step_nvidia() {
  log_step "8 · NVIDIA Drivers"

  # Check for NVIDIA GPU
  local gpu
  gpu="$(detect_gpu)"
  if [[ "$gpu" != "nvidia" ]]; then
    log_info "No NVIDIA GPU detected (found: ${gpu}) — skipping."
    return 0
  fi

  log_info "NVIDIA GPU found. Checking Secure Boot state..."
  local sb_enabled=false
  if command -v mokutil &>/dev/null; then
    mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled" && sb_enabled=true
  fi

  if [[ "$sb_enabled" == true ]]; then
    log_warning "Secure Boot is ENABLED."
    log_warning "Full automation is not possible — MOK enrollment requires manual BIOS interaction."
    log_warning "Steps to complete manually after this script:"
    cat <<'SB_MANUAL'

  ── Secure Boot + NVIDIA (manual steps) ──────────────────────────────────
  1.  sudo dnf install kmodtool akmods mokutil openssl
  2.  sudo kmodgenca -a
       (if "EXISTING KEY PAIR" error: add --force)
  3.  sudo mokutil --import /etc/pki/akmods/certs/public_key.der
       (create a short password, e.g. 1234)
  4.  systemctl reboot
  5.  In the blue MOK screen: Enroll MOK → Continue → Yes → [your password]
  6.  Reboot, then run:
       sudo dnf install akmod-nvidia
       Wait 5+ min before rebooting: modinfo -F version nvidia
  ─────────────────────────────────────────────────────────────────────────
SB_MANUAL
    dnf_install kmodtool akmods mokutil openssl
    log_info "MOK tools installed. Follow the manual steps above."
    return 0
  fi

  # Secure Boot disabled — install directly
  log_info "Installing akmod-nvidia..."
  dnf_install akmod-nvidia

  if [[ "${FEDORA_CUDA:-0}" == "1" ]]; then
    log_info "Installing CUDA support..."
    dnf_install xorg-x11-drv-nvidia-cuda
    log_success "NVIDIA CUDA support installed."
  fi

  log_success "akmod-nvidia installed."
  log_warning "Wait AT LEAST 5 minutes before rebooting (kernel module must finish building)."
  log_info "Check build: modinfo -F version nvidia"
  log_info "If it returns a version number → safe to reboot."
}

# ============================================================================
# STEP 9 — System Optimizations
# ============================================================================
_AUTOSTART_DIR="${HOME}/.config/autostart"
_GNOME_SW_DESKTOP="org.gnome.Software.desktop"

_step_optimizations() {
  log_step "9 · System Optimizations"

  # Disable NetworkManager-wait-online (saves ~15-20s boot time)
  if systemctl is-enabled NetworkManager-wait-online.service &>/dev/null; then
    sudo systemctl disable NetworkManager-wait-online.service
    log_success "Disabled NetworkManager-wait-online.service (~15-20s boot speedup)."
  else
    log_info "NetworkManager-wait-online: already disabled."
  fi

  # Disable GNOME Software autostart (saves up to 900MB RAM)
  if command -v gnome-shell &>/dev/null; then
    mkdir -p "${_AUTOSTART_DIR}"
    local autostart_file="${_AUTOSTART_DIR}/${_GNOME_SW_DESKTOP}"

    if [[ -f "$autostart_file" ]] && grep -q "X-GNOME-Autostart-enabled=false" "$autostart_file"; then
      log_info "GNOME Software autostart: already disabled."
    else
      local src="/usr/share/applications/${_GNOME_SW_DESKTOP}"
      if [[ -f "$src" ]]; then
        cp "$src" "$autostart_file"
        echo "X-GNOME-Autostart-enabled=false" >>"$autostart_file"
        log_success "GNOME Software autostart disabled (saves up to 900MB RAM)."
      else
        log_warning "${src} not found — GNOME Software may not be installed."
      fi
    fi

    # Also disable as GNOME search provider (prevents bg launch from overview search)
    if command -v dconf &>/dev/null; then
      local current_disabled
      current_disabled="$(dconf read /org/gnome/desktop/search-providers/disabled 2>/dev/null || echo "[]")"
      if echo "$current_disabled" | grep -q "Software"; then
        log_info "GNOME Software search provider: already disabled."
      else
        dconf write /org/gnome/desktop/search-providers/disabled \
          "['${_GNOME_SW_DESKTOP}']" 2>/dev/null &&
          log_success "GNOME Software disabled as search provider." ||
          log_warning "dconf write failed — disable Software search provider manually."
      fi
    fi
  else
    log_info "GNOME Shell not detected — skipping GNOME Software autostart step."
  fi
}

# ============================================================================
# STEP 10 — DNS over TLS with Cloudflare (optional — FEDORA_DNS=1)
# ============================================================================
_step_dns() {
  log_step "10 · DNS over TLS (Cloudflare)"

  local dir="/etc/systemd/resolved.conf.d"
  local conf="${dir}/99-dns-over-tls.conf"

  if [[ -f "$conf" ]]; then
    log_info "DNS over TLS already configured at ${conf}."
    return 0
  fi

  sudo mkdir -p "$dir"
  sudo tee "$conf" >/dev/null <<'DNS_CONF'
# PostInstallHUB — Cloudflare DNS over TLS
# Cloudflare security: blocks malware domains (1.1.1.2 / 1.0.0.2)
[Resolve]
DNS=1.1.1.2#security.cloudflare-dns.com 1.0.0.2#security.cloudflare-dns.com 2606:4700:4700::1112#security.cloudflare-dns.com 2606:4700:4700::1002#security.cloudflare-dns.com
DNSOverTLS=yes
Domains=~.
DNS_CONF

  sudo systemctl restart systemd-resolved.service 2>/dev/null || true
  log_success "DNS over TLS configured (Cloudflare security: 1.1.1.2/1.0.0.2)."
  log_info "To use plain Cloudflare (1.1.1.1): edit ${conf}"
}

# ============================================================================
# STEP 11 — UTC Time (for dual-boot systems)
# ============================================================================
_step_utc_time() {
  log_step "11 · UTC Hardware Clock"

  local current
  current="$(timedatectl show --property=LocalRTC --value 2>/dev/null || echo "unknown")"

  if [[ "$current" == "no" ]]; then
    log_info "Hardware clock already set to UTC."
  else
    sudo timedatectl set-local-rtc '0'
    log_success "Hardware clock set to UTC (fixes dual-boot time drift)."
  fi
}

# ============================================================================
# STEP 12 — Essential Packages
# ============================================================================
_ESSENTIAL_PACKAGES=(
  # Archive formats
  unzip p7zip p7zip-plugins unrar
  # System tools
  pciutils wget curl git htop btop tree
  # Terminal improvements
  bat fd-find ripgrep fzf
  # Media (CLI)
  yt-dlp
)

_step_essential_packages() {
  log_step "12 · Essential Packages"
  dnf_install "${_ESSENTIAL_PACKAGES[@]}"

  # Ghostty terminal — available in Fedora repos on recent releases
  if rpm -q ghostty &>/dev/null; then
    log_info "Already installed: ghostty"
  else
    log_info "Installing ghostty terminal…"
    sudo "$_DNF" install -y ghostty 2>/dev/null ||
      log_warning "Ghostty not found in default repos." \
        "Install via COPR: sudo dnf copr enable pgdev/ghostty && sudo dnf install -y ghostty"
  fi

  log_success "Essential packages installed."
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
║  REBOOT — recommended after update + codec changes              ║
║    systemctl reboot                                              ║
║                                                                  ║
║  NVIDIA (if FEDORA_NVIDIA=1 was not set)                        ║
║    sudo dnf install akmod-nvidia                                 ║
║    Wait 5+ min: modinfo -F version nvidia                        ║
║    For CUDA: sudo dnf install xorg-x11-drv-nvidia-cuda          ║
║                                                                  ║
║  FIREFOX — enable OpenH264 plugin                               ║
║    Settings → General → scroll to "Digital Rights Management"   ║
║    → Enable DRM, or go to about:addons → Plugins                ║
║                                                                  ║
║  SET HOSTNAME                                                    ║
║    hostnamectl set-hostname YOUR_HOSTNAME                        ║
║                                                                  ║
║  FIREFOX DEFAULT START PAGE (remove Fedora redirect)            ║
║    sudo rm -f /usr/lib64/firefox/browser/defaults/preferences/  ║
║               firefox-redhat-default-prefs.js                   ║
║                                                                  ║
║  GNOME EXTENSIONS (optional, GNOME spins only)                  ║
║    Pop Shell:  sudo dnf install -y gnome-shell-extension-pop-shell xprop
║    GSconnect:  sudo dnf install nautilus-python                  ║
║                sudo firewall-cmd --permanent --zone=public \     ║
║                     --add-service=kdeconnect                     ║
║    Others:     https://extensions.gnome.org                      ║
║    Useful:  Blur My Shell · Dash to Dock · Caffeine              ║
║             Vitals · Clipboard Indicator · Just Perfection       ║
║                                                                  ║
║  FLATPAK APPS (examples)                                         ║
║    flatpak install flathub org.gimp.GIMP                         ║
║    flatpak install flathub com.brave.Browser                     ║
║    flatpak install flathub it.mijorus.gearlever  # AppImage mgr  ║
║                                                                  ║
║  GTK THEMES (GNOME spins only)                                  ║
║    adw-gtk3: https://github.com/lassekongo83/adw-gtk3            ║
║    Apply:  sudo flatpak override --filesystem=$HOME/.themes      ║
║            sudo flatpak override --env=GTK_THEME=my-theme        ║
║                                                                  ║
║  STARSHIP PROMPT                                                 ║
║    curl -sS https://starship.rs/install.sh | sh                  ║
║    echo 'eval "$(starship init bash)"' >> ~/.bashrc              ║
║                                                                  ║
║  DNS OVER TLS (if FEDORA_DNS=1 was not set)                     ║
║    FEDORA_DNS=1 bash install.sh                                  ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
MANUAL
}

# ============================================================================
# run_install — orchestrator (called by install.sh)
# ============================================================================
run_install() {
  require_os fedora
  check_sudo

  log_step "PostInstallHUB · Fedora 44"
  echo -e "${DIM}User: $(whoami)  ·  Host: $(hostname)  ·  dnf: ${_DNF}${NC}"
  echo -e "${DIM}POSTINSTALL_YES=${POSTINSTALL_YES:-0}  ·  FEDORA_NVIDIA=${FEDORA_NVIDIA:-0}  ·  FEDORA_DNS=${FEDORA_DNS:-0}${NC}\n"

  # Note: Fedora ships zram-generator by default — zram swap is already active.
  # No FEDORA_ZRAM flag needed; run `swapon --show` to confirm /dev/zramN is present.
  log_info "zram: Fedora enables zram-generator by default — swap is already compressed in RAM."

  # Core steps (always run)
  _step_rpmfusion
  _step_update
  _step_firmware
  _step_flatpak
  _step_appimage
  _step_media_codecs
  _step_hw_video
  _step_optimizations
  _step_utc_time
  _step_essential_packages

  # Optional steps (gated by env flags)
  if [[ "${FEDORA_NVIDIA:-0}" == "1" ]]; then
    _step_nvidia
  fi

  if [[ "${FEDORA_DNS:-0}" == "1" ]]; then
    _step_dns
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
