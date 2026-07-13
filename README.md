# PostInstallHUB

One command to set up a fresh Linux or Windows installation.

## Install

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/matheusgomescosta/PostInstallHUB/main/install.sh | bash
```

### Windows

Download and run `setup.cmd` (or `setup.ps1`) from the
[latest release](https://github.com/matheusgomescosta/PostInstallHUB/releases).

## What it does

- Installs **git**, **curl**, **neovim**, and **zsh**
- Configures dotfiles from the companion preset repo
- Applies system tweaks (aliases, shell defaults, convenience settings)
- Sets **zsh** as your default shell

## Supported platforms

| Platform | Package manager |
|---|---|
| Ubuntu / Debian | `apt` |
| Arch Linux | `pacman` |
| Fedora | `dnf` |
| Omarchy | `pacman` |
| Windows 10/11 | `winget` |

## Re-running

The script is idempotent. Running it again on an already-configured system is safe —
installed packages are skipped, applied tweaks are no-ops.

## Safety

- A **backup warning** is displayed before any existing config file is modified.
  Press `Enter` to continue or `Ctrl+C` to abort.
- Only **one instance** can run at a time (lock file: `/tmp/postinstallhub.lock`).
  If a previous run was interrupted, delete the lock file and re-run.
- No destructive operations are performed without explicit acknowledgment.

## What it does NOT do

- Dev environment setup (Node.js, Docker, Python, etc.)
- GUI configuration
- System hardening or security configuration

## Environment variables

| Variable | Effect |
|---|---|
| `POSTINSTALL_YES=1` | Skip backup warning (for automation) |
| `POSTINSTALL_SKIP_DOTFILES=1` | Skip dotfile configuration step |
| `POSTINSTALL_DOTFILES_URL=<url>` | Override companion dotfile repo URL |
| `POSTINSTALL_SKIP_TWEAKS=1` | Skip system tweaks step |

## License

MIT © 2026 Matheus
