---
title: "Deployment Specification"
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

# Deployment specification

> **Note:** PostInstallHUB is a collection of shell scripts, not a web service.
> "Deployment" here means publishing a new version to GitHub so users can run
> the install one-liner. There are no servers, containers to push, load
> balancers, or cloud infrastructure.

## Artifact

- Type: Shell scripts (Bash `.sh` + Windows `.cmd` / `.ps1`)
- Distribution: GitHub raw URLs (no package registry)
- Version format: Semantic versioning — `vMAJOR.MINOR.PATCH` (e.g. `v0.1.0`)
- Signature/provenance: N/A — solo project, no artifact signing
- SBOM: N/A

## Install URLs

Pin to a specific tag (recommended for stability):

```bash
curl -fsSL https://raw.githubusercontent.com/SobralCybersec/PostInstallHUB/v1.0.0/install.sh | bash
```

Always-latest (tracks `main`):

```bash
curl -fsSL https://raw.githubusercontent.com/SobralCybersec/PostInstallHUB/main/install.sh | bash
```

The README always shows the current stable tag URL. Update it when the stable
tag changes.

## Pre-release checklist

- [ ] `shellcheck` passes on all `.sh` files with zero errors.
- [ ] `bash -n` syntax check passes on all `.sh` files.
- [ ] Docker tests pass for all supported Linux distros (Ubuntu, Arch, Fedora, Omarchy).
- [ ] Windows VM test passes for `setup.cmd` / `setup.ps1`.
- [ ] `CHANGELOG.md` updated with this version's changes.
- [ ] README curl URL updated if the stable tag changed.
- [ ] No secrets, tokens, or personal paths hardcoded in scripts.

## Release procedure

1. Ensure all pre-release checks above are green.
2. Update `CHANGELOG.md` — add a new `## [vX.Y.Z] - YYYY-MM-DD` section.
3. Commit: `git commit -m "chore: release vX.Y.Z"`.
4. Tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`.
5. Push tag: `git push origin vX.Y.Z`.
6. Create GitHub Release on `vX.Y.Z` with the CHANGELOG section as the body.
7. Verify the curl one-liner works against the new tag in a fresh Docker container.
8. Update README stable URL if needed, push to `main`.

## Verification after release

| Check | Expected result | How |
|---|---|---|
| Curl one-liner (Ubuntu) | Exits 0; packages installed | `docker run --rm ubuntu:22.04 bash -c "apt-get update -q && apt-get install -y -q curl && curl -fsSL <URL> \| bash"` |
| Curl one-liner (Arch) | Exits 0; packages installed | Same pattern with `archlinux:latest` |
| GitHub Release page | Tag visible; changelog body present | Browser check |
| README URL | Points to correct tag | `grep raw.githubusercontent README.md` |

## Post-deployment

- N/A — no service to monitor. Scripts run on the user's machine and exit.
- If a regression is reported: push a fix commit, tag a patch release, update README.

---

### Sections not applicable to this project

| Web-service concept | Status |
|---|---|
| Container registry | N/A |
| Kubernetes / Helm | N/A |
| Blue/green or canary deployment | N/A |
| Health endpoint / readiness probe | N/A |
| Error rate / latency monitoring | N/A |
| Rollout observation window | N/A |
| Cloud infrastructure | N/A |
