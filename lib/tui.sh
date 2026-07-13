#!/usr/bin/env bash
# =============================================================================
# lib/tui.sh — Interactive flag-configuration menu for PostInstallHUB
# =============================================================================
# Called by install.sh BEFORE running the distro script.
# Shows a numbered [x] / [●] menu — type a number to toggle, Enter to start.
#
# Behaviour:
#   POSTINSTALL_YES=1          → skip TUI entirely (CI / batch mode)
#   POSTINSTALL_PICKER=auto    → try GUI picker first (rofi > fzf), fall back to text TUI (default)
#   POSTINSTALL_PICKER=tui     → force text TUI, skip GUI picker entirely
#   POSTINSTALL_PICKER=gui     → force GUI picker (exit 1 if rofi/fzf unavailable)
#   Selecting a flag           → exports the env var for the distro script to consume
#
# Items per distro:
#   All     : POSTINSTALL_YES checkbox + 3 dotfile radio buttons
#   Ubuntu  : + UBUNTU_NVIDIA · UBUNTU_DEBLOAT · UBUNTU_SNAP
#   Arch    : + ARCH_DOCKER · ARCH_LTS
#   Endeavour/CachyOS: + GAMING · PLYMOUTH · WAYDROID · FISH
#   Fedora  : + FEDORA_NVIDIA · FEDORA_CUDA · FEDORA_DNS
#   Debian  : + NVIDIA · CUDA · GAMING · DEBLOAT · ZSWAP
#   Kali    : dotfiles = zerodaygym (Kali-only) or caelestia
# =============================================================================

[[ -n "${_TUI_LOADED:-}" ]] && return 0
_TUI_LOADED=1

_TUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/picker.sh
source "${_TUI_DIR}/picker.sh"

# ── Render ─────────────────────────────────────────────────────────────────────
_tui_render() {
  local distro="$1"
  local -n _bk="$2" _bv="$3" _bd="$4" # bool: keys · vals · descs
  local -n _rk="$5" _rd="$6"          # radio: keys · descs
  local _rs="$7"                      # radio selected index (0-based)

  local pretty
  pretty=$(grep -oP '(?<=^PRETTY_NAME=).+' /etc/os-release 2>/dev/null |
    tr -d '"' || echo "$distro")

  printf '\033[2J\033[H' # clear + cursor home (no tput dependency)

  printf '\n'
  printf '  %sPostInstallHUB%s  %sv0.1.0%s\n' "$BOLD" "$NC" "$DIM" "$NC"
  printf '\n'
  printf '  %sOS:%s  %-40s %suser: %s%s\n' \
    "$DIM" "$NC" "$pretty" "$DIM" "$(whoami)" "$NC"
  printf '\n'

  local sep="${DIM}  ──────────────────────────────────────────────────────${NC}"

  # ── Options (bool checkboxes) ─────────────────────────────────────────────────
  if ((${#_bk[@]} > 0)); then
    printf '%b\n' "$sep"
    printf '  %s  Options%s\n' "$BOLD" "$NC"
    printf '%b\n' "$sep"

    local i
    for ((i = 0; i < ${#_bk[@]}; i++)); do
      local n=$((i + 1))
      local mark
      if ((${_bv[$i]})); then
        mark="${GREEN}x${NC}"
      else
        mark=" "
      fi
      printf '  %s%d%s  [%b]  %-30s %s%s%s\n' \
        "$BOLD" "$n" "$NC" \
        "$mark" \
        "${_bk[$i]}" \
        "$DIM" "${_bd[$i]}" "$NC"
    done
    printf '\n'
  fi

  # ── Dotfiles (radio — pick one) ───────────────────────────────────────────────
  printf '%b\n' "$sep"
  printf '  %s  Dotfiles%s  %s(pick one)%s\n' "$BOLD" "$NC" "$DIM" "$NC"
  printf '%b\n' "$sep"

  local bc=${#_bk[@]}
  for ((i = 0; i < ${#_rk[@]}; i++)); do
    local n=$((bc + i + 1))
    local mark
    if ((i == _rs)); then
      mark="${CYAN}●${NC}"
    else
      mark=" "
    fi
    printf '  %s%d%s  [%b]  %-30s %s%s%s\n' \
      "$BOLD" "$n" "$NC" \
      "$mark" \
      "${_rk[$i]}" \
      "$DIM" "${_rd[$i]}" "$NC"
  done

  local total=$((${#_bk[@]} + ${#_rk[@]}))
  printf '\n%b\n' "$sep"
  printf '  %s[1–%d]%s toggle  ·  %s[Enter]%s start  ·  %s[q]%s quit\n' \
    "$BOLD" "$total" "$NC" \
    "$BOLD" "$NC" \
    "$BOLD" "$NC"
  printf '%b\n\n' "$sep"
  printf '  ▶  '
}

# ── Public entry point ─────────────────────────────────────────────────────────
run_config_tui() {
  local distro="${1:-unknown}"

  # Skip entirely in CI / batch mode
  if [[ "${POSTINSTALL_YES:-0}" == "1" ]]; then
    return 0
  fi

  # ── GUI picker (rofi > fzf) — dotfiles pre-selection ──────────────────────────
  if [[ "${POSTINSTALL_PICKER:-auto}" != "tui" ]]; then
    local gui_dot
    gui_dot="$(pick_dotfiles_gui "$distro" 2>/dev/null || true)"
    if [[ -n "$gui_dot" ]]; then
      export POSTINSTALL_DOTFILES="$gui_dot"
      log_info "GUI picker selected dotfiles: ${gui_dot}"
      # Still run text TUI for bool flags unless POSTINSTALL_YES=1
    fi
  fi

  # ── Bool flags (ordered; parallel arrays) ─────────────────────────────────────
  local -a bkeys=() bvals=() bdescs=()

  # POSTINSTALL_YES is always item 1
  bkeys=("POSTINSTALL_YES")
  bvals=(0)
  bdescs=("Non-interactive — auto-approve all prompts")

  case "$distro" in
    ubuntu | zorin | linuxmint | pop | elementary | neon)
      bkeys+=(UBUNTU_NVIDIA UBUNTU_DEBLOAT UBUNTU_SNAP)
      bvals+=(0 0 0)
      bdescs+=(
        "Install NVIDIA proprietary drivers (ubuntu-drivers)"
        "Remove pre-installed bloatware (GNOME-focused)"
        "Enable Snap daemon + Snap apps"
      )
      ;;
    arch | manjaro)
      bkeys+=(ARCH_DOCKER ARCH_LTS)
      bvals+=(0 0)
      bdescs+=(
        "Install Docker + add user to docker group"
        "Install LTS kernel (linux-lts)"
      )
      ;;
    endeavouros | cachyos | garuda)
      bkeys+=(ENDEAVOUR_GAMING ENDEAVOUR_PLYMOUTH
        ENDEAVOUR_WAYDROID ENDEAVOUR_FISH)
      bvals+=(0 0
        0 0)
      bdescs+=(
        "Steam · Lutris · GameMode · GPU drivers"
        "Plymouth boot animation"
        "Waydroid (Android container)"
        "Fisher plugin manager for fish"
      )
      ;;
    fedora)
      bkeys+=(FEDORA_NVIDIA FEDORA_CUDA FEDORA_DNS)
      bvals+=(0 0 0)
      bdescs+=(
        "NVIDIA drivers (akmod-nvidia)"
        "CUDA support (requires FEDORA_NVIDIA=1)"
        "Cloudflare DNS over TLS"
      )
      ;;
    debian)
      bkeys+=(DEBIAN_NVIDIA DEBIAN_NVIDIA_CUDA
        DEBIAN_GAMING DEBIAN_DEBLOAT DEBIAN_ZSWAP)
      bvals+=(0 0
        0 0 0)
      bdescs+=(
        "NVIDIA open driver (nvidia-open)"
        "CUDA toolkit (implies DEBIAN_NVIDIA)"
        "Steam · Heroic · MangoHud via Flatpak"
        "Remove LibreOffice · KMail · Juk · Dragon"
        "Enable ZSWAP kernel parameter (systemd-boot)"
      )
      ;;
    opensuse-leap | opensuse-tumbleweed | opensuse)
      bkeys+=(OPENSUSE_NVIDIA OPENSUSE_GAMING OPENSUSE_PACKMAN)
      bvals+=(0 0 0)
      bdescs+=(
        "NVIDIA proprietary drivers (nvidia-glG06 or nvidia-open)"
        "Steam · Lutris · GameMode via Packman/Flatpak"
        "Add Packman repo + switch multimedia codecs"
      )
      ;;
    nixos)
      bkeys+=(NIXOS_UNFREE NIXOS_FLAKES NIXOS_HOME_MANAGER)
      bvals+=(0 0 0)
      bdescs+=(
        "Allow unfree packages (nixpkgs.config.allowUnfree)"
        "Enable Nix flakes + nix-command experimental features"
        "Install Home Manager as a NixOS module"
      )
      ;;
      # kali: no extra bool flags beyond POSTINSTALL_YES
  esac

  # ── Dotfiles radio (pick one — default: none) ─────────────────────────────────
  local -a rkeys=() rdescs=()
  local rsel=0 # index 0 = "none" by default

  if [[ "$distro" == "kali" ]]; then
    rkeys=(none zerodaygym caelestia)
    rdescs=(
      "Skip dotfiles"
      "i3-gaps security desktop — HTB/VPN modules  (Kali-only)"
      "Quickshell Hyprland desktop (via Nix)"
    )
  else
    rkeys=(none jakoolit caelestia)
    rdescs=(
      "Skip dotfiles"
      "Hyprland desktop (LinuxBeginnings/Hyprland-Dots)"
      "Quickshell Hyprland desktop (AUR or via Nix)"
    )
  fi

  local total=$((${#bkeys[@]} + ${#rkeys[@]}))
  local dirty=1

  # ── Interaction loop ───────────────────────────────────────────────────────────
  while true; do
    ((dirty)) && {
      _tui_render "$distro" bkeys bvals bdescs rkeys rdescs "$rsel"
      dirty=0
    }

    local key
    IFS= read -r -s -n1 key

    case "$key" in
      q | Q)
        printf '\033[2J\033[H\n'
        echo -e "${YELLOW}[INFO]${NC} Install cancelled."
        exit 0
        ;;
      '') # Enter → start install
        break
        ;;
      [1-9])
        local n=$((key - 1)) # convert to 0-based index
        local bc=${#bkeys[@]}

        if ((n >= 0 && n < bc)); then
          # Toggle bool checkbox
          bvals[$n]=$((1 - ${bvals[$n]}))
          dirty=1
        elif ((n >= bc && n < total)); then
          # Select radio (dotfiles) — exclusive
          rsel=$((n - bc))
          dirty=1
        fi
        ;;
    esac
  done

  # ── Export selections as env vars ──────────────────────────────────────────────
  printf '\033[2J\033[H\n'
  echo -e "${BOLD}Configuration summary:${NC}"

  local i
  for ((i = 0; i < ${#bkeys[@]}; i++)); do
    if ((${bvals[$i]})); then
      export "${bkeys[$i]}=1"
      echo -e "  ${GREEN}[x]${NC} ${bkeys[$i]}=1"
    else
      echo -e "  ${DIM}[ ] ${bkeys[$i]}=0${NC}"
    fi
  done

  local sel_dot="${rkeys[$rsel]}"
  if [[ "$sel_dot" != "none" ]]; then
    export "POSTINSTALL_DOTFILES=${sel_dot}"
    echo -e "  ${CYAN}[●]${NC} POSTINSTALL_DOTFILES=${sel_dot}"
  else
    echo -e "  ${DIM}[ ] POSTINSTALL_DOTFILES=none${NC}"
  fi

  echo ""
  echo -e "${DIM}  Starting in 3 s …  Ctrl+C to abort${NC}"
  sleep 3
  echo ""
}
