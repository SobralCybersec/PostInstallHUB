#!/usr/bin/env bash
# =============================================================================
# scripts/linux/dotfiles.sh — Dotfiles preset module for PostInstallHUB
# =============================================================================
# Sourced automatically by every distro script (via common.sh chain).
# Provides one public function: step_dotfiles
#
# Env vars:
#   POSTINSTALL_DOTFILES=none|jakoolit|caelestia|zerodaygym
#     none        — skip dotfiles entirely (default when POSTINSTALL_YES=1)
#     jakoolit    — LinuxBeginnings/Hyprland-Dots dispatcher
#                   Supported: Arch · Fedora · Ubuntu · Debian · OpenSUSE · NixOS
#                   NixOS is a supported distro (listed in LinuxBeginnings/Hyprland-Dots)
#                   Detects distro, clones sub-repo, runs its install.sh
#     caelestia   — caelestia-dots/shell (Quickshell desktop for Hyprland)
#                   Arch/EndeavourOS: installs via AUR (yay)
#                   Other: installs Nix (Determinate) then nix run
#     zerodaygym  — zerodaygym/zerodaygym-kali-dotfiles (KALI ONLY)
#                   i3-gaps · polybar · rofi · alacritty · pywal · Nord theme
#                   Custom Kali security-ops desktop with HTB/VPN modules
#
#   POSTINSTALL_YES=1 — when set and POSTINSTALL_DOTFILES is unset,
#                       skips dotfiles silently (CI / non-interactive mode)
#
# Examples:
#   POSTINSTALL_DOTFILES=jakoolit   bash scripts/linux/arch.sh
#   POSTINSTALL_DOTFILES=zerodaygym bash scripts/linux/kali.sh
#   POSTINSTALL_DOTFILES=caelestia  bash scripts/linux/endeavour.sh
#   POSTINSTALL_YES=1               bash scripts/linux/ubuntu.sh  # skip
# =============================================================================

[[ -n "${_DOTFILES_LOADED:-}" ]] && return 0
_DOTFILES_LOADED=1

# ── Preset: Jakoolit / LinuxBeginnings Hyprland-Dots ─────────────────────────
# Source: https://github.com/LinuxBeginnings/Hyprland-Dots
# What it does: detects distro → clones <Distro>-Hyprland sub-repo → runs
#               install.sh inside it. No prompts in the dispatcher itself;
#               sub-repo installer may prompt depending on distro.
# Supported: Arch (pacman), Fedora (dnf), Ubuntu 24.04–26.04,
#            Debian, OpenSUSE (zypper), NixOS
# NOT supported: Kali (apt but ID != "Debian GNU/Linux")
_dotfiles_jakoolit() {
  log_step "Dotfiles › Jakoolit Hyprland-Dots"
  log_info "Source: https://github.com/LinuxBeginnings/Hyprland-Dots"
  log_info "Detects distro → clones per-distro Hyprland repo → runs installer"

  if ! command -v git &>/dev/null; then
    log_error "git is required for Jakoolit dots — install git first."
    return 1
  fi

  if ! command -v curl &>/dev/null; then
    log_error "curl is required for Jakoolit dots — install curl first."
    return 1
  fi

  log_info "Running Distro-Hyprland.sh …"
  sh <(curl -fsSL \
    https://raw.githubusercontent.com/LinuxBeginnings/Hyprland-Dots/main/Distro-Hyprland.sh)

  log_success "Jakoolit Hyprland-Dots installed"
  log_info "Post-install: reboot → select Hyprland at the login screen"
}

# ── Preset: Caelestia (Quickshell desktop for Hyprland) ──────────────────────
# Source: https://github.com/caelestia-dots/shell
# What it does: Quickshell-based bar/launcher/OSD/notifs overlay for Hyprland
# Arch/EndeavourOS: installs via AUR (yay -S caelestia-shell-git) — preferred
# Other distros: installs Nix (Determinate Systems) then nix run
# Requires: Hyprland already running / installed
_dotfiles_caelestia() {
  log_step "Dotfiles › Caelestia Quickshell"
  log_info "Source: https://github.com/caelestia-dots/shell"
  log_info "Caelestia is a Hyprland desktop shell (bar · launcher · OSD · notifs)"

  # Arch / EndeavourOS: AUR path (no Nix overhead, best runtime compat)
  if command -v yay &>/dev/null; then
    log_info "yay detected → installing via AUR: caelestia-shell-git"
    yay -S --needed --noconfirm caelestia-shell-git
    log_success "Caelestia installed via AUR"
    log_info "Start with: caelestia shell -d   (or: qs -c caelestia)"
    return 0
  fi

  # Other distros: Nix flake path
  log_info "yay not found → using Nix flake path"

  if ! command -v nix &>/dev/null; then
    log_info "Nix not found — installing via Determinate Systems (enables flakes by default) …"
    curl --proto '=https' --tlsv1.2 -sSf -L \
      https://install.determinate.systems/nix \
      | sh -s -- install --no-confirm

    # Source nix into current shell session
    # shellcheck source=/dev/null
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
      source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    elif [[ -f "${HOME}/.nix-profile/etc/profile.d/nix.sh" ]]; then
      source "${HOME}/.nix-profile/etc/profile.d/nix.sh"
    fi
  fi

  if ! command -v nix &>/dev/null; then
    log_error "Nix installation failed — cannot install Caelestia via flake"
    log_info "Try manually: https://install.determinate.systems/nix"
    return 1
  fi

  log_info "Running: nix run github:caelestia-dots/shell#with-cli"
  nix run github:caelestia-dots/shell#with-cli

  log_success "Caelestia launched via Nix"
  log_info "Re-run after reboot with: nix run github:caelestia-dots/shell#with-cli"
}

# ── Preset: ZeroDayGym Kali i3-gaps security desktop ─────────────────────────
# Source: https://github.com/zerodaygym/zerodaygym-kali-dotfiles
# What it does (from install.sh audit):
#   • apt install: i3 i3-wm i3blocks i3status polybar rofi alacritty kitty
#                  terminator gnome-terminal tmux pywal arc-theme papirus-icons
#                  feh imagemagick compton arandr flameshot lxappearance
#                  cargo xcb/pango/meson build libs for i3-gaps from source
#   • Builds i3-gaps from source (Airblader/i3)
#   • Installs Nerd Fonts (Iosevka, RobotoMono, Hack)
#   • Copies dotfiles: .bashrc .tmux.conf nvim/ kitty/ polybar/ i3/ rofi/
#   • Installs TPM + tmux-themepack
#   • Installs Nord rofi theme
#   • Sets up HTB VPN / target scripts in ~/.config/bin/
# KALI ONLY — apt-based, Kali-specific paths
# Runs non-interactively (no prompts). Requires sudo.
_dotfiles_zerodaygym() {
  log_step "Dotfiles › ZeroDayGym Kali i3-gaps"
  log_info "Source: https://github.com/zerodaygym/zerodaygym-kali-dotfiles"
  log_info "Installs: i3-gaps (src) · polybar · rofi · alacritty · pywal · Nord · HTB scripts"

  # Guard: Kali only
  local distro_id
  distro_id=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"' || echo "unknown")
  if [[ "$distro_id" != "kali" ]]; then
    log_error "ZeroDayGym dotfiles require Kali Linux (current distro: ${distro_id})"
    log_info "Use POSTINSTALL_DOTFILES=jakoolit or caelestia for non-Kali distros."
    return 1
  fi

  # Requires git + sudo
  if ! command -v git &>/dev/null; then
    log_info "git not found — installing …"
    sudo apt-get install -y git
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  log_info "Cloning zerodaygym-kali-dotfiles (depth=1) …"
  git clone --depth=1 \
    https://github.com/zerodaygym/zerodaygym-kali-dotfiles \
    "${tmpdir}/zdg"

  if [[ ! -f "${tmpdir}/zdg/install.sh" ]]; then
    log_error "install.sh not found in repo — structure may have changed upstream"
    return 1
  fi

  # The ZDG installer overwrites ~/.bashrc, ~/.tmux.conf, ~/.config/* silently.
  # Create backups before running (consistent with PostInstallHUB backup policy).
  local backup_ts
  backup_ts=$(date +%Y%m%d_%H%M%S)
  for f in "${HOME}/.bashrc" "${HOME}/.tmux.conf"; do
    if [[ -f "$f" ]]; then
      cp "$f" "${f}.postinstallhub.bak.${backup_ts}"
      log_info "Backed up ${f} → ${f}.postinstallhub.bak.${backup_ts}"
    fi
  done

  log_info "Running ZeroDayGym install.sh (sudo required — fully non-interactive) …"
  chmod +x "${tmpdir}/zdg/install.sh"
  (cd "${tmpdir}/zdg" && sudo ./install.sh)
  local exit_code=$?

  if (( exit_code == 0 )); then
    log_success "ZeroDayGym Kali i3-gaps desktop installed"
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   ZeroDayGym — Manual Steps Required         ║${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║                                              ║${NC}"
    echo -e "${BOLD}║  1. Reboot → select i3 at login screen       ║${NC}"
    echo -e "${BOLD}║  2. tmux: Ctrl+b → Shift+i (install plugins) ║${NC}"
    echo -e "${BOLD}║  3. lxappearance → select Arc-Dark theme      ║${NC}"
    echo -e "${BOLD}║  4. pywal -i /path/to/wallpaper               ║${NC}"
    echo -e "${BOLD}║  5. echo 'IP' > ~/.config/bin/target          ║${NC}"
    echo -e "${BOLD}║     (sets HTB target for polybar module)       ║${NC}"
    echo -e "${BOLD}║                                              ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
  else
    log_error "ZeroDayGym installer exited with code ${exit_code}"
    return "$exit_code"
  fi
}

# ── Interactive preset selection ──────────────────────────────────────────────
_dotfiles_select_interactive() {
  local distro_id
  distro_id=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"' || echo "unknown")

  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║              Dotfiles Preset Selection                   ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${DIM}0) none        — skip dotfiles (press Enter for default)${NC}"

  if [[ "$distro_id" != "kali" ]]; then
    echo -e "  1) jakoolit    — Hyprland desktop (Arch · Fedora · Ubuntu · Debian)"
    echo -e "  2) caelestia   — Quickshell Hyprland desktop (AUR or Nix)"
  else
    echo -e "  3) zerodaygym  — i3-gaps security desktop ${BOLD}(Kali only)${NC}"
    echo -e "  2) caelestia   — Quickshell Hyprland desktop (via Nix)"
  fi

  echo ""
  echo -e "  ${DIM}Or set POSTINSTALL_DOTFILES=<preset> to skip this prompt.${NC}"
  echo ""

  local choice
  read -r -p "Select preset [0]: " choice
  choice="${choice:-0}"

  case "$choice" in
    1) echo "jakoolit" ;;
    2) echo "caelestia" ;;
    3) echo "zerodaygym" ;;
    *) echo "none" ;;
  esac
}

# ── Public entry point ────────────────────────────────────────────────────────
# Called by every distro's run_install() after all main steps complete.
step_dotfiles() {
  local preset="${POSTINSTALL_DOTFILES:-}"

  # No preset set: either ask (interactive) or skip (POSTINSTALL_YES=1 / CI)
  if [[ -z "$preset" ]]; then
    if [[ "${POSTINSTALL_YES:-0}" == "1" ]]; then
      log_info "Dotfiles: skipped (set POSTINSTALL_DOTFILES=<preset> to enable)"
      return 0
    fi
    preset=$(_dotfiles_select_interactive)
  fi

  case "${preset,,}" in   # lowercase match
    none | "")
      log_info "Dotfiles: none selected — skipped"
      ;;
    jakoolit)
      _dotfiles_jakoolit
      ;;
    caelestia)
      _dotfiles_caelestia
      ;;
    zerodaygym | zdg)
      _dotfiles_zerodaygym
      ;;
    *)
      log_warning "Unknown dotfiles preset: '${preset}'"
      log_info "Valid: none · jakoolit · caelestia · zerodaygym"
      ;;
  esac
}
