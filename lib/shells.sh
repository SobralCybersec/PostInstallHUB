#!/usr/bin/env bash
# lib/shells.sh — Fish and Nushell shell setup helpers for PostInstallHUB
#
# Expects common.sh already sourced by the caller.
# log_*, append_once, backup_warning, is_installed must be defined before
# this file is sourced. Do NOT source common.sh from here.
[[ -n "${_SHELLS_LIB_LOADED:-}" ]] && return 0
_SHELLS_LIB_LOADED=1

# ---------------------------------------------------------------------------
# _shells_detect_pm — returns: apt | pacman | dnf | zypper | unknown
# ---------------------------------------------------------------------------
_shells_detect_pm() {
  if is_installed apt-get; then
    echo apt
    return
  fi
  if is_installed pacman; then
    echo pacman
    return
  fi
  if is_installed dnf; then
    echo dnf
    return
  fi
  if is_installed zypper; then
    echo zypper
    return
  fi
  echo unknown
}

# ---------------------------------------------------------------------------
# _shells_pkg_install PKG [PKG…]
# Idempotent install via whichever package manager is present.
# Reuses apt_install from common.sh on Debian/Ubuntu (already idempotent).
# ---------------------------------------------------------------------------
_shells_pkg_install() {
  local pm
  pm="$(_shells_detect_pm)"
  case "$pm" in
    apt)
      # apt_install is already defined and idempotent when common.sh is sourced
      if declare -f apt_install &>/dev/null; then
        apt_install "$@"
      else
        sudo apt-get install -y "$@"
      fi
      ;;
    pacman)
      local to_install=()
      local pkg
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
      ;;
    dnf) sudo dnf install -y "$@" ;;
    zypper) sudo zypper install -y "$@" ;;
    *)
      log_error "shells.sh: no recognised package manager. Install manually: $*"
      return 1
      ;;
  esac
}

# ===========================================================================
# setup_fish
#
# 1. Install fish via detected package manager
# 2. Register in /etc/shells
# 3. Set as default shell via chsh
# 4. Install fisher plugin manager
# 5. Install plugins: nvm.fish, fzf.fish (if fzf present), tide@v6
# 6. Write ~/.config/fish/conf.d/postinstallhub.fish (marker-guarded)
#
# Reads: POSTINSTALL_YES (env, default 0)
# ===========================================================================
setup_fish() {
  log_step "shells.sh · Fish Shell Setup"

  # 1 — install ---------------------------------------------------------------
  if is_installed fish; then
    log_info "fish already installed: $(fish --version 2>/dev/null)"
  else
    log_info "Installing fish..."
    _shells_pkg_install fish
  fi

  local fish_path
  fish_path="$(command -v fish)"

  # 2 — /etc/shells -----------------------------------------------------------
  if grep -qF "$fish_path" /etc/shells 2>/dev/null; then
    log_info "fish already in /etc/shells."
  else
    echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    log_success "fish added to /etc/shells: ${fish_path}"
  fi

  # 3 — default shell ---------------------------------------------------------
  local current_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current_shell" == "$fish_path" ]]; then
    log_info "fish already the default shell."
  else
    log_info "Setting fish as default shell via chsh..."
    backup_warning "/etc/passwd"
    chsh -s "$fish_path" "$USER"
    log_success "Default shell → fish (takes effect on next login)."
  fi

  # 4 — fisher ----------------------------------------------------------------
  if fish -c "type -q fisher" 2>/dev/null; then
    log_info "fisher already installed."
  else
    log_info "Installing fisher..."
    fish -c "curl -sL \
      https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish \
      | source && fisher install jorgebucaran/fisher"
    log_success "fisher installed."
  fi

  # 5 — plugins ---------------------------------------------------------------
  # nvm.fish
  if fish -c "fisher list 2>/dev/null" | grep -q "nvm.fish"; then
    log_info "fisher plugin already present: nvm.fish"
  else
    fish -c "fisher install jorgebucaran/nvm.fish" &&
      log_success "fisher: nvm.fish installed." ||
      log_warning "fisher: nvm.fish install failed — skipping."
  fi

  # fzf.fish — only when fzf is on PATH
  if is_installed fzf; then
    if fish -c "fisher list 2>/dev/null" | grep -q "fzf.fish"; then
      log_info "fisher plugin already present: fzf.fish"
    else
      fish -c "fisher install PatrickF1/fzf.fish" &&
        log_success "fisher: fzf.fish installed." ||
        log_warning "fisher: fzf.fish install failed — skipping."
    fi
  else
    log_info "fzf not found — skipping PatrickF1/fzf.fish."
  fi

  # tide@v6 prompt
  if fish -c "fisher list 2>/dev/null" | grep -q "tide"; then
    log_info "fisher plugin already present: tide"
  else
    fish -c "fisher install IlanCosman/tide@v6" &&
      log_success "fisher: tide@v6 installed." ||
      log_warning "fisher: tide install failed — skipping."
  fi

  # 6 — fish config -----------------------------------------------------------
  local fish_conf_dir="${HOME}/.config/fish/conf.d"
  local fish_conf="${fish_conf_dir}/postinstallhub.fish"
  local fish_marker="# PostInstallHUB fish config"

  mkdir -p "$fish_conf_dir"

  if [[ -f "$fish_conf" ]] && grep -qF "$fish_marker" "$fish_conf" 2>/dev/null; then
    log_info "fish config already written: ${fish_conf}"
  else
    [[ -f "$fish_conf" ]] && backup_warning "$fish_conf"
    cat >"$fish_conf" <<'FISHCONF'
# PostInstallHUB fish config
# Generated by lib/shells.sh — safe to edit. Marker above ensures idempotency.

# Editor
set -gx EDITOR nvim

# PATH
fish_add_path "$HOME/.local/bin"

# Abbreviations (expand on Space, unlike aliases)
abbr -a ll   'eza -la'
abbr -a la   'eza -la'
abbr -a cat  'bat'
abbr -a grep 'grep --color=auto'
FISHCONF
    log_success "fish config written: ${fish_conf}"
  fi

  log_success "Fish shell setup complete. Re-login or run 'exec fish' to activate."
}

# ===========================================================================
# setup_nushell
#
# 1. Install nushell via detected package manager
# 2. Create ~/.config/nushell/ if absent
# 3. Append PostInstallHUB block to env.nu  (marker-guarded)
# 4. Append aliases to config.nu            (marker-guarded)
# 5. Register in /etc/shells; offer chsh (prompt unless POSTINSTALL_YES=1)
#
# Reads: POSTINSTALL_YES (env, default 0)
# ===========================================================================
setup_nushell() {
  log_step "shells.sh · Nushell Setup"

  # 1 — install ---------------------------------------------------------------
  if is_installed nu; then
    log_info "nushell already installed: $(nu --version 2>/dev/null)"
  else
    log_info "Installing nushell..."
    _shells_pkg_install nushell
  fi

  local nu_path
  nu_path="$(command -v nu 2>/dev/null || true)"
  if [[ -z "$nu_path" ]]; then
    log_error "nushell binary 'nu' not found after install — aborting setup_nushell."
    return 1
  fi

  # 2 — config directory ------------------------------------------------------
  local nu_dir="${HOME}/.config/nushell"
  mkdir -p "$nu_dir"

  local env_nu="${nu_dir}/env.nu"
  local cfg_nu="${nu_dir}/config.nu"
  # Touch so backup_warning and append work even before first `nu` run
  [[ -f "$env_nu" ]] || touch "$env_nu"
  [[ -f "$cfg_nu" ]] || touch "$cfg_nu"

  # 3 — env.nu ----------------------------------------------------------------
  local env_marker="# PostInstallHUB env.nu"
  if grep -qF "$env_marker" "$env_nu" 2>/dev/null; then
    log_info "env.nu already configured."
  else
    backup_warning "$env_nu"
    cat >>"$env_nu" <<'ENV_NU'

# PostInstallHUB env.nu
$env.EDITOR = "nvim"
$env.PATH = ($env.PATH | prepend $"($env.HOME)/.local/bin")
ENV_NU
    log_success "env.nu: EDITOR + PATH written."
  fi

  # 4 — config.nu -------------------------------------------------------------
  local cfg_marker="# PostInstallHUB config.nu"
  if grep -qF "$cfg_marker" "$cfg_nu" 2>/dev/null; then
    log_info "config.nu already configured."
  else
    backup_warning "$cfg_nu"

    # bat alias — use bat or batcat, whichever is available
    local bat_bin=""
    if is_installed bat; then bat_bin="$(command -v bat)"; fi
    if is_installed batcat; then bat_bin="$(command -v batcat)"; fi

    {
      printf '\n%s\n' "# PostInstallHUB config.nu"
      printf '%s\n' "alias ll = ls -la"
      printf '%s\n' "alias la = ls -la"
      [[ -n "$bat_bin" ]] && printf 'alias cat = %s\n' "$bat_bin"
    } >>"$cfg_nu"
    log_success "config.nu: aliases written."
  fi

  # 5 — /etc/shells + optional chsh -------------------------------------------
  if grep -qF "$nu_path" /etc/shells 2>/dev/null; then
    log_info "nushell already in /etc/shells."
  else
    echo "$nu_path" | sudo tee -a /etc/shells >/dev/null
    log_success "nushell added to /etc/shells: ${nu_path}"
  fi

  local current_shell
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current_shell" == "$nu_path" ]]; then
    log_info "nushell already the default shell."
  elif [[ "${POSTINSTALL_YES:-0}" == "1" ]]; then
    log_info "POSTINSTALL_YES=1 — skipping default shell change to nushell."
  else
    echo -e "Set nushell as your default shell? [y/N]"
    read -r _nu_yn
    if [[ "${_nu_yn:-N}" =~ ^[Yy]$ ]]; then
      backup_warning "/etc/passwd"
      chsh -s "$nu_path" "$USER"
      log_success "Default shell → nushell (takes effect on next login)."
    else
      log_info "Skipped. Run 'chsh -s ${nu_path}' to switch later."
    fi
  fi

  log_success "Nushell setup complete."
}
