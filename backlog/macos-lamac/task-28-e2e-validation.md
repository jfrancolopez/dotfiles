# Task 28 — End-to-end validation (lamac + Linux regression)

Status: blocked
Scope: mac-local + a check on one Omarchy machine
Depends on: task-27
Size: M

## Objective
Prove the whole system: lamac survives a reboot fully configured, and the
Omarchy machines are not regressed by the repo changes.

## Files involved
None (validation only; record results in this file's Result section).

## Reason
Multiple agents changed shared code (detect_os, stow.sh, packages.sh,
layer moves). One integrated pass catches interaction bugs.

## Proposed implementation
On lamac, after a REBOOT:
- login shell: p10k prompt, aliases (`l`, `ll`, `gs`), zoxide, atuin history
- `dotfiles status` / `doctor`: clean; `dotfiles update --dry-run`: no-op plan
- Ghostty: theme/font/profile-overrides active (font-size 13, option-as-alt)
- AeroSpace workspaces switch correctly; the native macOS menu bar stays
  visible and no replacement bar process or reserved top gap returns
- borders drawn; Rectangle snapping works alongside AeroSpace
- `dotfiles wallpaper rotate` sets a wallpaper; create
  `~/Pictures/local-wallpapers`, add an image, verify it joins the pool
- `nvim` opens with LazyVim from the repo config
- `scripts/macos-inventory.sh` runs clean, zero dangling symlinks reported
On nox or fornax (whichever is at hand):
- `git pull && dotfiles status` then `dotfiles apply` — expect the known
  conflict prompts from the neovim/atuin/xdg-terminal-exec/wallpaper layer
  moves (tasks 08/09/16): choose backup; then `dotfiles doctor` exit 0;
  Hyprland, waybar, ghostty all unaffected; `dotfiles wallpaper status`
  reports sane counts from the new shared pool path.
Repo-wide:
```bash
shellcheck -x scripts/dotfiles scripts/bootstrap.sh scripts/lib/*.sh
bash tests/bootstrap-first-run.sh && bash tests/package-bootstrap.sh
```

## Safety concerns
The Linux `apply` is the riskiest step — do it while at that machine, not
over SSH from lamac, in case Hyprland session refresh acts up.

## Validation commands
The checklist above IS the validation; paste actual outputs (trimmed) into
the Result section.

## Rollback notes
Per-item rollbacks are in the originating tasks; nothing new is changed here.

## Acceptance criteria
Every checklist item checked with evidence; Linux machines report clean
status/doctor after their apply.

## Result
Blocked pending a lamac reboot and physical/access-at-hand Omarchy validation.
Repo-wide checks from this macOS session passed:
`shellcheck -x scripts/dotfiles scripts/bootstrap.sh scripts/lib/*.sh
scripts/macos-inventory.sh scripts/macos-defaults.sh .githooks/pre-commit ...`,
`bash tests/bootstrap-first-run.sh`, `bash tests/package-bootstrap.sh`,
`bash tests/os-detection.sh`, and `bash .githooks/pre-commit`.

lamac pre-reboot state: fresh login zsh finds `dotfiles` and `brew`, stow
dry-run is clean, and borders is running, but `desktoppr` still needs terminal
sudo install and Tailscale/Atuin login are pending.
