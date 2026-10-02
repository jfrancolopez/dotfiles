# Task 33 — Migrate Tailscale to the OSS daemon (manual-only, WireGuard-like)

Status: todo
Scope: mac-local (lamac, human present — needs sudo and admin-console access)
Depends on: task-32 (investigation; its fix failed validation)
Size: M

## Objective
Tailscale on lamac behaves like WireGuard: installed, idle by default,
`tailscale up` to connect, `tailscale down` to disconnect, nothing
automatic across reboot/login, no VPN profile resurrection.

## Why (verdict from the 2026-07-08 live instrumentation)
The App Store client enforces an always-available model with no
user-accessible off switch. Franco manually disabled VPN On Demand and
disconnected; validation failed. Unified-log forensics
(`/usr/bin/log show`, subsystem com.apple.networkextension) proved:

- IPNExtension (the App Store app's network extension) saved the Tailscale
  NE configuration on EVERY extension launch — 15 saves logged in one
  morning from 11 different pids, including 3 within seconds of boot
  (10:31:09/:25/:27).
- Franco's disable (saved by the System Settings VPN pane at 10:23:54) was
  overwritten by IPNExtension at 10:23:59 — five seconds later.
- At next boot, nesessionmanager was "Resetting VPN On Demand" for
  Tailscale at 10:30:59, 27s into boot, before login completed; the
  extension relaunched and re-saved. Loop closed at the OS level:
  extension re-saves config -> config arms on-demand -> on-demand
  relaunches extension at boot.
- All of this happened with the documented policy
  `VPNOnDemandIsUserConfigured=true` present in the app defaults domain,
  the app container, AND the extension's internal group-container marker —
  build 1.98.8 does not honor it via `defaults` (it may require real MDM
  managed preferences; untestable without MDM). The confirm-gated group
  briefly added to scripts/macos-defaults.sh was removed for this reason.
- The standalone .pkg build ships the same IPNExtension/OnDemandManager
  code (its stale 1.50.1 sysext on lamac is from that variant) — migrating
  to it would change nothing.
- Community reports match and were closed without resolution
  (tailscale/tailscale#12813, #16505).
- Dotfiles re-audited: nothing in bootstrap, brew services, LaunchAgents,
  login items, shell init, AeroSpace, or the dotfiles CLI launches or
  configures Tailscale on macOS.

The OSS daemon has no Network Extension and no on-demand code path at all;
`tailscale down` persists across reboots by construction.

## Migration steps (in order, human present)
```bash
# 1. Quit Tailscale.app (menu bar icon -> Quit).
# 2. Delete /Applications/Tailscale.app in Finder; approve the
#    "remove its system extension/VPN configuration" prompt. Verify:
scutil --nc list | grep -i tailscale       # expect: nothing
# 3. Install and start the OSS daemon:
brew install tailscale
sudo "$(brew --prefix)/bin/tailscaled" install-system-daemon
# 4. Log in (may register a fresh node; delete the old "lamac" node in
#    the admin console at login.tailscale.com if it duplicates):
tailscale up
# 5. Confirm the manual workflow, then park it down:
tailscale status && tailscale down
# 6. Declare the package (this task's repo change):
#    add "tailscale" to packages/profile-lamac-macos/brew.txt
```
Optional cleanup while at it: the stale standalone sysext
`io.tailscale.ipn.macsys.network-extension` 1.50.1 (inert) disappears if
you install+delete the standalone .pkg app once, or leave it.

## Validation
```bash
scutil --nc list | grep -i tailscale   # nothing — no VPN profile exists
sudo launchctl print system/com.tailscale.tailscaled | grep state  # running
tailscale status                       # "Tailscale is stopped."
tailscale up && tailscale status       # connects, peers listed
tailscale down                         # disconnects
# reboot, then:
tailscale status                       # STILL "stopped" — the actual test
pgrep IPNExtension                     # nothing
```
No permission prompts expected after the initial daemon install.

## Rollback
```bash
sudo "$(brew --prefix)/bin/tailscaled" uninstall-system-daemon
brew uninstall tailscale
```
Reinstall Tailscale from the App Store and log in (always-available
behavior returns).

## Risks
- Node re-registration: subnet routes/ACL tags tied to the old node need
  re-approval in the admin console.
- The daemon runs as root at boot (idle when down) — that is the trade for
  kernel utun without an NE; acceptable per the objective.
- Taildrop and the menu bar UI go away; CLI covers up/down/status/exit
  nodes. sketchybar vpn.sh already handles the PATH binary.

## Result
(fill in after execution on lamac)
