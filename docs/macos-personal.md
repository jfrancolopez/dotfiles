# macOS Personal Setup

## Layer Map

For the personal Mac named `lamac`, the active layers are:

```text
stow/global
stow/os-macos
stow/profile-lamac-macos
```

Package declarations are parallel:

```text
packages/global/{brew,cask}.txt
packages/os-macos/{brew,cask}.txt
packages/profile-lamac-macos/{brew,cask}.txt
```

Formulae go in `brew.txt`; GUI apps and fonts go in `cask.txt`.

## Terminal

Ghostty is the managed terminal on macOS and the standard target across the
personal environments. Edit the shared config in:

```text
stow/global/ghostty/.config/ghostty/config
```

The lamac-specific hook is:

```text
stow/profile-lamac-macos/ghostty/.config/ghostty/profile-overrides
```

Kitty may remain installed but is unmanaged. Alacritty's global config remains
tracked for non-macOS use, but Alacritty is not declared for managed Mac
installation. Removed legacy WezTerm config should not be restored.

## Window Management

AeroSpace owns tiling and workspaces. Edit it here:

```text
stow/os-macos/aerospace/.config/aerospace/aerospace.toml
```

Rectangle stays for ad-hoc snapping of floating windows. Keep its shortcuts
disjoint from AeroSpace shortcuts.

Borders is managed here:

```text
stow/os-macos/borders/.config/borders/bordersrc
```

## Raycast

Raycast is installed as a cask and remains the launcher/productivity surface.
Raycast data, extensions, and account state are not committed to this repo.

## Wallpapers

Shared wallpapers live in Git under:

```text
stow/global/wallpapers/.local/share/wallpapers/shared/
```

Private local wallpapers live outside Git on every OS:

```text
~/Pictures/local-wallpapers/
```

Use:

```bash
dotfiles wallpaper status
dotfiles wallpaper rotate
dotfiles wallpaper open-local
```

macOS uses `desktoppr` when available, with an AppleScript fallback. The
LaunchAgent scheduler is opt-in; see `docs/wallpapers.md`.

## Tailscale (manual-only)

Verdict (2026-07-08, evidence in backlog task 33): the App Store client
**cannot** run as a traditional dial-up VPN. Its network extension
(IPNExtension) rewrites the VPN configuration — re-arming "VPN On Demand" —
on every extension launch, within seconds of any manual disable, and the
armed on-demand rules make macOS relaunch the extension at every boot and
network change. That loop has no user-accessible break point: the GUI
toggle, System Settings, profile deletion, `tailscale down`, and the
documented `VPNOnDemandIsUserConfigured` policy (both defaults domains AND
the internal group-container marker) were all tested on 1.98.8 and all get
overwritten. The standalone .pkg build ships the same extension code and
behaves identically.

Manual-only mode therefore means the open-source daemon:
`brew install tailscale` + `sudo tailscaled install-system-daemon`, then
`tailscale up` / `tailscale down`. No Network Extension, no VPN profile in
System Settings, no on-demand framework; `down` persists across reboots.
Migration steps, validation, and rollback:
`backlog/macos-lamac/task-33-tailscale-oss-migration.md`.

Until that migration runs, expect the App Store client to resurrect its
VPN profile and on-demand rules; `Tailscale down` stops tailnet traffic
(engine down) but macOS keeps the extension process alive.

### ladomum.com DNS

`dotfiles update` installs a macOS resolver at `/etc/resolver/ladomum.com`
from the stowed source in `stow/os-macos/resolver/`. This sends
`*.ladomum.com` lookups directly to AdGuard on `domum-core` over Tailscale
(`100.121.26.52`) so browsers do not depend on Tailscale repeatedly repairing
split DNS in macOS.

This works both at home and away as long as Tailscale is connected. If
Tailscale is down, `*.ladomum.com` names will not resolve on macOS until
Tailscale is brought back up or the resolver is removed.

## AI Tooling

Ollama.app owns the CLI and models on macOS. `~/.ollama` is local state and is
never committed. LM Studio is optional and unmanaged unless a future task
declares it explicitly.

## Not Automated

These stay manual or app-owned:

- System defaults beyond the reviewed table below.
- Keychain and iCloud state.
- Mac App Store app ownership.
- VS Code settings, which Settings Sync owns.
- Browser profiles.
- Raycast and Keyboard Maestro data.
- Local/private wallpaper folders.

## Notable Defaults

These defaults are documented here and can be applied selectively with:

```bash
scripts/macos-defaults.sh --dry-run
scripts/macos-defaults.sh
```

The script is never called by bootstrap, update, or apply.

| Setting | Apply command | Revert |
| --- | --- | --- |
| Dock autohide | `defaults write com.apple.dock autohide -bool true; killall Dock` | `defaults delete com.apple.dock autohide; killall Dock` |
| Dock bottom orientation | `defaults write com.apple.dock orientation bottom; killall Dock` | `defaults delete com.apple.dock orientation; killall Dock` |
| Dock tile size 47 | `defaults write com.apple.dock tilesize -int 47; killall Dock` | `defaults delete com.apple.dock tilesize; killall Dock` |
| Finder show hidden files | `defaults write com.apple.finder AppleShowAllFiles -bool true; killall Finder` | `defaults delete com.apple.finder AppleShowAllFiles; killall Finder` |
| Show all file extensions | `defaults write -g AppleShowAllExtensions -bool true; killall Finder` | `defaults delete -g AppleShowAllExtensions; killall Finder` |
| Tap to click | `defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true` | `defaults delete com.apple.AppleMultitouchTrackpad Clicking` |
| Key repeat fast | Documented only: `defaults write -g KeyRepeat -int 2` | `defaults delete -g KeyRepeat` |
| Initial key repeat | Documented only: `defaults write -g InitialKeyRepeat -int 15` | `defaults delete -g InitialKeyRepeat` |
| Disable press-and-hold accents | Documented only: `defaults write -g ApplePressAndHoldEnabled -bool false` | `defaults delete -g ApplePressAndHoldEnabled` |
