---
title: "Repository Structure"
status: "active"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["CONTRIBUTING.md", "OWNERSHIP.md"]
supersedes: null
---

# Repository structure

```text
PostInstallHUB/
├── install.sh              ← Entry point: OS detection + routing
├── scripts/
│   ├── linux/
│   │   ├── common.sh       ← Shared bash functions (log_*, check_sudo, etc.)
│   │   ├── ubuntu.sh       ← Ubuntu/Debian setup
│   │   ├── arch.sh         ← Arch Linux setup
│   │   ├── fedora.sh       ← Fedora setup
│   │   └── omarchy.sh      ← Omarchy (Arch+Hyprland) setup
│   └── windows/
│       ├── setup.cmd       ← Windows CMD setup
│       └── setup.ps1       ← PowerShell setup
├── lib/
│   ├── colors.sh           ← ANSI color constants (RED, GREEN, YELLOW, BLUE, NC)
│   ├── lock.sh             ← Lock file management (acquire, release, check)
│   └── backup.sh           ← Backup warning helpers
├── tests/
│   ├── test_ubuntu.sh      ← Ubuntu script tests
│   ├── test_arch.sh        ← Arch script tests
│   ├── test_fedora.sh      ← Fedora script tests
│   └── test_omarchy.sh     ← Omarchy script tests
├── docs/                   ← Spec documentation (this directory)
├── AGENTS.md               ← Universal AI coding agent instructions
├── CLAUDE.md               ← Claude-specific notes
├── README.md               ← User-facing docs and quick start
├── CHANGELOG.md            ← Version history (keep-a-changelog format)
└── LICENSE.md              ← MIT License
```

---

## Directory ownership and purpose

| Path | Purpose | Owner | Notes |
|---|---|---|---|
| `install.sh` | OS detection and routing — the only file a user ever runs directly | Matheus | Must stay minimal; delegates to `scripts/` |
| `scripts/linux/common.sh` | Shared functions sourced by all Linux scripts | Matheus | Logging, sudo check, idempotency helpers |
| `scripts/linux/<distro>.sh` | Distro-specific install logic | Matheus | Each script is self-contained beyond common.sh |
| `scripts/windows/setup.cmd` | Windows CMD setup | Matheus | Uses `winget` for package installs |
| `scripts/windows/setup.ps1` | PowerShell setup (richer than CMD) | Matheus | Preferred over CMD for future Windows work |
| `lib/colors.sh` | ANSI escape code constants | Matheus | Sourced by all scripts that produce colored output |
| `lib/lock.sh` | Lock file acquire/release to prevent concurrent runs | Matheus | Lock path: `/tmp/postinstallhub.lock` |
| `lib/backup.sh` | Print backup warning before any destructive step | Matheus | Must be called before modifying existing configs |
| `tests/` | Syntax + behavior tests for each distro script | Matheus | Run with `bash tests/test_<distro>.sh` |
| `docs/` | All spec documentation | Matheus | Never modify source files; docs describe intended behavior |

---

## Dependency rules

```text
install.sh  →  scripts/linux/<distro>.sh  →  scripts/linux/common.sh
install.sh  →  scripts/windows/setup.*
scripts/**  →  lib/colors.sh
scripts/**  →  lib/lock.sh
scripts/**  →  lib/backup.sh
lib/*       -/→  scripts/**   (lib never imports from scripts)
```

`lib/` is a leaf layer — nothing in `lib/` sources anything from `scripts/`.

---

## Placement rules

| Content type | Where it lives |
|---|---|
| OS detection and routing | `install.sh` |
| Distro-specific install steps | `scripts/linux/<distro>.sh` |
| Shared bash functions | `scripts/linux/common.sh` |
| ANSI colors | `lib/colors.sh` |
| Lock file logic | `lib/lock.sh` |
| Backup warning logic | `lib/backup.sh` |
| Tests | `tests/test_<distro>.sh` |
| User docs | `README.md` |
| Spec docs | `docs/` |
| AI agent instructions | `AGENTS.md`, `CLAUDE.md` |

---

## Generated and vendored files

There are no generated or vendored files in this repository. Everything is hand-authored bash/CMD.
