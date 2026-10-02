# macOS First-Time Setup

This is the rebuild path for a fresh personal Mac. Homebrew is the only manual
package prerequisite; bootstrap will not install Homebrew for you.

## 1. Install Homebrew

Install from:

```text
https://brew.sh
```

Then open a new terminal so `/opt/homebrew/bin` is available.

## 2. Run Bootstrap

Remote bootstrap:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/refs/heads/main/scripts/bootstrap.sh)"
```

Or clone first:

```bash
git clone https://github.com/jfrancolopez/dotfiles.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh
```

Bootstrap installs prerequisites, shell UX, declared Homebrew packages, and
stows the active layers.

## 3. Rename The Machine

If this is the personal Mac, set the hostname to `lamac` so the profile layer is
`profile-lamac-macos`:

```bash
sudo scutil --set ComputerName lamac
sudo scutil --set HostName lamac
sudo scutil --set LocalHostName lamac
```

Verify:

```bash
hostname -s
dotfiles status
```

## 4. Login Round

If this Mac profile declares Tailscale, enable the Homebrew daemon and log in:

```bash
sudo "$(brew --prefix)/bin/tailscaled" install-system-daemon
tailscale up
```

`dotfiles update` also installs `/etc/resolver/ladomum.com` from the managed
macOS resolver source. It requires sudo once and makes `*.ladomum.com` resolve
through AdGuard on `domum-core` over Tailscale.

Sync shell history:

```bash
atuin login -u <username>
atuin sync
```

Atuin owns `Ctrl+R` after opening a new shell. Daily commands and recovery notes
are in [`atuin.md`](atuin.md).

Set up GitHub SSH:

```bash
dotfiles git setup-ssh
```

Set up encrypted recovery-pack email after key restore:

```bash
dotfiles recovery setup
dotfiles recovery send
```

Store `~/.config/age/recovery.txt`, the printed `age1...` recipient, and the
Gmail app password securely outside the Mac.

## 5. Services

Start the managed UI services. Homebrew 6+ refuses to manage services from
untrusted taps, so trust the tap first:

```bash
brew trust felixkratz/formulae
brew services start felixkratz/formulae/borders
```

Wallpaper rotation is opt-in on macOS:

```bash
cp ~/.local/share/dotfiles/com.dotfiles.wallpaper.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.dotfiles.wallpaper.plist
```

## 6. Menu Bar

The native macOS menu bar is used and remains user-managed. Configure its
visibility in System Settings > Menu Bar; the dotfiles do not hide or replace
it.

## 7. Permissions

Expected first-run prompts:

- AeroSpace: Accessibility.
- Rectangle: Accessibility.

Grant these in System Settings when prompted.

## 8. Validate

```bash
dotfiles status
dotfiles doctor
scripts/macos-defaults.sh --dry-run
```

If Stow reports legacy conflicts from an older flat layout, back them up through
the conflict wizard before applying the new layered layout.
