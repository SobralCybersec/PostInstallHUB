#!/usr/bin/env bash
# =============================================================================
# scripts/linux/nixos.sh — NixOS post-install setup
#
# NixOS is declarative — this script does NOT install packages directly.
# Instead it: configures channels or flakes, appends config snippets to
# /etc/nixos/configuration.nix idempotently, runs nixos-rebuild, and
# optionally wires up Home Manager as a NixOS module.
#
# Called by install.sh:
#   source scripts/linux/nixos.sh && run_install
#
# Or run directly:
#   bash scripts/linux/nixos.sh
#
# Optional env flags:
#   NIXOS_FLAKES=1           — enable flakes in configuration.nix + rebuild
#   NIXOS_UNFREE=1           — allow unfree packages in configuration.nix
#   NIXOS_HOME_MANAGER=1     — add home-manager 24.11 channel + NixOS module
#   POSTINSTALL_YES=1        — non-interactive (skip prompts)
#   POSTINSTALL_DOTFILES=none|jakoolit|caelestia
#     jakoolit   — Hyprland desktop (LinuxBeginnings/Hyprland-Dots)
#                  NixOS is a supported distro
#     caelestia  — Quickshell Hyprland desktop; uses nix run on NixOS
# =============================================================================
set -euo pipefail

_NIXOS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_NIXOS_SCRIPT_DIR}/common.sh"
source "${_NIXOS_SCRIPT_DIR}/dotfiles.sh"

_NIXOS_CONF="/etc/nixos/configuration.nix"
# Tracks whether any config snippet was appended this session
_NIXOS_CONFIG_CHANGED=0

# ============================================================================
# NixOS-specific helpers
# ============================================================================

# nix_config_has MARKER — returns 0 if MARKER is present in configuration.nix
nix_config_has() {
  local marker="$1"
  grep -qF "$marker" "$_NIXOS_CONF" 2>/dev/null
}

# nix_config_append MARKER SNIPPET
#   Idempotently appends SNIPPET to configuration.nix using backup_warning.
nix_config_append() {
  local marker="$1"
  local snippet="$2"

  if nix_config_has "$marker"; then
    log_info "configuration.nix: already contains '${marker}' — skipped"
    return 0
  fi

  backup_warning "$_NIXOS_CONF"
  printf '\n%s\n' "$snippet" | sudo tee -a "$_NIXOS_CONF" >/dev/null
  log_success "configuration.nix: appended '${marker}'"
  _NIXOS_CONFIG_CHANGED=1
}

# ============================================================================
# OS guard
# ============================================================================
_require_nixos() {
  local id
  id="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release 2>/dev/null | tr -d '"' || echo unknown)"
  if [[ "$id" != "nixos" ]]; then
    log_error "Wrong OS: expected 'nixos', got '${id}'."
    exit 5
  fi
}

# ============================================================================
# STEP 1 — Channels (skipped when NIXOS_FLAKES=1)
# ============================================================================
_step_channels() {
  log_step "1 · Nix Channels"

  if [[ "${NIXOS_FLAKES:-0}" == "1" ]]; then
    log_info "NIXOS_FLAKES=1 — skipping channel setup (flakes bypass channels)"
    return 0
  fi

  if sudo nix-channel --list 2>/dev/null | grep -q "nixpkgs-unstable"; then
    log_info "Channel nixpkgs-unstable already registered."
  else
    log_info "Adding nixpkgs-unstable channel…"
    sudo nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
    log_success "Channel registered: nixpkgs-unstable"
  fi

  log_info "Updating channels…"
  sudo nix-channel --update
  log_success "Channels up to date."
}

# ============================================================================
# STEP 2 — Flakes (only when NIXOS_FLAKES=1)
# ============================================================================
_step_flakes() {
  log_step "2 · Nix Flakes"

  if [[ "${NIXOS_FLAKES:-0}" != "1" ]]; then
    log_info "NIXOS_FLAKES not set — skipping"
    return 0
  fi

  local marker='# PostInstallHUB — flakes'
  local snippet='  # PostInstallHUB — flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];'

  nix_config_append "$marker" "$snippet"

  # Rebuild immediately so subsequent nix commands can use flakes
  if [[ "$_NIXOS_CONFIG_CHANGED" == "1" ]]; then
    log_info "Rebuilding to activate flakes…"
    sudo nixos-rebuild switch
    log_success "nixos-rebuild switch: flakes enabled"
    _NIXOS_CONFIG_CHANGED=0 # this rebuild consumed the pending change
  fi
}

# ============================================================================
# STEP 3 — Unfree packages (only when NIXOS_UNFREE=1)
# ============================================================================
_step_unfree() {
  log_step "3 · Unfree Packages"

  if [[ "${NIXOS_UNFREE:-0}" != "1" ]]; then
    log_info "NIXOS_UNFREE not set — skipping"
    return 0
  fi

  local marker='# PostInstallHUB — allowUnfree'
  local snippet='  # PostInstallHUB — allowUnfree
  nixpkgs.config.allowUnfree = true;'

  nix_config_append "$marker" "$snippet"
}

# ============================================================================
# STEP 4 — Home Manager as NixOS module (only when NIXOS_HOME_MANAGER=1)
# ============================================================================
_step_home_manager() {
  log_step "4 · Home Manager"

  if [[ "${NIXOS_HOME_MANAGER:-0}" != "1" ]]; then
    log_info "NIXOS_HOME_MANAGER not set — skipping"
    return 0
  fi

  # Add stable 24.11 channel
  if sudo nix-channel --list 2>/dev/null | grep -q "home-manager"; then
    log_info "home-manager channel already registered."
  else
    log_info "Adding home-manager 24.11 channel…"
    sudo nix-channel --add \
      https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz \
      home-manager
    sudo nix-channel --update
    log_success "home-manager channel registered (release-24.11)"
  fi

  # Wire as a NixOS module so nixos-rebuild manages both OS and home configs
  local marker='# PostInstallHUB — home-manager module'
  local snippet='  # PostInstallHUB — home-manager module
  # Manage home-manager via NixOS (nixos-rebuild switch handles both)
  imports = [ <home-manager/nixos> ];
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  # Add per-user config:
  # home-manager.users.<username> = { pkgs, ... }: {
  #   home.stateVersion = "24.11";
  #   home.packages = with pkgs; [ ... ];
  # };'

  nix_config_append "$marker" "$snippet"
}

# ============================================================================
# STEP 5 — Essential packages advisory
# ============================================================================
# We do NOT auto-edit environment.systemPackages — its structure varies across
# single-file, modular, and flake-based configs. Print what to add instead.
_step_essential_pkgs() {
  log_step "5 · Essential Packages (advisory)"

  cat <<'PKGS'

  Add these to environment.systemPackages in /etc/nixos/configuration.nix:

    environment.systemPackages = with pkgs; [
      git
      curl
      wget
      neovim
      ripgrep
      fd
      fzf
      bat
      eza
      htop
      zsh
    ];

  Then rebuild: sudo nixos-rebuild switch

  Tip: nix search nixpkgs <name>  — find the right package attribute name.

PKGS
}

# ============================================================================
# STEP 6 — Dotfiles
# ============================================================================
_step_dotfiles_nixos() {
  log_step "6 · Dotfiles"

  # jakoolit: LinuxBeginnings/Hyprland-Dots lists NixOS as a supported distro.
  # caelestia: nix run path is used automatically (no yay on NixOS).
  step_dotfiles
}

# ============================================================================
# STEP 7 — Final rebuild (only if any config changes were made)
# ============================================================================
_step_rebuild() {
  log_step "7 · Final nixos-rebuild switch"

  if [[ "$_NIXOS_CONFIG_CHANGED" == "0" ]]; then
    log_info "No pending configuration changes — skipping rebuild."
    return 0
  fi

  log_info "Running: sudo nixos-rebuild switch"
  sudo nixos-rebuild switch
  log_success "nixos-rebuild switch: complete"
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
║  PACKAGES — add to environment.systemPackages then rebuild       ║
║    sudo nano /etc/nixos/configuration.nix                        ║
║    sudo nixos-rebuild switch                                     ║
║                                                                  ║
║  HOME MANAGER — per-user config (after NIXOS_HOME_MANAGER=1)   ║
║    home-manager.users.<you> = { pkgs, ... }: {                  ║
║      home.stateVersion = "24.11";                                ║
║      home.packages = with pkgs; [ ... ];                         ║
║    };                                                            ║
║                                                                  ║
║  FLAKES — initialise your config as a flake after step 2        ║
║    cd /etc/nixos && sudo nix flake init                          ║
║    Move configuration.nix content into flake.nix outputs        ║
║                                                                  ║
║  GARBAGE COLLECT — reclaim disk space                            ║
║    sudo nix-collect-garbage -d                                   ║
║                                                                  ║
║  GENERATIONS — list / rollback                                   ║
║    sudo nixos-rebuild list-generations                           ║
║    sudo nixos-rebuild switch --rollback                          ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
MANUAL
}

# ============================================================================
# run_install — orchestrator (called by install.sh)
# ============================================================================
run_install() {
  _require_nixos
  check_sudo

  log_step "PostInstallHUB · NixOS"
  echo -e "${DIM}User: $(whoami)  ·  Host: $(hostname)${NC}"
  echo -e "${DIM}NIXOS_FLAKES=${NIXOS_FLAKES:-0}  ·  NIXOS_UNFREE=${NIXOS_UNFREE:-0}  ·  NIXOS_HOME_MANAGER=${NIXOS_HOME_MANAGER:-0}${NC}\n"

  _step_channels
  _step_flakes
  _step_unfree
  _step_home_manager
  _step_essential_pkgs
  _step_dotfiles_nixos
  _step_rebuild

  echo ""
  log_success "All automated steps complete!"
  _print_manual_steps
}

# Allow direct execution: bash scripts/linux/nixos.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_install "$@"
fi
