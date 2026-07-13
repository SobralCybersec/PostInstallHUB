---
title: "Security Specification"
status: "draft"
owner: "Matheus"
reviewers:
  - "Matheus"
version: "0.1.0"
last_reviewed: "2026-07-10"
review_cycle: "quarterly"
applies_to: "0.1.0"
source_of_truth: true
related: []
supersedes: null
---

# Security specification

## Security objectives

1. Ensure the script cannot be silently tampered with between the user copying the URL and running it (supply chain integrity via HTTPS + GitHub's public, versioned hosting).
2. Ensure the script never stores, logs, or transmits credentials or personal data.
3. Ensure the script cannot be weaponized to modify the system in ways the user did not explicitly review (no silent destructive ops; backup warning before touching existing configs; sudo only where required).

## Assets

| Asset | Classification | Owner | Impact if compromised |
|---|---|---|---|
| User OS configuration (dotfiles, shell config, package list) | Private / personal | Matheus (user's machine) | Misconfigured system; data loss if backup skipped |
| GitHub repository (install.sh and distro scripts) | Public | Matheus | Malicious script served to all users who curl the raw URL |
| Companion dotfile repo | Public | Matheus | Malicious dotfiles applied to user's system |

## Trust boundaries

```
[GitHub raw HTTPS] ──curl -fsSL──► [User terminal: bash install.sh]
                                           │
                          ┌────────────────┼────────────────┐
                          ▼                ▼                ▼
                    [apt/pacman/dnf] [dotfile repo]  [/tmp lock file]
                    (sudo, local)   (curl HTTPS)     (local only)
```

- **Untrusted input:** the URL the user types. Anything beyond the official GitHub raw URL is out of scope.
- **Semi-trusted:** GitHub itself (public repo, Matheus controls it with 2FA).
- **Trusted:** the local system once the script is running under the user's account.

## Threat-model summary

See [THREAT-MODEL.md](THREAT-MODEL.md) for full STRIDE enumeration. Summary:

| Threat ID | Threat | Asset | Likelihood | Impact | Mitigation |
|---|---|---|---:|---:|---|
| THR-001 | Attacker hosts malicious install.sh at look-alike URL | GitHub repo / user OS | Low | High | HTTPS only; user copies verbatim GitHub raw URL; public repo is auditable |
| THR-002 | GitHub repo compromised; script modified | User OS | Very Low | High | 2FA on GitHub account; pin to release tag in production docs |
| THR-003 | Script logs sudo password or env credentials | User credentials | Very Low | High | Script never handles credentials; sudo invoked directly by OS; no logging of env vars |
| THR-004 | Stale lock file prevents recovery after crash | Script usability | Low | Low | Documented manual removal; consider auto-expiry (see THREAT-MODEL.md TMR-001) |
| THR-005 | Script modifies existing config without user awareness | User dotfiles | Low | Medium | Backup warning printed before any config modification |
| THR-006 | Script runs all commands as root unnecessarily | User OS | Low | Medium | `sudo` used only for specific commands (apt install, chsh, pacman); script itself is not run as root |

## Authentication

- Identity provider: N/A — no user authentication in the script.
- MFA requirement: 2FA required on Matheus's GitHub account (protects the repo from unauthorized pushes).
- Session lifetime: N/A.
- Rotation/revocation: N/A.
- Password policy: N/A — no passwords handled by PostInstallHUB.
- Recovery flow: N/A.

## Authorization

- Model: N/A — no multi-user access control.
- Default: the script runs as the current user. `sudo` is used only for commands that require root (package installs, `chsh`). The script itself must not be launched with `sudo`.
- Enforcement points: each `sudo` call is explicit and visible in the script output.
- Resource ownership check: N/A.
- Administrative elevation: `sudo` for specific package manager and shell-change commands only; user sees every sudo invocation printed before it runs.

## Data protection

| Data | At rest | In transit | Logs | Backups |
|---|---|---|---|---|
| User OS config / dotfiles | On local disk (user's responsibility) | Not transmitted by PostInstallHUB | Never logged by the script | N/A (PostInstallHUB does not back up user data; it warns before overwriting) |
| Lock file (`/tmp/postinstallhub.lock`) | Contains only PID; deleted on EXIT | Not transmitted | Not logged | N/A |
| No other data collected | — | — | — | — |

## Input and output controls

- Schema validation: N/A — no user input accepted at runtime (non-interactive by design; distro is detected automatically).
- File upload: N/A.
- SSRF: N/A — script is not a server.
- Injection: shell variable quoting enforced throughout (`"$var"` not `$var`); no `eval` of user-controlled input; `set -u` catches unbound variables.
- Browser controls: N/A — not a web application.

## Security checklist (per PR)

- [ ] No `eval` of any user-controlled or externally fetched string.
- [ ] All variables in critical paths are double-quoted.
- [ ] No hardcoded credentials, tokens, or API keys anywhere in the repo.
- [ ] No logging of sensitive environment variables (`$HOME` paths are fine; `$PASSWORD`, `$TOKEN` etc. are not — and the script should never touch those).
- [ ] `curl` calls use `-fsSL` with HTTPS URLs only — no HTTP fallback.
- [ ] `shellcheck` passes with no errors.
- [ ] Any new `sudo` invocation is visible in script output before it runs.

## Security verification

- Baseline: OWASP ASVS is N/A (not a web application). Equivalent baseline: `shellcheck` clean + manual code review per release.
- SAST: `shellcheck` — must pass (zero errors) on every PR.
- Dependency scanning: N/A — no package.json, no pip, no external runtime deps beyond bash and standard coreutils.
- Secret scanning: GitHub's default secret scanning on the public repo; manual review on every PR.
- DAST: N/A — not a running service.
- Penetration testing: N/A — local script, no network surface.
- Threat-model review: re-run when a new distro is added, a new `curl` target is introduced, or sudo scope changes.

## Incident handling

- Contact: matheussobrallinkedin@gmail.com (see SECURITY-REPORTING.md).
- Severity model: High = script can be used to exfiltrate data or modify system without user consent. Medium = script misbehaves in a way the user cannot detect. Low = cosmetic or recoverable error.
- Key-revocation procedure: if GitHub account is compromised, revoke all personal access tokens immediately via GitHub Settings → Developer Settings → Tokens; rotate SSH keys.
- Evidence retention: N/A (personal project; no audit log retention requirement).
- Notification obligations: N/A (no users beyond Matheus in v0.1.0; if script is published, add a SECURITY.md disclosure notice).
