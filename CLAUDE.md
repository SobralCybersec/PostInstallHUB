# PostInstallHUB — Claude Memory

> Project-scoped memory for Claude Code sessions.
> Read this at the start of every session before touching any file.

---

## What This Project Is

**PostInstallHUB** is a shell-script collection for post-install OS setup.  
Single entry point (`install.sh`) auto-detects the distro and delegates to the right script.

**Supported distros:**  
`kali` · `ubuntu` · `zorin` · `linuxmint` · `pop` · `elementary` · `neon` · `debian` · `arch` · `manjaro` · `endeavouros` · `cachyos` · `garuda` · `fedora` · `windows`

No runtime deps beyond bash + standard OS tools. No pip, no npm, no Obsidian, no framework.  
Windows: PowerShell 7 + winget only.

**Owner / primary user:** Matheus  
**Repo:** `/home/satu/Docs/emai-starter-vault/Wiki/Coding/PostInstallHUB`  
**Phase:** 0 complete — all distro scripts + smoke tests written.

---

## File Map

```
install.sh                      ← entry point: detect_os() + case dispatch
lib/
  colors.sh                     ← ANSI constants (RED GREEN YELLOW BLUE CYAN BOLD DIM NC)
  lock.sh                       ← acquire_lock() — single-instance guard
  backup.sh                     ← backup_warning() — backs up file + optional prompt
scripts/
  linux/
    common.sh                   ← shared: log_*/check_sudo/require_os/apt_install/
                                          append_once/git_clone_once/is_installed/
                                          is_pkg_installed/detect_os
    kali.sh                     ← Kali Linux 2025.x — 12 steps + manual banner
    ubuntu.sh                   ← Ubuntu / Ubuntu-based (Zorin, Mint, Pop, etc.) — 9 steps
    debian.sh                   ← Debian 13 Trixie — 11 steps; DaVinci Resolve, Flatpak
    arch.sh                     ← Arch Linux — 11+2 opt-in steps (docker, LTS kernel)
    endeavour.sh                ← EndeavourOS / CachyOS / Garuda / Manjaro — 12 steps
    fedora.sh                   ← Fedora 44 — 12 steps + manual banner
  windows/
    setup.ps1                   ← Windows 11 — winget apps, tweaks, debloat, dev, gaming
tests/
  test_kali.sh                  ← smoke tests for kali.sh
  test_ubuntu.sh                ← smoke tests for ubuntu.sh
  test_debian.sh                ← smoke tests for debian.sh
  test_arch.sh                  ← smoke tests for arch.sh
  test_endeavour.sh             ← smoke tests for endeavour.sh
  test_fedora.sh                ← smoke tests for fedora.sh
  test_windows.ps1              ← smoke tests for setup.ps1 (PowerShell)
docs/                           ← architecture, decisions, specs
contracts/                      ← JSON Schema contracts
design/                         ← design tokens / assets
```

---

## Coding Rules (non-negotiable)

1. **`#!/usr/bin/env bash` + `set -euo pipefail`** — every executable bash script.
2. **Quote every variable.** `"$var"`, `"${arr[@]}"` — no bare expansions.
3. **`local`** for every variable inside a function.
4. **Idempotent.** Re-running must be safe. Check before install/write/clone.
5. **`apt_install`** (from common.sh) — never raw `apt install`. Skips already-installed.
6. **`append_once MARKER FILE CONTENT`** — never `echo >> file`. Always marker-guarded.
7. **`git_clone_once URL DIR`** — never raw `git clone`. Checks dir existence first.
8. **`backup_warning FILE`** before any config-file modification.  
   (Auto-backup + prompt; skipped when `POSTINSTALL_YES=1`.)
9. **`require_os DISTRO`** at top of every distro script's `run_install()`.  
   Exception: `endeavour.sh` uses `_require_arch_family()` (family check, not exact).
10. **No `sudo` inside lib/.** Only distro scripts call sudo (after `check_sudo()`).
11. **Source guards.** Every lib file: `[[ -n "${_VAR_LOADED:-}" ]] && return 0; _VAR_LOADED=1`.
12. **`log_step` / `log_info` / `log_success` / `log_warning` / `log_error`** — never raw `echo`.
13. **Exit codes:**
    - `0` = success
    - `2` = unsupported OS
    - `3` = lock conflict
    - `4` = no sudo
    - `5` = wrong OS for distro script
    - `1` = test failure (`test_*.sh` only)
14. **No `cd` inside functions** unless absolutely needed and immediately restored.
15. **`POSTINSTALL_YES=1`** = CI/non-interactive mode. All prompts must respect it.

---

## How `install.sh` Works

```
install.sh
  └─ detect_os()                         # reads /etc/os-release → ID
  └─ case "$distro" in
       kali)       source kali.sh
       ubuntu|…)   source ubuntu.sh
       debian)     source debian.sh
       arch|…)     source arch.sh
       endeavouros|cachyos|garuda) source endeavour.sh
       fedora)     source fedora.sh
       windows)    print instructions; exit 0
     esac
  └─ run_install()                       # defined in the sourced script
```

Every distro script **must** define `run_install()`.  
`install.sh` never calls individual step functions directly.

---

## Distro Script Steps

### kali.sh
| # | Function | What |
|---|----------|------|
| 1 | `_step_update` | apt update + upgrade + autoremove |
| 2 | `_step_folders` | ~/Tools ~/Docs ~/Notes ~/Scripts ~/Trash ~/Temps ~/Wordlists |
| 3 | `_step_aliases` | Navigation + pkg + cleanup aliases → `~/.zshrc` (marker-guarded) |
| 4 | `_step_zsh_autosuggest` | zsh-autosuggestions install + configure |
| 5 | `_step_ufw` | UFW defaults + SSH + 80/tcp + enable |
| 6 | `_step_wordlists` | Gunzip rockyou.txt + symlink ~/Wordlists |
| 7 | `_step_editors` | gedit vim neovim nano |
| 8 | `_step_terminal_tools` | terminator tmux htop tree tor flameshot keepassxc wallpapers |
| 9 | `_step_recon_tools` | dirsearch amass ffuf wfuzz feroxbuster recon-ng enum4linux seclists |
| 10 | `_step_python_libs` | requests dnspython termcolor tldextract colorama cffi bs4 |
| 11 | `_step_github_tools` | 8 repos → ~/Tools via git_clone_once |
| 12 | `_step_go_tools` | golang-go + assetfinder gau subfinder httprobe shuffledns |

### ubuntu.sh (also: zorin, linuxmint, pop, elementary, neon)
Steps 1–9: update → flatpak → timeshift → PPAs+apt → flatpak-apps → cleanup  
Opt-in: `UBUNTU_DEBLOAT=1` · `UBUNTU_SNAP=1` · `UBUNTU_NVIDIA=1`

### debian.sh (Debian 13 Trixie)
Steps 1–11: update → ufw → deb-multimedia → nvidia(opt) → flatpak → productivity →  
  davinci-deps → gaming(opt) → debloat(opt) → zswap(opt) → cleanup  
Env: `DEBIAN_NVIDIA=1` · `DEBIAN_NVIDIA_CUDA=1` · `DEBIAN_GAMING=1` · `DEBIAN_DEBLOAT=1` · `DEBIAN_ZSWAP=1`

### arch.sh
Steps 1–11+2: update → yay → pacman-config → micro → services → vm-tools →  
  fonts → zsh+zimfw → AUR-apps → cleanup  
Opt-in: `ARCH_DOCKER=1` · `ARCH_LTS=1`

### endeavour.sh (EndeavourOS · CachyOS · Garuda · Manjaro)
Steps 1–12: update → mirrors → yay → chaotic-aur → ufw → zsh+omz →  
  fish → packages → flatpak → plymouth(opt) → waydroid(opt) → gaming(opt) → cleanup  
Env: `ENDEAVOUR_PLYMOUTH=1` · `ENDEAVOUR_WAYDROID=1` · `ENDEAVOUR_GAMING=1` · `ENDEAVOUR_FISH=1`  
Note: uses `_require_arch_family()` (not `require_os`) — accepts all Arch-family IDs.

### fedora.sh
Steps 1–12: update → rpm-fusion → copr → flatpak → dnf-packages → firmware →  
  services → gaming(opt) → cleanup  
Opt-in: `FEDORA_GAMING=1`

### setup.ps1 (Windows 11 — PowerShell 7)
Sections: Prerequisites → Apps (winget) → Tweaks (winrift, `WINDOWS_TWEAKS=1`) →  
  Debloat (`WINDOWS_DEBLOAT=1`) → Dev env (`WINDOWS_DEV=1`) → Gaming (`WINDOWS_GAMING=1`) → Summary  
Run: `Set-ExecutionPolicy Bypass -Scope Process -Force; .\scripts\windows\setup.ps1`

---

## Adding a New Distro

1. `scripts/linux/<distro>.sh` — source `common.sh`, define `run_install()`
2. Add `case` branch in `install.sh`
3. `tests/test_<distro>.sh` — model after existing test files
4. Update `docs/03-architecture/INTEGRATIONS.md`
5. Update this CLAUDE.md file map + steps table

---

## Environment / Non-Goals

- **No HTTP API, no web server, no domain events** — pure shell.
- **No Obsidian plugin** — not an Obsidian plugin.
- **No Node/Python runtime deps** — only bash + OS package manager (or winget/pwsh on Windows).
- **No GUI installer** — terminal only.
- **No secrets stored** — scripts never write API keys or passwords.
- **No CI pipeline yet** — Phase 0. Tests run manually on a live box or Docker.

---

## Key Gotchas

- `bat` → `batcat` on Debian/Ubuntu — scripts handle both via `is_installed`.
- `fd` → `fd-find` on Debian/Ubuntu — binary may be `fdfind`.
- Go from apt may be outdated — warn; link to https://go.dev/dl/.
- ZSH autosuggestions path: `/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh` (Kali/Debian).
- rockyou.txt at `/usr/share/wordlists/rockyou.txt.gz` on Kali (needs gunzip).
- UFW: use `--force` to avoid interactive prompts in non-interactive mode.
- `require_os kali` exits on non-Kali — by design.
- endeavour.sh Chaotic-AUR key: `3056513887B78AEB` from `keyserver.ubuntu.com`.
- Debian NVIDIA: use CUDA repo (debian12/x86_64 works on Trixie) — distro driver 550 insufficient for DaVinci Resolve 20.x (needs driver 570+ / CUDA 12.8).
- DaVinci Resolve: `SKIP_PACKAGE_CHECK=1 ./DaVinci_Resolve_*.run` to bypass package check.
- Windows setup.ps1: requires PowerShell 7 + winget; must run elevated for restore points.

---

## Session Checklist

**Before any edit:**
- [ ] Read CLAUDE.md (this file)
- [ ] `find . -name "*.sh" -o -name "*.ps1" | sort` — know what exists
- [ ] Read the target file before editing (Edit tool requires prior Read in same session)

**Before committing:**
- [ ] `bash -n <file>` on every changed `.sh`
- [ ] Re-run relevant test file if distro script or lib/ changed
- [ ] Update this CLAUDE.md if you added a file, step, env flag, or rule
