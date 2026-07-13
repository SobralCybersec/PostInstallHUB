---
title: "PostInstallHUB — Project Brief"
version: "0.1.0"
status: "in-progress"
updated: 2026-07-13
platform:
  - Linux (Ubuntu/Debian, Arch, Fedora, Omarchy)
  - Windows (CMD/batch + PowerShell)
agents:
  - Claude Code
  - OpenAI Codex CLI
---

# PostInstallHUB — Project Brief

## 1. Project declaration

```yaml
project:
  name: "PostInstallHUB"
  type: "shell script collection"
  problem: "Fresh OS installs leave users with bad defaults, missing tools, and unconfigured shells. Setup is tedious and error-prone to repeat across machines or distros."
  solution: "Single curl one-liner that auto-detects OS and distro, then runs the right post-install script: packages, dotfiles, system tweaks."
  install_command: "curl -fsSL https://raw.githubusercontent.com/matheusgomescosta/PostInstallHUB/main/install.sh | bash"
  platform:
    - "Ubuntu / Debian (apt)"
    - "Arch Linux (pacman)"
    - "Fedora (dnf)"
    - "Omarchy — DHH's Arch + Hyprland setup"
    - "Windows (winget + CMD/batch, PowerShell variant)"
  owner: "Matheus"
  phase: "MVP / greenfield"
  repository: "https://github.com/matheusgomescosta/PostInstallHUB"
  version: "0.1.0"
  database: false
  api: false
  web_app: false
```

## 2. Core experience

User runs one command on a fresh machine. The script:

1. Detects the OS and distro automatically.
2. Prints a brief header and a backup warning before touching config files.
3. Installs packages: `git`, `curl`, `neovim`, `zsh`.
4. Pulls dotfile presets from the companion GitHub repo via curl.
5. Applies system tweaks (sets zsh as default shell, applies distro-specific settings).
6. Exits cleanly with a summary of what changed.

Output is readable — colored labels, clear step names, no wall of noise. If the script has already run, it detects the lock file and exits safely. Nothing is destructive without a warning first.

This is not a dev environment bootstrapper. No Node, Docker, Python venvs, or language runtimes. Just the baseline that should exist on every machine.

## 3. Platform boundary

| Platform | Package manager | Script |
|---|---|---|
| Ubuntu / Debian | apt | `scripts/linux/ubuntu.sh` |
| Arch Linux | pacman | `scripts/linux/arch.sh` |
| Fedora | dnf | `scripts/linux/fedora.sh` |
| Omarchy | pacman (Arch base) | `scripts/linux/omarchy.sh` |
| Windows | winget | `scripts/windows/setup.cmd` + `setup.ps1` |

Detection happens in `install.sh` by reading `/etc/os-release` on Linux and `%OS%`/`ver` on Windows. Unknown distros print a clear error and exit without making changes.

## 4. Script architecture

```
install.sh
  └─ detect OS / distro
       ├─ source lib/colors.sh      # terminal color helpers
       ├─ source lib/lock.sh        # prevent concurrent runs
       ├─ source lib/backup.sh      # warn + back up before config changes
       └─ delegate to distro script
            ├─ install packages (apt/pacman/dnf/winget)
            ├─ curl dotfile preset from companion repo
            ├─ apply system tweaks
            └─ set zsh as default shell
```

Every distro script sources the same `lib/` helpers, so colors, locking, and backup behavior are consistent. Distro scripts are not standalone — they expect the lib/ context set up by `install.sh`.

## 5. Directory structure

```
PostInstallHUB/
├── install.sh                  # entry point — OS detection + delegation
├── lib/
│   ├── colors.sh               # ANSI color variables and print helpers
│   ├── lock.sh                 # lock file: /tmp/postinstallhub.lock
│   └── backup.sh               # backs up a file before overwriting it
├── scripts/
│   ├── linux/
│   │   ├── ubuntu.sh
│   │   ├── arch.sh
│   │   ├── fedora.sh
│   │   └── omarchy.sh
│   └── windows/
│       ├── setup.cmd
│       └── setup.ps1
├── docs/
│   └── 00-project/             # spec documents (this directory)
├── AGENTS.md                   # universal agent operating rules
├── CLAUDE.md                   # Claude-specific notes, points to AGENTS.md
└── README.md                   # install command + supported platforms
```

## 6. Implementation phases

### Phase 0 — Repo setup + common lib
- GitHub repo scaffold: README, LICENSE, AGENTS.md, CLAUDE.md
- `lib/colors.sh`: ANSI helpers (`info`, `ok`, `warn`, `err` print functions)
- `lib/lock.sh`: write `/tmp/postinstallhub.lock` on start, remove on exit, trap on crash
- `lib/backup.sh`: copy target file to `<file>.bak.<timestamp>` before overwriting
- `install.sh` skeleton: reads `/etc/os-release`, maps distro to script path, delegates

**Done when:** `install.sh` on Ubuntu prints detected distro and exits cleanly (even before the distro script exists).

### Phase 1 — Linux scripts
- `ubuntu.sh`: apt update, install packages, curl dotfiles, tweaks, chsh zsh
- `arch.sh`: pacman sync, same package list, same dotfile curl, same tweaks
- `fedora.sh`: dnf update, same
- `omarchy.sh`: Arch base + Hyprland-specific tweaks (config paths differ from plain Arch)

**Done when:** Each script runs idempotently in a clean Docker container of the target distro.

### Phase 2 — Windows scripts
- `setup.cmd`: winget install for git/curl/neovim; calls setup.ps1 for shell config
- `setup.ps1`: dotfile curl, PowerShell profile setup, system tweaks

**Done when:** Runs cleanly in a Windows 10/11 VM from CMD.

### Phase 3 — Tests, docs, release
- Shell tests per distro using Docker (smoke test: run script, check binaries exist)
- README finalized with curl one-liner, supported platforms table, what it does/doesn't do
- GitHub Release v1.0.0 with checksums

## 7. Acceptance criteria

- `install.sh` detects Ubuntu, Arch, Fedora, Omarchy, and Windows correctly.
- `git`, `curl`, `neovim`, `zsh` are installed after running the relevant distro script.
- Dotfiles are pulled from the companion repo and placed correctly.
- System tweaks are applied (zsh set as default shell).
- Running the script a second time does not duplicate work or error out (idempotent).
- Lock file prevents two concurrent runs.
- Backup warning is shown and a `.bak` file is created before any config file is overwritten.
- Unknown distros exit with a clear error message and no side effects.

## 8. Agent operating rules

```
Read AGENTS.md before changing any script.
AGENTS.md is the universal source of rules; CLAUDE.md points Claude to it.
This is a shell script project — no Node, no Python deps, no package.json.
Do not add a dev environment setup. Scope is: packages + dotfiles + tweaks.
Supported platforms: Ubuntu/Debian, Arch, Fedora, Omarchy, Windows (CMD/PS).
All scripts must be idempotent. Test in a clean environment, not on your live machine.
Keep lib/ helpers general. Distro scripts handle distro-specific logic only.
No destructive operation without a backup.sh call and a printed warning first.
Lock file must be set before any install work begins and removed on exit/crash.
```
