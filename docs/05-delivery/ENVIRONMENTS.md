---
title: "Environment Strategy"
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

# Environment strategy

> **Note:** PostInstallHUB has no staging or production environments in the
> web-service sense. "Environments" are the isolated test containers/VMs used
> during development. The user's actual machine is the only "production" target
> — and it is not managed by Matheus.

## Test environments

| Environment | Base image / OS | Script under test | How to spin up |
|---|---|---|---|
| `ubuntu-test` | `ubuntu:22.04` (Docker) | `scripts/linux/ubuntu.sh` | `docker run --rm -it ubuntu:22.04 bash` |
| `arch-test` | `archlinux:latest` (Docker) | `scripts/linux/arch.sh` | `docker run --rm -it archlinux:latest bash` |
| `fedora-test` | `fedora:latest` (Docker) | `scripts/linux/fedora.sh` | `docker run --rm -it fedora:latest bash` |
| `omarchy-test` | Arch-based VM or container | `scripts/linux/omarchy.sh` | Arch VM with Hyprland; or custom Docker image |
| `windows-test` | Windows 10 or 11 VM | `scripts/windows/setup.cmd`, `setup.ps1` | VirtualBox / VMware / Hyper-V |

## What "production" means here

The user's own machine — freshly installed Ubuntu, Arch, Fedora, Windows, or
an Omarchy setup. Matheus does not manage these machines. The scripts must be
safe to run on a clean OS install and should be idempotent (safe to re-run).

## Test environment setup

### Linux containers (Docker)

```bash
# Ubuntu
docker run --rm -it ubuntu:22.04 bash
# Inside container:
apt-get update && apt-get install -y curl
curl -fsSL https://raw.githubusercontent.com/SobralCybersec/PostInstallHUB/main/install.sh | bash

# Arch
docker run --rm -it archlinux:latest bash
# Inside container:
pacman -Sy --noconfirm curl
curl -fsSL .../install.sh | bash

# Fedora
docker run --rm -it fedora:latest bash
# Inside container:
dnf install -y curl
curl -fsSL .../install.sh | bash
```

### Windows VM

- Install Windows 10 or 11 in a VM (VirtualBox / VMware / Hyper-V).
- Take a snapshot of the clean state before each test run; revert to snapshot after.
- Run `setup.cmd` from CMD and `setup.ps1` from an elevated PowerShell.

## Parity notes

- Docker containers are minimal; some tools (e.g. `sudo`) may not be pre-installed.
  Scripts must handle this — either run as root inside the container or install `sudo` first.
- Omarchy tests require a more complete Arch base since Hyprland and related
  packages are not available in the default `archlinux:latest` image. Use a
  custom Dockerfile or a VM snapshot.
- Windows VM should not have pre-installed developer tools to simulate a clean
  machine. Test both with and without `winget` pre-configured.

---

## Sections not applicable to this project

| Web-service concept | Status |
|---|---|
| Staging environment | N/A |
| Production cluster | N/A |
| Environment promotion pipeline | N/A |
| Feature flags per environment | N/A |
| Anonymized data copies | N/A |
| External dependency sandboxes | N/A |
