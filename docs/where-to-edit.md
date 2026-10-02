# Where to edit

"I want to change X → edit file Y." Pick the **lowest** layer that makes the
change true everywhere it should apply.

| I want to change… | Edit here |
|---|---|
| A global shell alias / env var | `stow/global/shell/.config/shell/aliases.sh` (or `env.sh`) |
| Terminal UX cheat sheet / audit | `docs/terminal-cheatsheet.md` |
| Zsh config / prompt | `stow/global/zsh/.zshrc`, `stow/global/zsh/.p10k.zsh` |
| Git config | `stow/global/git/.gitconfig` |
| Global Git ignore | `stow/global/git/.gitignore_global` |
| tmux | `stow/global/tmux/.tmux.conf` |
| SSH client config | `stow/global/ssh/.ssh/config` |
| Hyprland keybinds (all Omarchy machines) | `stow/os-omarchy/hyprland/.config/hypr/bindings.lua` |
| Hyprland look/feel (all Omarchy machines) | `stow/os-omarchy/hyprland/.config/hypr/looknfeel.lua` |
| Optional ALT-as-SUPER on one Omarchy machine | `stow/profile-<hostname>-omarchy/hyprland/.config/hypr/input.lua` |
| Waybar | `stow/os-omarchy/waybar/.config/waybar/` |
| Ghostty terminal style/shortcuts | `stow/global/ghostty/.config/ghostty/config` |
| Alacritty terminal style/shortcuts | `stow/global/alacritty/.config/alacritty/alacritty.toml` |
| Terminal font overrides for one machine | `stow/profile-<hostname>-<os>/{ghostty,alacritty}/.config/<terminal>/profile-overrides*` |
| Default terminal launcher | `stow/os-omarchy/xdg-terminal-exec/.config/xdg-terminals.list` |
| Omarchy Display panel persistence wrappers | `stow/os-omarchy/scripts/.local/bin/omarchy-{display-text-size,hyprland-monitor-scaling}` |
| Atuin | `stow/global/atuin/.config/atuin/config.toml` |
| Neovim | `stow/global/neovim/.config/nvim/` |
| OpenCode local LLM providers/models | `stow/global/opencode/.config/opencode/opencode.json` (see `docs/local-llm.md`) |
| macOS first-time setup | `docs/macos-first-time-setup.md` |
| macOS personal reference | `docs/macos-personal.md` |
| macOS zprofile | `stow/os-macos/zsh/.zprofile` |
| macOS Ghostty profile override for `lamac` | `stow/profile-lamac-macos/ghostty/.config/ghostty/profile-overrides` |
| macOS AeroSpace | `stow/os-macos/aerospace/.config/aerospace/aerospace.toml` |
| macOS Borders | `stow/os-macos/borders/.config/borders/bordersrc` |
| macOS wallpaper LaunchAgent template | `stow/os-macos/wallpapers/.local/share/dotfiles/com.dotfiles.wallpaper.plist` |
| Shared wallpapers | `stow/global/wallpapers/.local/share/wallpapers/shared/` |
| Monitor scale/resolution for `nox` | `stow/profile-nox-omarchy/hyprland/.config/hypr/monitors.lua` |
| Monitor scale/resolution for `fornax` | `stow/profile-fornax-omarchy/hyprland/.config/hypr/monitors.lua` |
| Profile policy and autostart apps (one machine) | `stow/profile-<hostname>-omarchy/hyprland/.config/hypr/profile.lua` |
| Fornax away/no-suspend service | `stow/profile-fornax-omarchy/away/.config/systemd/user/dotfiles-away-inhibit.service` |
| Autostart audit ignore list | `stow/profile-<hostname>-omarchy/dotfiles/.config/dotfiles/autostart.ignore` |
| Add an Omarchy pacman package everywhere | `packages/global/pacman.txt` |
| Add an Omarchy AUR package everywhere | `packages/global/aur.txt` |
| Add a package on all Omarchy machines | `packages/os-omarchy/{pacman,aur}.txt` |
| Add a Homebrew formula on all Macs | `packages/os-macos/brew.txt` |
| Add a Homebrew cask on all Macs | `packages/os-macos/cask.txt` |
| Add a package on one machine | `packages/profile-<hostname>-<os>/{pacman,aur}.txt` |
| KVM sharing peers/positions (one machine) | `stow/profile-<hostname>-<os>/lan-mouse/.config/lan-mouse/config.toml` (see `docs/kvm-sharing.md`) |
| Windows dual-boot detection helper | `stow/os-omarchy/scripts/.local/bin/omarchy-windows-boot-detect` (see `docs/omarchy-dualboot-windows.md`) |
| Omarchy Dockurr Windows RDP tuning | `stow/os-omarchy/windows-dockurr/` (see `docs/omarchy-dockurr-windows.md`) |

## Rules of thumb

- **Monitor config is always machine-specific.** On Omarchy 4 it belongs in the
  profile layer's `monitors.lua`, never in `os-omarchy`. Use Omarchy's generic
  scale variables when the shell Display panel should persist future changes.
- **App launcher config stays with Omarchy.** Do not stow launcher config or
  package entries here unless there is a specific new need.
- Omarchy 4 loads `~/.config/hypr/*.lua`; the old `.conf` fragments are legacy
  compatibility files and are not the active source of truth.
- Optional machine-specific Omarchy features belong in the matching profile
  layer, disabled by default when appropriate.
- After editing anything, run `dotfiles apply`.
- To audit login apps and local startup drift, run `dotfiles autostart status`.
