---
title: "Software Supply-Chain Security"
status: "active"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-13"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: ["RISK-REGISTER.md", "DEPENDENCIES.md"]
supersedes: null
---

# Software supply-chain security

PostInstallHUB's supply chain is intentionally minimal. There is no build pipeline, no compiled artifact, no package registry, and no third-party dependencies. The attack surface is small.

---

## What the supply chain looks like

```text
Matheus writes bash scripts
       ↓
Committed to github.com/SobralCybersec/PostInstallHUB (Matheus-controlled)
       ↓
User runs: curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash
       ↓
install.sh downloads additional scripts from the same repo (same trust domain)
       ↓
Scripts call distro package managers (apt, pacman, dnf, winget)
  → packages come from official distro repos only
       ↓
Scripts fetch dotfiles from Matheus's companion dotfile repo (Matheus-controlled)
```

Every link in this chain is either Matheus-controlled or an official distribution channel (GitHub raw, official distro repos).

---

## Controls

| Control | Applied | Notes |
|---|---|---|
| HTTPS-only delivery | Yes | GitHub enforces TLS on all raw.githubusercontent.com URLs |
| 2FA on GitHub account | Yes | Prevents unauthorized pushes |
| Solo repository | Yes | No collaborators = no insider threat surface |
| Official distro repos only | Yes | No third-party PPAs, no AUR helpers, no unofficial taps |
| Matheus-controlled dotfile repo | Yes | No external dotfile sources |
| README advises pinning to release tags | Yes | Users can avoid picking up unreviewed commits from main |
| README advises auditing before running | Yes | curl-pipe-to-bash limitation is documented explicitly |

---

## Packages installed (targets, not supply chain inputs)

The scripts install: `git`, `curl`, `neovim`, `zsh`. All come from official distro repositories:

| Distro | Package source |
|---|---|
| Ubuntu/Debian | `apt` → official Ubuntu/Debian repos |
| Arch | `pacman` → official Arch repos |
| Fedora | `dnf` → official Fedora repos |
| Omarchy | `pacman` → official Arch repos |
| Windows | `winget` → official Microsoft-curated winget repository |

---

## Known limitation: curl-pipe-to-bash

The installation pattern `curl -fsSL <url> | bash` is trusting by design. The user is executing whatever is at that URL. Mitigations:

1. HTTPS ensures the content is from GitHub's servers (no MITM on the wire).
2. The GitHub account is 2FA-protected (no unauthorized push).
3. Users are encouraged in README to clone and inspect before running if they have higher trust requirements.

This is an accepted risk. See RSK-003 in `RISK-REGISTER.md`.

---

## Out of scope

The following enterprise supply-chain practices are out of scope for this personal project and are not planned:

- **SBOM (Software Bill of Materials):** N/A — there are no software dependencies to enumerate.
- **Sigstore / cosign artifact signing:** N/A — no compiled artifacts are distributed.
- **SLSA provenance attestations:** N/A — no build pipeline.
- **Dependabot / Renovate:** N/A — no dependency manifests.
- **Container image scanning:** N/A — no container images produced.
- **CI runner isolation:** N/A — no CI pipeline at this time.
