#!/usr/bin/env bash
# =============================================================================
# lib/picker.sh — GUI/fuzzy dotfiles picker for PostInstallHUB
# Provides pick_dotfiles_gui() which uses rofi > fzf > fallback-to-TUI
#
# POSTINSTALL_PICKER=auto  → try GUI first, fall back to text TUI (default)
# POSTINSTALL_PICKER=tui   → force text TUI, skip this entirely
# POSTINSTALL_PICKER=gui   → force GUI, exit 1 if no GUI available
# =============================================================================

[[ -n "${_PICKER_LOADED:-}" ]] && return 0
_PICKER_LOADED=1

# ── Internal: build choices array by distro ─────────────────────────────────
_picker_choices() {
  local distro="$1"
  local -n _out="$2"
  if [[ "$distro" == "kali" ]]; then
    _out=(
      "none - Skip dotfiles"
      "zerodaygym - i3-gaps security desktop (Kali-only)"
      "caelestia - Quickshell Hyprland (via Nix)"
    )
  else
    _out=(
      "none - Skip dotfiles"
      "jakoolit - Hyprland-Dots (LinuxBeginnings)"
      "caelestia - Quickshell Hyprland (via Nix)"
    )
  fi
}

# ── Internal: strip description, return preset name only ───────────────────
_picker_strip() {
  # "zerodaygym - i3-gaps …" → "zerodaygym"
  echo "${1%% - *}"
}

# ── Internal: detect usable display env ────────────────────────────────────
_picker_has_display() {
  [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]
}

# ── Internal: detect terminal (stdin is a tty) ──────────────────────────────
_picker_has_tty() {
  [[ -t 0 ]]
}

# ── pick_dotfiles_gui ───────────────────────────────────────────────────────
# Usage: chosen=$(pick_dotfiles_gui "$distro")
# Returns preset name (none|jakoolit|caelestia|zerodaygym) on stdout.
# Returns empty string when no GUI is available (caller falls back to TUI).
pick_dotfiles_gui() {
  local distro="${1:-unknown}"
  local -a choices=()
  _picker_choices "$distro" choices

  local chosen=""

  if command -v rofi &>/dev/null && _picker_has_display; then
    chosen=$(printf '%s\n' "${choices[@]}" |
      rofi -dmenu \
        -p "PostInstallHUB › Dotfiles" \
        -theme-str 'window {width: 600px;}' \
        -mesg "Select dotfiles preset" \
        2>/dev/null) || true

  elif command -v fzf &>/dev/null && _picker_has_tty; then
    chosen=$(printf '%s\n' "${choices[@]}" |
      fzf --prompt="PostInstallHUB › Dotfiles: " \
        --height=40% \
        --border \
        --header="Select a dotfiles preset (↑↓ navigate, Enter select)" \
        2>/dev/null) || true

  else
    if [[ "${POSTINSTALL_PICKER:-auto}" == "gui" ]]; then
      echo "picker.sh: --gui requested but rofi/fzf not found or no display" >&2
      exit 1
    fi
    echo ""
    return 0
  fi

  [[ -z "$chosen" ]] && {
    echo ""
    return 0
  }

  _picker_strip "$chosen"
}

# ── pick_flags_gui ──────────────────────────────────────────────────────────
# Usage: mapfile -t selected < <(pick_flags_gui "$distro")
# Returns selected flag names (newline-separated) via stdout.
# Caller: for each name, export "${name}=1"
# Returns empty when no GUI is available.
pick_flags_gui() {
  local distro="${1:-unknown}"

  # Build flag list matching tui.sh's bkeys case block
  local -a flags=()
  case "$distro" in
    ubuntu | zorin | linuxmint | pop | elementary | neon)
      flags=(UBUNTU_NVIDIA UBUNTU_DEBLOAT UBUNTU_SNAP)
      ;;
    arch | manjaro)
      flags=(ARCH_DOCKER ARCH_LTS)
      ;;
    endeavouros | cachyos | garuda)
      flags=(ENDEAVOUR_GAMING ENDEAVOUR_PLYMOUTH ENDEAVOUR_WAYDROID ENDEAVOUR_FISH)
      ;;
    fedora)
      flags=(FEDORA_NVIDIA FEDORA_CUDA FEDORA_DNS)
      ;;
    debian)
      flags=(DEBIAN_NVIDIA DEBIAN_NVIDIA_CUDA DEBIAN_GAMING DEBIAN_DEBLOAT DEBIAN_ZSWAP)
      ;;
    kali | *)
      # kali: no extra bool flags
      echo ""
      return 0
      ;;
  esac

  ((${#flags[@]} == 0)) && {
    echo ""
    return 0
  }

  local selected=""

  if command -v rofi &>/dev/null && _picker_has_display; then
    selected=$(printf '%s\n' "${flags[@]}" |
      rofi -dmenu \
        -multi-select \
        -p "PostInstallHUB › Options" \
        -mesg "Space to multi-select, Enter to confirm" \
        2>/dev/null) || true

  elif command -v fzf &>/dev/null && _picker_has_tty; then
    selected=$(printf '%s\n' "${flags[@]}" |
      fzf --multi \
        --prompt="PostInstallHUB › Options: " \
        --height=60% \
        --border \
        --header="Tab to multi-select, Enter to confirm" \
        2>/dev/null) || true

  else
    if [[ "${POSTINSTALL_PICKER:-auto}" == "gui" ]]; then
      echo "picker.sh: --gui requested but rofi/fzf not found or no display" >&2
      exit 1
    fi
    echo ""
    return 0
  fi

  echo "$selected"
}
