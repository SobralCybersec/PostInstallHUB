---
title: "Obsidian Plugin Architecture"
status: "not-applicable"
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

# Obsidian plugin architecture

> **N/A for PostInstallHUB.**
>
> This document does not apply to PostInstallHUB. PostInstallHUB is a
> standalone shell script project for post-install OS setup. It has no
> connection to Obsidian, no plugin manifest, no ItemViews, no Vault APIs, and
> no JavaScript runtime. This file was generated from a project template
> intended for Obsidian plugin development and is retained here only so the
> template audit trail is complete.

---

## Why this document does not apply

Obsidian plugin architecture documents describe concerns specific to plugins
that run inside the Obsidian desktop application: the plugin lifecycle, Vault
and FileManager APIs, ItemView registration, CSS scoping within the Obsidian
DOM, `requestUrl` for network access, and teardown of listeners on unload.

PostInstallHUB has none of these. It is invoked from a terminal on a fresh
operating system where Obsidian may not even be installed. There is no plugin
manifest, no `main.js` entry point for Obsidian, no React component tree, and
no Vault to interact with.

If PostInstallHUB ever gains an Obsidian-related component in the future (e.g.,
a companion plugin that triggers the install script), this document should be
updated and its status changed to `draft`.
