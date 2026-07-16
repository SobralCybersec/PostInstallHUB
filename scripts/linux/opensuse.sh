#!/usr/bin/env bash
# =============================================================================
# scripts/linux/opensuse.sh — openSUSE post-install setup
#
# Covers: system update · Packman repo · essential packages · flatpak ·
#         NVIDIA drivers · gaming · ZSH + oh-my-zsh · dotfiles
#
# Called by install.sh:
#   source scripts/linux/opensuse.sh && run_install
#
# Or run directly:
#   bash scripts/linux/opensuse.sh
#
# Optional env flags:
#   OPENSUSE_PACKMAN=1   — add Packman repo + dist-upgrade codecs
#   OPENSUSE_NVIDIA=1    — install NVIDIA proprietary drivers
#   OPENSUSE_GAMING=1    — install Steam, Lutris, Protontricks, gamemode
#   POSTINSTALL_YES=1    — non-interactive (no prompts); skips dotfiles
#   POSTINSTALL_DOTFILES=none|jakoolit|caelestia
#     jakoolit   — Hyprland desktop (LinuxBeginnings/Hyprland-Dots)
#     caelestia  — Quickshell Hyprland desktop (AUR or Nix)
# =============================================================================
set -euo pipefail

_OPENSUSE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_OPENSUSE_SCRIPT_DIR}/common.sh"
source "${_OPENSUSE_SCRIPT_DIR}/dotfiles.sh"

# ============================================================================
# openSUSE-specific package helpers
# ============================================================================

# zypper_install PKG [PKG…] — idempotent; only installs what's missing
zypper_install() {
  local to_install=()
  for pkg in "$@"; do
    if rpm -q "$pkg" &>/dev/null; then
      log_info "Already installed: ${pkg}"
    else
      to_install+=("$pkg")
    fi
  done
  [[ ${#to_install[@]} -eq 0 ]] && return 0
  log_info "zypper installing: ${to_install[*]}"
  sudo zypper install -y "${to_install[@]}"
}

# zypper_addrepo NAME URL [PRIORITY] — idempotent repo add
# PRIORITY defaults to 99; lower number = higher priority
zypper_addrepo() {
  local name="$1"
  local url="$2"
  local priority="${3:-99}"
  if sudo zypper repos 2>/dev/null | grep -q "${name}"; then
    log_info "Repo already added: ${name}"
  else
    sudo zypper addrepo -cfp "${priority}" "${url}" "${name}"
    log_success "Repo added: ${name}"
  fi
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

# flatpak_install APP_ID [APP_ID…] — idempotent flatpak install from flathub
flatpak_install() {
  local to_install=()
  for app in "$@"; do
    if flatpak list --app 2>/dev/null | grep -q "^${app}"; then
      log_info "Flatpak already installed: ${app}"
    else
      to_install+=("$app")
    fi
  done
  [[ ${#to_install[@]} -eq 0 ]] && return 0
  log_info "Flatpak installing: ${to_install[*]}"
  flatpak install -y flathub "${to_install[@]}"
}

# ============================================================================
# OS family guard
# Accepts: opensuse-leap · opensuse-tumbleweed · opensuse · suse
# ============================================================================
_require_opensuse_family() {
  local actual
  actual="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release 2>/dev/null | tr -d '"' || echo unknown)"
  case "$actual" in
    opensuse-leap | opensuse-tumbleweed | opensuse | suse)
      return 0
      ;;
    *)
      log_error "Wrong OS: expected openSUSE family, got '${actual}'."
      exit 5
      ;;
  esac
}

# ============================================================================
# STEP 1 — System Update
# ============================================================================
_step_update() {
  log_step "1 · System Update"
  sudo zypper refresh
  sudo zypper update -y
  log_success "System up to date."
}

# ============================================================================
# STEP 2 — Packman Repository (optional — OPENSUSE_PACKMAN=1)
# Packman provides proprietary codecs and multimedia packages that openSUSE
# cannot ship due to licensing (MP3, H.264, AAC, etc.).
# dist-upgrade --from packman replaces openSUSE's codec stubs with full builds.
# ============================================================================
_step_packman() {
  log_step "2 · Packman Repository"

  zypper_addrepo packman \
    "https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/" \
    90

  log_info "Refreshing repos..."
  sudo zypper refresh

  log_info "Upgrading packages from Packman (codec replacements)..."
  sudo zypper dist-upgrade --from packman -y --allow-vendor-change

  log_success "Packman repo active; multimedia packages upgraded."
}

# ============================================================================
# STEP 3 — Essential Packages
# ============================================================================
_ESSENTIAL_PACKAGES=(
  curl git wget htop fastfetch neovim ripgrep fd fzf bat eza zoxide zsh
)

_step_essential() {
  log_step "3 · Essential Packages"
  zypper_install "${_ESSENTIAL_PACKAGES[@]}"
  log_success "Essential packages installed (fastfetch replaces deprecated neofetch)."
}

# ============================================================================
# STEP 4 — Flatpak + Flathub + core Flatpak apps
# ============================================================================
_FLATPAK_APPS=(
  org.gnome.Extensions
  com.github.tchx84.Flatseal
  com.brave.Browser
  com.github.johnfactotum.Foliate
)

_step_flatpak() {
  log_step "4 · Flatpak + Flathub"

  zypper_install flatpak

  flatpak_remote_add flathub https://dl.flathub.org/repo/flathub.flatpakrepo

  log_info "Installing Flatpak apps..."
  flatpak_install "${_FLATPAK_APPS[@]}"

  log_success "Flatpak configured; Flathub apps installed."
}

# ============================================================================
# STEP 5 — NVIDIA Drivers (optional — OPENSUSE_NVIDIA=1)
# Uses the official NVIDIA repo for Tumbleweed.
# For Leap, the URL differs — see gotcha note below.
# ============================================================================
_step_nvidia() {
  log_step "5 · NVIDIA Drivers"

  zypper_addrepo NVIDIA \
    "https://download.nvidia.com/opensuse/tumbleweed" \
    99

  log_info "Refreshing NVIDIA repo..."
  sudo zypper refresh --repo NVIDIA

  zypper_install nvidia-glG05 nvidia-computeG05

  log_success "NVIDIA drivers installed."
  log_warning "Reboot required to load the NVIDIA kernel module."
  # ponytail: Leap URL differs; add _detect_opensuse_version() + branch if Leap support is added
  log_info "Leap note: repo URL = https://download.nvidia.com/opensuse/leap/\$(. /etc/os-release && echo \$VERSION_ID)"
}

# ============================================================================
# STEP 6 — Gaming (optional — OPENSUSE_GAMING=1)
# Steam + Lutris + Protontricks via Flatpak; gamemode via zypper.
# ============================================================================
_GAMING_FLATPAKS=(
  com.valvesoftware.Steam
  net.lutris.Lutris
  com.github.Matoking.protontricks
)

_step_gaming() {
  log_step "6 · Gaming"

  log_info "Installing gaming Flatpak apps..."
  flatpak_install "${_GAMING_FLATPAKS[@]}"

  log_info "Installing gamemode..."
  zypper_install gamemode

  log_success "Gaming setup complete (Steam · Lutris · Protontricks · gamemode)."
}

# ============================================================================
# STEP 7 — ZSH + oh-my-zsh + zsh-autosuggestions
# ============================================================================
_step_zsh() {
  log_step "7 · ZSH + oh-my-zsh + autosuggestions"

  zypper_install zsh zsh-autosuggestions

  # Set ZSH as default shell (idempotent)
  local current_shell
  current_shell="$(getent passwd "$(whoami)" | cut -d: -f7)"
  local zsh_path
  zsh_path="$(command -v zsh)"

  if [[ "$current_shell" == "$zsh_path" ]]; then
    log_info "ZSH already default shell."
  else
    log_info "Setting ZSH as default shell..."
    chsh -s "$zsh_path"
    log_success "Default shell set to ZSH (takes effect on next login)."
  fi

  # oh-my-zsh (idempotent)
  if [[ -d "${HOME}/.oh-my-zsh" ]]; then
    log_info "oh-my-zsh already installed."
  else
    log_info "Installing oh-my-zsh..."
    # RUNZSH=no: don't launch ZSH mid-script; CHSH=no: we handled it above
    RUNZSH=no CHSH=no \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    log_success "oh-my-zsh installed."
  fi

  # zsh-autosuggestions plugin source guard in .zshrc
  # openSUSE ships the plugin via zypper at this path
  append_once "zsh-autosuggestions" "${HOME}/.zshrc" \
    "source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

  log_success "ZSH configuration complete."
}

# ============================================================================
# STEP 8 — Dotfiles
# ============================================================================
_step_dotfiles() {
  log_step "8 · Dotfiles"
  step_dotfiles
}

# ============================================================================
# run_install — orchestrator (called by install.sh)
# ============================================================================
run_install() {
  _require_opensuse_family
  check_sudo

  log_step "PostInstallHUB · openSUSE"
  echo -e "${DIM}User: $(whoami)  ·  Host: $(hostname)${NC}"
  echo -e "${DIM}POSTINSTALL_YES=${POSTINSTALL_YES:-0}  ·  OPENSUSE_PACKMAN=${OPENSUSE_PACKMAN:-0}  ·  OPENSUSE_NVIDIA=${OPENSUSE_NVIDIA:-0}  ·  OPENSUSE_GAMING=${OPENSUSE_GAMING:-0}${NC}\n"

  # Core steps (always run)
  _step_update
  _step_essential
  _step_flatpak
  _step_zsh

  # Optional steps (gated by env flags)
  if [[ "${OPENSUSE_PACKMAN:-0}" == "1" ]]; then
    _step_packman
  fi

  if [[ "${OPENSUSE_NVIDIA:-0}" == "1" ]]; then
    _step_nvidia
  fi

  if [[ "${OPENSUSE_GAMING:-0}" == "1" ]]; then
    _step_gaming
  fi

  _step_dotfiles

  echo ""
  log_success "All automated steps complete!"
  log_warning "Reboot recommended to apply all changes."
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_install "$@"
fi
