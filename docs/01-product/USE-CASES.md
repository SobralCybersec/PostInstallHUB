---
title: "Use Cases"
status: "draft"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: []
supersedes: null
---

# Use cases

## UC-001 — Fresh Linux Install Setup

- Primary actor: Matheus (or any user on a supported distro)
- Goal: Set up a freshly installed Linux OS with packages, dotfiles, and shell defaults in one command
- Trigger: User has a freshly installed supported OS and wants to configure it quickly
- Preconditions:
  - OS is Ubuntu/Debian, Arch, Fedora, or Omarchy
  - User has internet access
  - User has `sudo` rights
  - No lock file exists at `/tmp/postinstallhub.lock`
- Success outcome:
  - `git`, `curl`, `neovim`, `zsh` installed
  - Dotfiles configured in `$HOME`
  - System tweaks applied to `~/.zshrc`
  - `zsh` is the default shell
  - Lock file cleaned up; script exits `0`
- Failure outcomes:
  - Package manager fails → script exits non-zero with the failing command printed
  - Dotfile curl fails → warning printed; script continues remaining steps

### Main flow

1. User runs `curl -fsSL https://raw.githubusercontent.com/matheusgomescosta/PostInstallHUB/main/install.sh | bash`
2. `install.sh` creates lock file at `/tmp/postinstallhub.lock`
3. Script reads `/etc/os-release` and identifies the distro
4. Backup warning printed for any existing config files; user presses Enter to continue
5. Distro-specific sub-script sourced (e.g. `scripts/linux/ubuntu.sh`)
6. Packages installed via distro package manager (`apt install -y git curl neovim zsh`)
7. Dotfile preset fetched and applied via companion `curl` command
8. System tweaks (aliases, shell defaults) written to `~/.zshrc`
9. `chsh -s $(which zsh)` sets zsh as default shell
10. Lock file removed; success message printed; script exits `0`

### Alternative flows

- A1 — Dotfile curl fetch fails (no network or repo unavailable):
  1. Script prints `WARNING: dotfile setup failed, skipping.`
  2. Remaining steps (tweaks, chsh) continue normally; script still exits `0`

- A2 — Package install fails (broken mirror, permissions error):
  1. Script captures exit code from package manager
  2. Prints failing command and stderr output
  3. Removes lock file
  4. Exits with package manager's non-zero code

- A3 — User aborts at backup warning (Ctrl+C):
  1. Signal handler removes lock file
  2. Process exits; no config files were modified

### Business rules

- BR-001 — Lock file must be created before any side-effectful operation and removed on all exit paths (success, failure, signal)
- BR-002 — No operation may proceed without first printing and receiving acknowledgment of the backup warning when an existing config file would be modified
- BR-003 — Package install commands must use idempotent flags (`--needed` for pacman, `--no-upgrade` equivalent where available) so re-runs are safe

### Data touched

- Reads: `/etc/os-release`, `~/.zshrc`, `~/.bashrc` (existence check)
- Writes: `/tmp/postinstallhub.lock`, `~/.zshrc`, `/etc/passwd` (via `chsh`)
- Emits: stdout progress messages, stderr on failure

### Acceptance criteria

- [ ] On Ubuntu 22.04, running the curl one-liner produces a configured system with all four packages present and `zsh` as default shell
- [ ] On Arch Linux, `command -v git neovim zsh curl` all return `0` after the script completes
- [ ] When dotfile curl fails, the script still exits `0` and remaining steps complete

---

## UC-002 — Idempotent Re-run

- Primary actor: Matheus (checking state or recovering from partial failure)
- Goal: Re-run the script safely without breaking anything already configured
- Trigger: User runs the install script again on an already-set-up system
- Preconditions:
  - All packages from UC-001 already installed
  - Dotfiles already in place
  - `zsh` already default shell
- Success outcome:
  - Script exits `0`
  - No packages re-downloaded or reinstalled
  - No config files overwritten
  - Lock file cleaned up
- Failure outcomes:
  - None expected; any error is a bug

### Main flow

1. Lock file created
2. OS detected (same path as UC-001)
3. Backup warning skipped for files that won't be modified (already idempotent content)
4. Package manager reports "already installed" for each package; no download occurs
5. Dotfile script detects existing symlinks/files; skips without overwriting
6. Tweaks block checks for existing entries in `~/.zshrc`; skips if already present
7. `chsh` skipped if current shell is already `zsh`
8. Lock file removed; exits `0`

### Alternative flows

- None; idempotency means all branches converge to no-op + exit `0`

### Business rules

- BR-003 — Idempotent package flags required (see UC-001)
- BR-004 — Config write operations must check for existing content before appending

### Data touched

- Reads: `/etc/os-release`, `~/.zshrc`, installed package state
- Writes: `/tmp/postinstallhub.lock` (created then removed); no other writes if already configured
- Emits: stdout progress (skipped steps noted)

### Acceptance criteria

- [ ] Running the script twice in sequence produces identical system state; second run output contains "already installed" for all packages
- [ ] No file modification timestamps change on the second run for config files

---

## UC-003 — Blocked Concurrent Run

- Primary actor: Matheus (accidentally triggers a second run while first is in progress)
- Goal: Prevent two instances of the script from running simultaneously
- Trigger: User runs `install.sh` while another instance is already executing
- Preconditions:
  - `/tmp/postinstallhub.lock` already exists (first run in progress)
- Success outcome:
  - Second invocation prints clear error and exits `1` immediately
  - First run is undisturbed
- Failure outcomes:
  - N/A

### Main flow

1. Second `install.sh` starts
2. Script checks for `/tmp/postinstallhub.lock`
3. Lock file found → prints `ERROR: PostInstallHUB is already running (lock: /tmp/postinstallhub.lock). Abort or wait for it to finish.`
4. Exits `1` without touching any package, config, or dotfile

### Alternative flows

- A1 — Stale lock file from a previously crashed run:
  1. Script detects lock file but no matching PID is alive
  2. Prints warning: `WARNING: stale lock detected (no matching process). Removing and continuing.`
  3. Removes stale lock; proceeds normally

### Business rules

- BR-001 — Lock file governs all concurrent access

### Data touched

- Reads: `/tmp/postinstallhub.lock`, `/proc/<PID>` (stale check)
- Writes: nothing (fast exit)
- Emits: error message to stderr

### Acceptance criteria

- [ ] Starting two instances in parallel results in exactly one completing and one exiting `1` with the lock error message
- [ ] Stale lock (no live PID) is detected and cleared automatically

---

## UC-004 — Unsupported OS

- Primary actor: Any user on an unsupported distro
- Goal: Fail cleanly and informatively when the OS is not supported
- Trigger: User runs `install.sh` on openSUSE, CentOS, Alpine, or any other unsupported OS
- Preconditions:
  - OS is not Ubuntu/Debian, Arch, Fedora, or Omarchy
- Success outcome:
  - Script exits `1` within 2 seconds
  - Error message names the detected OS and lists supported distros
  - No packages installed, no files modified
- Failure outcomes:
  - N/A

### Main flow

1. Lock file created
2. Script reads `/etc/os-release`; `ID` value not in supported list
3. Prints: `ERROR: Unsupported OS: "<detected ID>". Supported: ubuntu, debian, arch, fedora, omarchy.`
4. Lock file removed
5. Exits `1`

### Alternative flows

- A1 — `/etc/os-release` missing (very minimal container):
  1. Script prints `ERROR: Cannot detect OS — /etc/os-release not found.`
  2. Exits `1`

### Business rules

- BR-005 — OS detection must complete before any package or config operation begins

### Data touched

- Reads: `/etc/os-release`
- Writes: `/tmp/postinstallhub.lock` (created then removed)
- Emits: error to stderr

### Acceptance criteria

- [ ] On a Fedora 38 machine running the script prints the unsupported-OS error and exits `1` within 2 seconds — *wait, Fedora is supported*; on openSUSE Leap the same behaviour applies
- [ ] No packages are installed and no config files are touched before the error fires

---

## UC-005 — Windows Setup

- Primary actor: Matheus on a Windows 10/11 machine
- Goal: Install core packages and apply Windows-specific tweaks without a Linux environment
- Trigger: User downloads and runs `setup.cmd` (or `setup.ps1`) from the GitHub releases page
- Preconditions:
  - Windows 10 (build 1809+) or Windows 11
  - `winget` available (pre-installed on Windows 11; installable via App Installer on Windows 10)
  - User has Administrator rights or can approve UAC prompts
- Success outcome:
  - `git`, `curl`, `neovim` installed via `winget`
  - Windows-specific tweaks applied (environment variables, optional aliases via `doskey`)
  - Script exits `0`
- Failure outcomes:
  - `winget` unavailable → prints install instructions and exits `1`
  - Package install fails → prints failing command and exits with non-zero code

### Main flow

1. User runs `setup.cmd` (double-click or `cmd /c setup.cmd`)
2. Script checks `winget --version`; confirms it is available
3. `winget install --id Git.Git -e --source winget` installs git
4. `winget install --id Neovim.Neovim -e --source winget` installs neovim
5. `winget install --id cURL.cURL -e --source winget` installs curl
6. Windows-specific tweaks applied (e.g. `setx` for PATH adjustments)
7. Success message printed; script exits `0`

### Alternative flows

- A1 — `winget` not found:
  1. Prints `ERROR: winget not found. Install App Installer from the Microsoft Store: https://aka.ms/getwinget`
  2. Exits `1`

- A2 — Package already installed:
  1. `winget` reports "No available upgrade found" or "already installed"
  2. Script treats this as success; continues

### Business rules

- BR-006 — Windows script must not require WSL, Git Bash, or any Unix toolchain to run
- BR-007 — All `winget` calls must use `--id` with exact package identifiers to avoid ambiguous matches

### Data touched

- Reads: `winget` registry / installed packages list
- Writes: Windows PATH (via `setx`), program files directories (via `winget`)
- Emits: stdout progress messages

### Acceptance criteria

- [ ] On Windows 11 with `winget` available, running `setup.cmd` installs `git` and `neovim` and exits `0`
- [ ] When `winget` is absent the script exits `1` with a link to the App Installer
