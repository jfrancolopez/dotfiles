# Backlog: macOS profile for lamac

Goal: rebuild the personal MacBook Pro ("lamac", M2 Pro, macOS 26) as a cleanly
managed machine in this repo's layered structure (`global` -> `os-macos` ->
`profile-lamac-macos`), replacing the broken legacy flat-layout setup.

Read `CONTEXT.md` before executing any task. It contains the audit findings
every task assumes.

## Execution protocol (one task per agent/session)

1. Read `CLAUDE.md` (repo root), then `backlog/macos-lamac/CONTEXT.md`, then
   your task file. Do ONLY what the task file says. Anything else you notice
   goes in a note at the bottom of the task file, not in the diff.
2. Tasks marked `Scope: repo-only` must not modify anything outside the repo.
   Tasks marked `Scope: mac-local` mutate `$HOME` on lamac and must be run on
   that machine with a human present.
3. Respect `Depends on:`. Do not start a task whose dependencies are not
   `done`.
4. Run every command in the task's Validation section before finishing.
5. Flip `Status: todo` to `Status: done` in the task file, append a short
   `## Result` section (what changed, anything surprising), and commit the
   task's changes together with the task-file update as ONE commit:
   `<area>: <imperative summary>` (matches repo history style, e.g.
   `packages: add brew/cask support for macos`).
6. Never push. Pushing happens once, in task 29, after everything is green.
   (History note: the initial backlog and task 02 were pushed early on
   2026-07-07 — done is done, but hold the line from here.)
7. Concurrency rules (added after an amend collision on 2026-07-07):
   - ONE agent works the repo at a time. Before starting: `git status` must
     be clean apart from your task, and run `git pull --ff-only`.
   - NEVER `git commit --amend`, rebase, or rewrite anything you did not
     create in your current session — another agent's commit may be HEAD.
   - Commit your task's file flip (Status + Result) together WITH the code,
     in the same commit, so the backlog state always matches history.
   - Do not commit `.claude/settings.local.json` or other session cruft with
     task work.
8. Blast-radius rules (added after the 2026-07-08 re-audit):
   - Extending a shared dispatch function (pkg_manager, detect_os,
     install_missing_packages, resolve_*) can ARM code paths for other OSes
     that were previously dead. Check every caller before returning a new
     value from a shared function.
   - Tests must pin DOTFILES_OS / DOTFILES_BOOTSTRAP_OS explicitly and mock
     every package manager they could reach; an unpinned fixture on a Mac
     once installed real brew packages.
   - main is consumed live (machines pull it; curl bootstrap runs it), so a
     task that lands "detection" without its "implementation" counterpart
     changes error messages users see. Prefer landing such pairs
     back-to-back (02+18, 06+19).
7. Never commit secrets, keys, tokens, `*.local` files, or anything from
   `~/Library` except where a task explicitly says otherwise.

## Task index and order

Phase 0 — foundations
- [x] 01 rename-hostname-lamac (mac-local, S)
- [x] 02 macos-os-detection (repo, M)
- [x] 03 bash-version-guard (repo, S)
- [x] 04 macos-inventory-script (repo, M)
- [x] 05 fix-status-conflict-visibility (repo, M)

Phase 1 — packages plumbing
- [x] 06 packages-lib-brew-support (repo, M) — needs 02
- [x] 07 packages-macos-lists (repo, S) — needs 06

Phase 2 — stow layers
- [x] 08 repo-hygiene-stow-ignores (repo, S)
- [x] 09 promote-neovim-atuin-to-global (repo, S)
- [x] 10 recover-aerospace-borders (repo, S)
- [x] 11 macos-layer-skeleton (repo, S) — absorbs former task 12; there is no
      task 12

Phase 3 — retired SketchyBar implementation (historical; removed 2026-10-02)
- [x] 13 sketchybar-core (repo, M) — needs 10
- [x] 14 sketchybar-system-plugins (repo, M) — needs 13
- [x] 15 sketchybar-network-media-plugins (repo, M) — needs 13

Phase 4 — wallpapers
- [x] 16 wallpaper-unified-engine (repo, M)
- [x] 17 wallpaper-macos-backend (repo, S) — needs 16

Phase 5 — bootstrap + CLI
- [x] 18 bootstrap-macos (repo, M) — needs 02, 03
- [x] 19 cli-brew-install-logic (repo, M) — needs 06, 07
- [x] 20 doctor-status-macos (repo, M) — needs 02, 06

Phase 6 — docs + guardrails
- [x] 21 macos-defaults-script (repo, S)
- [x] 22 docs-macos-setup (repo, S)
- [x] 23 secrets-guardrails (repo, S)

Phase 7 — apply on lamac (mac-local, human present, in this exact order)
- [x] 24 mac-cleanup-dangling-links (mac-local, S) — needs 01
- [x] 25 mac-cleanup-legacy-configs (mac-local, M) — needs 24
- [x] 26 mac-cleanup-services-apps (mac-local, S) — needs 24
- [ ] 27 mac-first-apply (mac-local, M) — blocked on terminal sudo install of desktoppr + human app logins
- [ ] 28 e2e-validation (mac-local + linux check, M) — blocked on 27, reboot, and Omarchy check
- [ ] 29 final-review-and-push (repo, S) — needs 28

Phase 8 — post-migration improvements
- [x] 30 sketchybar-primary-bar (historical; retired 2026-10-02)
- [x] 31 sketchybar-notch-polish (historical; retired 2026-10-02)
- [x] 32 tailscale-manual-mode (mac-local + docs, M) — investigation stands
      but its fix FAILED validation (2026-07-08): the extension rewrites the
      config on every launch; superseded by task 33
- [ ] 33 tailscale-oss-migration (mac-local, M, sudo + human) — replace the
      App Store client with OSS tailscaled for true manual mode; evidence
      and steps in the task file

Size: S = small mechanical change, any model. M = needs judgment; use a
stronger model. Phase 7 tasks mutate a real machine: strongest model, human
watching.

Repo-only phases 1-6 can be executed in any order that respects the listed
dependencies; phases 0 and 7 bracket them.
