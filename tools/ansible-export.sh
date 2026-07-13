#!/usr/bin/env bash
# =============================================================================
# tools/ansible-export.sh — Export PostInstallHUB configuration as an Ansible playbook
#
# Usage:
#   bash tools/ansible-export.sh
#   bash tools/ansible-export.sh --distro=ubuntu --UBUNTU_NVIDIA=1 --POSTINSTALL_DOTFILES=jakoolit
#   bash tools/ansible-export.sh --output=my-workstation.yml
#
# Output: Ansible playbook YAML (default: postinstallhub-playbook.yml)
# Run:    ansible-playbook -i localhost, <output>
# =============================================================================
set -euo pipefail

_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT_DIR="$(cd "${_TOOLS_DIR}/.." && pwd)"

source "${_ROOT_DIR}/lib/colors.sh"

# ---------------------------------------------------------------------------
# Logging (mirrors common.sh style; no sudo needed here)
# ---------------------------------------------------------------------------
log_info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} ✓ $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} ⚠ $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   ✗ $*" >&2; }
log_step()    { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}"; }

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
DISTRO=""
OUTPUT="postinstallhub-playbook.yml"
POSTINSTALL_DOTFILES="${POSTINSTALL_DOTFILES:-none}"

# Distro flags (read from env or CLI)
UBUNTU_NVIDIA="${UBUNTU_NVIDIA:-0}"
UBUNTU_SNAP="${UBUNTU_SNAP:-0}"
UBUNTU_DEBLOAT="${UBUNTU_DEBLOAT:-0}"
ARCH_DOCKER="${ARCH_DOCKER:-0}"
ARCH_LTS="${ARCH_LTS:-0}"
FEDORA_NVIDIA="${FEDORA_NVIDIA:-0}"
FEDORA_CUDA="${FEDORA_CUDA:-0}"
FEDORA_DNS="${FEDORA_DNS:-0}"
OPENSUSE_PACKMAN="${OPENSUSE_PACKMAN:-0}"
OPENSUSE_NVIDIA="${OPENSUSE_NVIDIA:-0}"
OPENSUSE_GAMING="${OPENSUSE_GAMING:-0}"
DEBIAN_NVIDIA="${DEBIAN_NVIDIA:-0}"
DEBIAN_GAMING="${DEBIAN_GAMING:-0}"
DEBIAN_DEBLOAT="${DEBIAN_DEBLOAT:-0}"

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --distro=*)               DISTRO="${arg#*=}" ;;
    --output=*)               OUTPUT="${arg#*=}" ;;
    --POSTINSTALL_DOTFILES=*) POSTINSTALL_DOTFILES="${arg#*=}" ;;
    --UBUNTU_NVIDIA=*)        UBUNTU_NVIDIA="${arg#*=}" ;;
    --UBUNTU_SNAP=*)          UBUNTU_SNAP="${arg#*=}" ;;
    --UBUNTU_DEBLOAT=*)       UBUNTU_DEBLOAT="${arg#*=}" ;;
    --ARCH_DOCKER=*)          ARCH_DOCKER="${arg#*=}" ;;
    --ARCH_LTS=*)             ARCH_LTS="${arg#*=}" ;;
    --FEDORA_NVIDIA=*)        FEDORA_NVIDIA="${arg#*=}" ;;
    --FEDORA_CUDA=*)          FEDORA_CUDA="${arg#*=}" ;;
    --FEDORA_DNS=*)           FEDORA_DNS="${arg#*=}" ;;
    --OPENSUSE_PACKMAN=*)     OPENSUSE_PACKMAN="${arg#*=}" ;;
    --OPENSUSE_NVIDIA=*)      OPENSUSE_NVIDIA="${arg#*=}" ;;
    --OPENSUSE_GAMING=*)      OPENSUSE_GAMING="${arg#*=}" ;;
    --DEBIAN_NVIDIA=*)        DEBIAN_NVIDIA="${arg#*=}" ;;
    --DEBIAN_GAMING=*)        DEBIAN_GAMING="${arg#*=}" ;;
    --DEBIAN_DEBLOAT=*)       DEBIAN_DEBLOAT="${arg#*=}" ;;
    --help|-h)
      sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      log_warning "Unknown argument: ${arg} (ignored)"
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Auto-detect distro if not given
# ---------------------------------------------------------------------------
if [[ -z "$DISTRO" ]]; then
  if [[ -f /etc/os-release ]]; then
    DISTRO="$(grep -oP '(?<=^ID=)[^\n]+' /etc/os-release | tr -d '"' || echo unknown)"
  else
    DISTRO="unknown"
  fi
  log_info "Auto-detected distro: ${DISTRO}"
fi

# Normalise family aliases
case "$DISTRO" in
  zorin|linuxmint|pop|elementary|neon) DISTRO="ubuntu" ;;
  # ponytail: arch family shares identical Ansible tasks; endeavour/cachyos/garuda collapse here
  manjaro|endeavouros|cachyos|garuda)  DISTRO="arch" ;;
  opensuse-leap|opensuse-tumbleweed)   DISTRO="opensuse" ;;
esac

# ---------------------------------------------------------------------------
# Collect active flags for the header comment
# ---------------------------------------------------------------------------
_flags_summary() {
  local flags=()
  [[ "$UBUNTU_NVIDIA"    == "1" ]] && flags+=("UBUNTU_NVIDIA=1")
  [[ "$UBUNTU_SNAP"      == "1" ]] && flags+=("UBUNTU_SNAP=1")
  [[ "$UBUNTU_DEBLOAT"   == "1" ]] && flags+=("UBUNTU_DEBLOAT=1")
  [[ "$ARCH_DOCKER"      == "1" ]] && flags+=("ARCH_DOCKER=1")
  [[ "$ARCH_LTS"         == "1" ]] && flags+=("ARCH_LTS=1")
  [[ "$FEDORA_NVIDIA"    == "1" ]] && flags+=("FEDORA_NVIDIA=1")
  [[ "$FEDORA_CUDA"      == "1" ]] && flags+=("FEDORA_CUDA=1")
  [[ "$FEDORA_DNS"       == "1" ]] && flags+=("FEDORA_DNS=1")
  [[ "$OPENSUSE_PACKMAN" == "1" ]] && flags+=("OPENSUSE_PACKMAN=1")
  [[ "$OPENSUSE_NVIDIA"  == "1" ]] && flags+=("OPENSUSE_NVIDIA=1")
  [[ "$OPENSUSE_GAMING"  == "1" ]] && flags+=("OPENSUSE_GAMING=1")
  [[ "$DEBIAN_NVIDIA"    == "1" ]] && flags+=("DEBIAN_NVIDIA=1")
  [[ "$DEBIAN_GAMING"    == "1" ]] && flags+=("DEBIAN_GAMING=1")
  [[ "$DEBIAN_DEBLOAT"   == "1" ]] && flags+=("DEBIAN_DEBLOAT=1")
  [[ "$POSTINSTALL_DOTFILES" != "none" ]] && flags+=("POSTINSTALL_DOTFILES=${POSTINSTALL_DOTFILES}")
  if [[ ${#flags[@]} -eq 0 ]]; then
    echo "none"
  else
    echo "${flags[*]}"
  fi
}

# ---------------------------------------------------------------------------
# Task generators — each prints YAML task blocks to stdout
# ---------------------------------------------------------------------------

# Shared apt update block (ubuntu / debian / kali)
_tasks_apt_update() {
  cat <<'YAML'
    # STEP 1 — System Update
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600
      tags: [update]

    - name: Upgrade all packages
      apt:
        upgrade: dist
        autoremove: yes
        autoclean: yes
      tags: [update]

YAML
}

_tasks_ubuntu() {
  _tasks_apt_update

  cat <<'YAML'
    # STEP 2 — Essential packages
    - name: Install essential packages
      apt:
        name:
          - curl
          - wget
          - git
          - vim
          - neovim
          - htop
          - tree
          - tmux
          - unzip
          - build-essential
          - software-properties-common
          - apt-transport-https
          - ca-certificates
          - gnupg
          - lsb-release
          - terminator
          - flameshot
          - keepassxc
        state: present
      tags: [essential]

    # STEP 3 — Flatpak
    - name: Install Flatpak
      apt:
        name: flatpak
        state: present
      tags: [flatpak]

    - name: Add Flathub remote
      community.general.flatpak_remote:
        name: flathub
        state: present
        flatpakrepo_url: https://dl.flathub.org/repo/flathub.flatpakrepo
        method: system
      tags: [flatpak]

    - name: Install Flatpak apps
      community.general.flatpak:
        name:
          - org.libreoffice.LibreOffice
          - org.gimp.GIMP
          - com.obsproject.Studio
          - org.videolan.VLC
          - com.spotify.Client
          - com.discordapp.Discord
        state: present
        method: system
      tags: [flatpak]

YAML

  if [[ "$UBUNTU_SNAP" == "1" ]]; then
    cat <<'YAML'
    # STEP 4 — Snap (opt-in: UBUNTU_SNAP=1)
    - name: Ensure snapd is running
      service:
        name: snapd
        state: started
        enabled: yes
      tags: [snap]

    - name: Install snap packages
      community.general.snap:
        name:
          - slack
          - postman
        state: present
      tags: [snap]

YAML
  fi

  if [[ "$UBUNTU_NVIDIA" == "1" ]]; then
    cat <<'YAML'
    # STEP 5 — NVIDIA drivers (opt-in: UBUNTU_NVIDIA=1)
    - name: Add graphics-drivers PPA
      ansible.builtin.apt_repository:
        repo: ppa:graphics-drivers/ppa
        state: present
      tags: [nvidia]

    - name: Install NVIDIA driver
      apt:
        name: nvidia-driver-550
        state: present
      tags: [nvidia]

YAML
  fi

  if [[ "$UBUNTU_DEBLOAT" == "1" ]]; then
    cat <<'YAML'
    # STEP 6 — Debloat (opt-in: UBUNTU_DEBLOAT=1)
    - name: Remove bloatware packages
      apt:
        name:
          - aisleriot
          - gnome-mahjongg
          - gnome-mines
          - gnome-sudoku
          - thunderbird
          - rhythmbox
          - totem
        state: absent
        purge: yes
        autoremove: yes
      tags: [debloat]

YAML
  fi
}

_tasks_arch() {
  cat <<'YAML'
    # STEP 1 — System Update
    - name: Update all packages (pacman)
      community.general.pacman:
        update_cache: yes
        upgrade: yes
      tags: [update]

    # STEP 2 — Essential packages
    - name: Install essential packages
      community.general.pacman:
        name:
          - base-devel
          - git
          - curl
          - wget
          - vim
          - neovim
          - htop
          - tree
          - tmux
          - unzip
          - flatpak
          - zsh
          - reflector
          - rsync
          - python
          - go
        state: present
      tags: [essential]

    # STEP 3 — yay AUR helper
    - name: Check if yay is installed
      command: which yay
      register: yay_check
      failed_when: false
      changed_when: false
      tags: [aur]

    - name: Install yay AUR helper
      become: no
      shell: |
        cd /tmp
        git clone https://aur.archlinux.org/yay.git yay-build
        cd yay-build
        makepkg -si --noconfirm
        cd /tmp
        rm -rf yay-build
      args:
        executable: /bin/bash
      when: yay_check.rc != 0
      tags: [aur]

    # STEP 4 — AUR packages
    - name: Install AUR packages via yay
      become: no
      shell: "yay -S --noconfirm {{ item }}"
      loop:
        - visual-studio-code-bin
        - google-chrome
        - timeshift
        - flameshot
        - keepassxc
      register: yay_result
      changed_when: "'installing' in yay_result.stdout"
      tags: [aur]

YAML

  if [[ "$ARCH_DOCKER" == "1" ]]; then
    cat <<'YAML'
    # STEP 5 — Docker (opt-in: ARCH_DOCKER=1)
    - name: Install Docker
      community.general.pacman:
        name:
          - docker
          - docker-compose
        state: present
      tags: [docker]

    - name: Enable and start Docker service
      service:
        name: docker
        state: started
        enabled: yes
      tags: [docker]

    - name: Add current user to docker group
      user:
        name: "{{ ansible_user_id }}"
        groups: docker
        append: yes
      tags: [docker]

YAML
  fi

  if [[ "$ARCH_LTS" == "1" ]]; then
    cat <<'YAML'
    # STEP 6 — LTS kernel (opt-in: ARCH_LTS=1)
    - name: Install LTS kernel
      community.general.pacman:
        name:
          - linux-lts
          - linux-lts-headers
        state: present
      tags: [kernel, lts]

    - name: Regenerate GRUB config for LTS kernel
      command: grub-mkconfig -o /boot/grub/grub.cfg
      tags: [kernel, lts]

YAML
  fi
}

_tasks_fedora() {
  cat <<'YAML'
    # STEP 1 — System Update
    - name: Update all packages (dnf)
      dnf:
        name: "*"
        state: latest
        update_cache: yes
      tags: [update]

    # STEP 2 — RPM Fusion repos
    - name: Enable RPM Fusion Free
      dnf:
        name: "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-{{ ansible_distribution_major_version }}.noarch.rpm"
        state: present
        disable_gpg_check: yes
      tags: [repos]

    - name: Enable RPM Fusion Non-Free
      dnf:
        name: "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-{{ ansible_distribution_major_version }}.noarch.rpm"
        state: present
        disable_gpg_check: yes
      tags: [repos]

    # STEP 3 — Essential packages
    - name: Install essential packages
      dnf:
        name:
          - curl
          - wget
          - git
          - vim
          - neovim
          - htop
          - tree
          - tmux
          - unzip
          - flatpak
          - zsh
          - gnome-tweaks
          - ffmpeg
          - vlc
          - flameshot
          - keepassxc
        state: present
      tags: [essential]

    # STEP 4 — Flathub
    - name: Add Flathub remote
      community.general.flatpak_remote:
        name: flathub
        state: present
        flatpakrepo_url: https://dl.flathub.org/repo/flathub.flatpakrepo
        method: system
      tags: [flatpak]

YAML

  if [[ "$FEDORA_NVIDIA" == "1" ]]; then
    cat <<'YAML'
    # STEP 5 — NVIDIA drivers (opt-in: FEDORA_NVIDIA=1)
    - name: Install NVIDIA driver via RPM Fusion
      dnf:
        name:
          - akmod-nvidia
          - xorg-x11-drv-nvidia-cuda
        state: present
      tags: [nvidia]

YAML
  fi

  if [[ "$FEDORA_CUDA" == "1" ]]; then
    cat <<'YAML'
    # STEP 6 — CUDA toolkit (opt-in: FEDORA_CUDA=1)
    - name: Add CUDA repo
      command: >
        dnf config-manager --add-repo
        https://developer.download.nvidia.com/compute/cuda/repos/fedora{{ ansible_distribution_major_version }}/x86_64/cuda-fedora{{ ansible_distribution_major_version }}.repo
      args:
        creates: /etc/yum.repos.d/cuda-fedora{{ ansible_distribution_major_version }}.repo
      tags: [cuda, nvidia]

    - name: Install CUDA toolkit
      dnf:
        name: cuda-toolkit
        state: present
      tags: [cuda, nvidia]

YAML
  fi

  if [[ "$FEDORA_DNS" == "1" ]]; then
    cat <<'YAML'
    # STEP 7 — DNS-over-TLS via systemd-resolved (opt-in: FEDORA_DNS=1)
    - name: Configure DNS-over-TLS in resolved.conf
      blockinfile:
        path: /etc/systemd/resolved.conf
        marker: "# {mark} POSTINSTALLHUB DNS-OVER-TLS"
        block: |
          DNS=1.1.1.1 1.0.0.1
          FallbackDNS=8.8.8.8
          DNSOverTLS=yes
      tags: [dns]

    - name: Restart systemd-resolved
      service:
        name: systemd-resolved
        state: restarted
        enabled: yes
      tags: [dns]

YAML
  fi
}

_tasks_opensuse() {
  cat <<'YAML'
    # STEP 1 — Refresh repos and update
    - name: Refresh zypper repos
      community.general.zypper_repository:
        repo: "*"
        runrefresh: yes
      tags: [update]

    - name: Update all packages (zypper)
      community.general.zypper:
        name: "*"
        state: latest
        update_cache: yes
      tags: [update]

    # STEP 2 — Essential packages
    - name: Install essential packages
      community.general.zypper:
        name:
          - curl
          - wget
          - git
          - vim
          - neovim
          - htop
          - tree
          - tmux
          - unzip
          - flatpak
          - zsh
          - flameshot
          - keepassxc
        state: present
      tags: [essential]

YAML

  if [[ "$OPENSUSE_PACKMAN" == "1" ]]; then
    cat <<'YAML'
    # STEP 3 — Packman repo (opt-in: OPENSUSE_PACKMAN=1)
    - name: Add Packman repo
      community.general.zypper_repository:
        name: packman
        repo: https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/
        state: present
        runrefresh: yes
      tags: [repos, packman]

    - name: Switch multimedia packages to Packman
      shell: zypper dup --from packman --allow-vendor-change -y
      args:
        executable: /bin/bash
      tags: [repos, packman]

YAML
  fi

  if [[ "$OPENSUSE_NVIDIA" == "1" ]]; then
    cat <<'YAML'
    # STEP 4 — NVIDIA drivers (opt-in: OPENSUSE_NVIDIA=1)
    - name: Add NVIDIA repo
      community.general.zypper_repository:
        name: nvidia
        repo: https://download.nvidia.com/opensuse/tumbleweed
        state: present
        runrefresh: yes
      tags: [nvidia]

    - name: Install NVIDIA driver
      community.general.zypper:
        name:
          - nvidia-video-G06
          - nvidia-compute-G06
        state: present
      tags: [nvidia]

YAML
  fi

  if [[ "$OPENSUSE_GAMING" == "1" ]]; then
    cat <<'YAML'
    # STEP 5 — Gaming (opt-in: OPENSUSE_GAMING=1)
    - name: Install gaming packages
      community.general.zypper:
        name:
          - steam
          - lutris
          - wine
          - gamemode
        state: present
      tags: [gaming]

YAML
  fi
}

_tasks_debian() {
  _tasks_apt_update

  cat <<'YAML'
    # STEP 2 — Essential packages
    - name: Install essential packages
      apt:
        name:
          - curl
          - wget
          - git
          - vim
          - neovim
          - htop
          - tree
          - tmux
          - unzip
          - build-essential
          - software-properties-common
          - apt-transport-https
          - ca-certificates
          - gnupg
          - flatpak
          - ufw
          - flameshot
          - keepassxc
          - timeshift
        state: present
      tags: [essential]

    # STEP 3 — UFW firewall defaults
    - name: Set UFW default deny incoming
      community.general.ufw:
        direction: incoming
        policy: deny
      tags: [ufw]

    - name: Set UFW default allow outgoing
      community.general.ufw:
        direction: outgoing
        policy: allow
      tags: [ufw]

    - name: Allow SSH through UFW
      community.general.ufw:
        rule: allow
        port: "22"
        proto: tcp
      tags: [ufw]

    - name: Enable UFW
      community.general.ufw:
        state: enabled
      tags: [ufw]

    # STEP 4 — Flatpak / Flathub
    - name: Add Flathub remote
      community.general.flatpak_remote:
        name: flathub
        state: present
        flatpakrepo_url: https://dl.flathub.org/repo/flathub.flatpakrepo
        method: system
      tags: [flatpak]

YAML

  if [[ "$DEBIAN_NVIDIA" == "1" ]]; then
    cat <<'YAML'
    # STEP 5 — NVIDIA drivers (opt-in: DEBIAN_NVIDIA=1)
    - name: Enable non-free and contrib components
      ansible.builtin.replace:
        path: /etc/apt/sources.list
        regexp: '(deb https?://\S+ \S+ main)$'
        replace: '\1 contrib non-free non-free-firmware'
      tags: [nvidia]

    - name: Update apt after enabling non-free
      apt:
        update_cache: yes
      tags: [nvidia]

    - name: Install NVIDIA driver
      apt:
        name:
          - nvidia-driver
          - firmware-misc-nonfree
        state: present
      tags: [nvidia]

YAML
  fi

  if [[ "$DEBIAN_GAMING" == "1" ]]; then
    cat <<'YAML'
    # STEP 6 — Gaming (opt-in: DEBIAN_GAMING=1)
    - name: Enable i386 architecture for Steam
      command: dpkg --add-architecture i386
      args:
        creates: /var/lib/dpkg/arch
      tags: [gaming]

    - name: Install gaming packages
      apt:
        name:
          - steam-installer
          - lutris
          - wine
          - gamemode
        state: present
        update_cache: yes
      tags: [gaming]

YAML
  fi

  if [[ "$DEBIAN_DEBLOAT" == "1" ]]; then
    cat <<'YAML'
    # STEP 7 — Debloat (opt-in: DEBIAN_DEBLOAT=1)
    - name: Remove bloatware packages
      apt:
        name:
          - gnome-games
          - evolution
          - rhythmbox
          - totem
        state: absent
        purge: yes
        autoremove: yes
      tags: [debloat]

YAML
  fi
}

_tasks_nixos() {
  cat <<'YAML'
    # NixOS — declarative; Ansible tasks are wrappers around nixos-rebuild
    - name: NixOS hint (declarative system)
      debug:
        msg: >
          NixOS is declarative. Edit /etc/nixos/configuration.nix manually,
          then run 'sudo nixos-rebuild switch'. Ansible can shell out to that
          command but cannot manage individual packages idempotently via modules.
      tags: [update]

    - name: Run nixos-rebuild switch
      shell: nixos-rebuild switch
      args:
        executable: /bin/bash
      tags: [update]

YAML
}

_tasks_kali() {
  _tasks_apt_update

  cat <<'YAML'
    # STEP 2 — Essential security tools
    - name: Install security and utility packages
      apt:
        name:
          - nmap
          - wireshark
          - burpsuite
          - metasploit-framework
          - aircrack-ng
          - hashcat
          - john
          - sqlmap
          - gobuster
          - dirb
          - nikto
          - wfuzz
          - ffuf
          - feroxbuster
          - enum4linux
          - seclists
          - wordlists
          - tmux
          - terminator
          - htop
          - vim
          - neovim
          - tree
          - git
          - curl
          - wget
          - tor
          - flameshot
          - keepassxc
        state: present
      tags: [essential, security]

    # STEP 3 — Python security libraries
    - name: Install Python security libraries
      pip:
        name:
          - requests
          - dnspython
          - termcolor
          - tldextract
          - colorama
          - cffi
          - beautifulsoup4
        state: present
      tags: [python]

    # STEP 4 — Wordlists
    - name: Gunzip rockyou.txt
      command: gunzip /usr/share/wordlists/rockyou.txt.gz
      args:
        creates: /usr/share/wordlists/rockyou.txt
      tags: [wordlists]

    - name: Create Wordlists symlink in home
      file:
        src: /usr/share/wordlists
        dest: "{{ ansible_env.HOME }}/Wordlists"
        state: link
      tags: [wordlists]

    # STEP 5 — UFW
    - name: Set UFW default deny incoming
      community.general.ufw:
        direction: incoming
        policy: deny
      tags: [ufw]

    - name: Allow SSH through UFW
      community.general.ufw:
        rule: allow
        port: "22"
        proto: tcp
      tags: [ufw]

    - name: Enable UFW
      community.general.ufw:
        state: enabled
      tags: [ufw]

YAML
}

# Dotfiles block — only emitted when POSTINSTALL_DOTFILES != none
_tasks_dotfiles() {
  local preset="$1"
  # Use printf to avoid heredoc quoting issues with the preset variable
  printf '    # Dotfiles\n'
  printf '    - name: Install dotfiles (%s)\n' "$preset"
  printf '      shell: |\n'
  printf '        if command -v chezmoi &>/dev/null; then\n'
  printf '          chezmoi init --apply %s\n' "$preset"
  printf '        elif command -v yadm &>/dev/null; then\n'
  printf '          yadm clone https://github.com/%s/dotfiles\n' "$preset"
  printf '        else\n'
  printf '          git clone --depth=1 https://github.com/%s/dotfiles "$HOME/.dotfiles"\n' "$preset"
  printf '          bash "$HOME/.dotfiles/install.sh"\n'
  printf '        fi\n'
  printf '      args:\n'
  printf '        executable: /bin/bash\n'
  printf '      become: no\n'
  printf '      tags: [dotfiles]\n'
  printf '      when: postinstall_dotfiles != "none"\n'
  printf '\n'
}

_tasks_summary() {
  cat <<'YAML'
    # Final summary
    - name: Print post-install summary
      debug:
        msg:
          - "PostInstallHUB setup complete."
          - "Distro   : {{ ansible_distribution }} {{ ansible_distribution_version }}"
          - "Hostname : {{ ansible_hostname }}"
          - "User     : {{ ansible_user_id }}"
          - "Reboot recommended if kernel or NVIDIA drivers were updated."
      tags: [summary]
YAML
}

# ---------------------------------------------------------------------------
# Playbook header — printed via printf to keep variable expansion explicit
# ---------------------------------------------------------------------------
_write_header() {
  local distro="$1"
  local flags_str="$2"
  local generated_date
  generated_date="$(date '+%Y-%m-%d %H:%M:%S')"
  local outbase
  outbase="$(basename "$OUTPUT")"

  printf '%s\n' '---'
  printf '# PostInstallHUB generated playbook\n'
  printf '# Generated : %s\n' "$generated_date"
  printf '# Distro    : %s\n' "$distro"
  printf '# Flags     : %s\n' "$flags_str"
  printf '#\n'
  printf '# Run with  : ansible-playbook -i localhost, %s\n' "$outbase"
  printf '# Tags      : update, essential, flatpak, snap, nvidia, cuda, dns, docker,\n'
  printf '#             kernel, lts, gaming, debloat, dotfiles, summary, ufw, repos,\n'
  printf '#             aur, python, security, wordlists, packman\n'
  printf '\n'
  printf '%s\n' "- name: PostInstallHUB — ${distro} post-install"
  printf '  hosts: localhost\n'
  printf '  connection: local\n'
  printf '  become: yes\n'
  printf '  gather_facts: yes\n'
  printf '\n'
  printf '  vars:\n'
  printf '    postinstall_dotfiles: "%s"\n' "$POSTINSTALL_DOTFILES"
  printf '    postinstall_distro: "%s"\n' "$distro"
  printf '\n'
  printf '  tasks:\n'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log_step "PostInstallHUB Ansible Export"
log_info "Distro  : ${DISTRO}"
log_info "Output  : ${OUTPUT}"
log_info "Flags   : $(_flags_summary)"
log_info "Dotfiles: ${POSTINSTALL_DOTFILES}"

{
  _write_header "$DISTRO" "$(_flags_summary)"

  case "$DISTRO" in
    ubuntu)   _tasks_ubuntu   ;;
    arch)     _tasks_arch     ;;
    fedora)   _tasks_fedora   ;;
    opensuse) _tasks_opensuse ;;
    debian)   _tasks_debian   ;;
    nixos)    _tasks_nixos    ;;
    kali)     _tasks_kali     ;;
    *)
      log_warning "Distro '${DISTRO}' not specifically supported — generating minimal apt-based playbook." >&2
      _tasks_apt_update
      ;;
  esac

  if [[ "$POSTINSTALL_DOTFILES" != "none" ]]; then
    _tasks_dotfiles "$POSTINSTALL_DOTFILES"
  fi

  _tasks_summary
} > "$OUTPUT"

log_success "Playbook written to: ${OUTPUT}"
printf '\n'
printf '%bRun with:%b\n' "${BOLD}" "${NC}"
printf '  %bansible-playbook -i localhost, %s%b\n' "${CYAN}" "$OUTPUT" "${NC}"
printf '  %b# Tagged run: ansible-playbook -i localhost, %s --tags update,essential%b\n' "${DIM}" "$OUTPUT" "${NC}"

# ---------------------------------------------------------------------------
# YAML validation — python3 only, best-effort
# ---------------------------------------------------------------------------
if command -v python3 &>/dev/null; then
  if python3 -c "import yaml; yaml.safe_load(open('${OUTPUT}'))" 2>/dev/null; then
    log_success "YAML validation passed"
  else
    log_warning "YAML validation failed — check ${OUTPUT} for syntax errors:"
    python3 -c "import yaml; yaml.safe_load(open('${OUTPUT}'))" 2>&1 | sed 's/^/  /'
  fi
else
  log_info "python3 not found — skipping YAML validation"
fi
