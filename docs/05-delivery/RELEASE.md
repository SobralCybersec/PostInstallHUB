---
title: "Release and Compatibility Policy"
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

# Release and compatibility policy

## Versioning

- Scheme: **Semantic versioning** — `vMAJOR.MINOR.PATCH`
- `v0.x.x` — MVP / incomplete coverage (some distros or Windows may be missing)
- `v1.0.0` — all distros supported (Ubuntu, Arch, Fedora, Omarchy, Windows 10/11), Docker tests green, README complete
- Release cadence: as-needed (no fixed schedule — solo project)
- Supported versions: latest release only; users can pin to any tag via the raw URL
- End-of-life: no formal EOL process; old tags remain accessible on GitHub indefinitely

## Version milestones

| Version | Meaning |
|---|---|
| `v0.1.0` | First public release — Ubuntu, Arch, Fedora Linux; skeleton Windows |
| `v0.2.0` | Omarchy complete; Windows fully tested |
| `v1.0.0` | All distros solid, idempotent, Docker tests green, README complete |

## Compatibility

| Surface | Compatibility promise | Breaking-change process |
|---|---|---|
| Curl one-liner URL (pinned tag) | Stable forever — tagged URLs never change | N/A; tags are immutable |
| Curl one-liner URL (`main` branch) | Tracks latest; may break between releases | README documents this risk |
| Script flags / arguments | No stable API yet (`v0.x.x`); may change | Documented in CHANGELOG |
| Installed packages / versions | Best-effort; follows distro defaults | CHANGELOG note on changes |
| Config file locations | Best-effort; follows XDG / distro convention | CHANGELOG note on changes |

## Release checklist

- [ ] `shellcheck` passes on all `.sh` files (zero errors, zero warnings).
- [ ] `bash -n` syntax check passes on all `.sh` files.
- [ ] Docker tests pass for all Linux distros:
  - [ ] `bash tests/test_ubuntu.sh`
  - [ ] `bash tests/test_arch.sh`
  - [ ] `bash tests/test_fedora.sh`
  - [ ] `bash tests/test_omarchy.sh` (if implemented)
- [ ] Windows VM test passes for `setup.cmd` and `setup.ps1` (if implemented).
- [ ] Scripts are idempotent — re-run on already-configured machine exits 0.
- [ ] `CHANGELOG.md` updated with `## [vX.Y.Z] - YYYY-MM-DD` section.
- [ ] README curl URL updated to point to new tag (if stable tag changed).
- [ ] No secrets, tokens, or personal paths hardcoded.
- [ ] Version and changelog updated.

## Release steps

```bash
# 1. Run all checks (see pre-release checklist above)
shellcheck scripts/**/*.sh install.sh lib/*.sh

# 2. Update CHANGELOG.md — add new version section

# 3. Commit
git add -A
git commit -m "chore: release vX.Y.Z"

# 4. Tag
git tag -a vX.Y.Z -m "Release vX.Y.Z"

# 5. Push tag
git push origin main
git push origin vX.Y.Z

# 6. Create GitHub Release
#    - Go to github.com/SobralCybersec/PostInstallHUB/releases/new
#    - Select tag vX.Y.Z
#    - Title: "PostInstallHUB vX.Y.Z"
#    - Body: paste the CHANGELOG section for this version

# 7. Verify curl one-liner on fresh Docker container
docker run --rm ubuntu:22.04 bash -c \
  "apt-get update -q && apt-get install -y -q curl && \
   curl -fsSL https://raw.githubusercontent.com/SobralCybersec/PostInstallHUB/vX.Y.Z/install.sh | bash"

# 8. Update README stable URL if needed
```

## Feature flags

N/A — PostInstallHUB has no feature flags. Individual distro scripts can be
enabled or skipped by the user choosing which script to run directly.

## Distribution

Scripts are distributed exclusively via GitHub raw URLs. No package registry
(npm, PyPI, Homebrew, AUR, apt PPA, etc.) is used. Users either:

1. Use the curl one-liner (recommended).
2. Clone the repo and run the script manually.
