# Context for all macos-lamac tasks (audit of 2026-07-07)

Facts every task in this backlog assumes. Verify a fact only if your task
touches it; do not re-audit the world.

## Decisions (made by Franco, do not re-litigate)

- The Mac will be renamed `lamac`; its profile is `profile-lamac-macos`.
- Terminal is **Ghostty** — on macOS now, and the standard target across all
  of Franco's personal environments going forward. WezTerm is removed
  entirely: no cask, no config, no recovery of old wezterm.lua. Alacritty is
  demoted: its global config stays (harmless), but it is NOT declared for
  installation on managed Macs; kitty stays installed-but-unmanaged.
- Keep: AeroSpace, Rectangle, Raycast, kitty (kitty stays unmanaged).
- Remove: minidlna, stale ollama LaunchAgent, WezTerm, all legacy flat-layout
  configs. This is a clean rebuild, not a patch.
- Shell/terminal UX comes from the existing repo layers only (zsh, oh-my-zsh,
  p10k, aliases.sh, env.sh, tmux, fastfetch, eza, neovim, zoxide, atuin).
- Packages: `packages/<layer>/brew.txt` (formulae) + `cask.txt` (casks), plain
  text, one per line, tap packages fully qualified (e.g.
  `felixkratz/formulae/borders`). No Brewfile, no mas.txt.
- SketchyBar was retired on 2026-10-02. Managed Macs use the native menu bar;
  do not install or start a replacement bar, hide the native bar, or reserve
  custom top gaps. Tasks 13-15 and 30-31 are historical records only.
- Wallpapers: a rotation engine ALREADY EXISTS for Omarchy (commit 8fa4466,
  2026-07-07): conf at `~/.config/dotfiles/wallpapers.conf`,
  `dotfiles wallpaper rotate|status|open-local`, systemd user timer, repo+local
  merge, docs in `docs/wallpapers.md`. Architecture decision: ONE
  platform-independent engine (`dotfiles-wallpaper` in the global layer) owning
  config/sources/selection/state, with per-OS backends that only set the image
  — omarchy = the existing audited current-background+swaybg behavior (NOT
  hyprpaper), macos = desktoppr with osascript fallback (task 16/17). Shared
  pool lives at `~/.local/share/wallpapers/shared/` (global layer); local pool
  is `~/Pictures/local-wallpapers` on ALL OSes (Franco's explicit path — the
  engine's day-old `~/Pictures/Wallpapers/local` default changes; docs carry
  the migration note). Local pool is merged only when the folder exists and is
  never committed. Schedulers stay per-OS: systemd timer (omarchy, existing),
  opt-in LaunchAgent template (macos).
- macOS system defaults: documented + selectively applied via a confirm-gated
  script only. Never run automatically.

## State of the Mac (before cleanup)

- macOS 26.5.1, arm64, M2 Pro. Homebrew 6.x at `/opt/homebrew`. GNU stow,
  git, zsh, oh-my-zsh + p10k + autosuggestions + syntax-highlighting all
  installed. `/bin/bash` is 3.2 and NO newer bash is installed.
- The Mac was stowed long ago from an old FLAT repo layout (`stow/<pkg>/...`,
  no layers) that commit `cedc5d2` ("dotfiles: New structure") deleted. Every
  symlink from that era is DANGLING: `~/.zshrc`, `~/.bashrc`, `~/.p10k.zsh`,
  `~/.tmux.conf`, `~/.gitconfig`, `~/.gitignore_global`, `~/.ssh/config`,
  `~/.config/aerospace/aerospace.toml`, `~/.config/borders`,
  `~/.config/wezterm`, `~/.config/git`, `~/.config/btop/btop.conf`,
  `~/.config/shell/{aliases,env}.sh`, `~/.config/nvim/*`.
- Old Mac configs are recoverable from git: `git show cedc5d2~1:<old path>`.
  Only two are wanted: `stow/aerospace/.config/aerospace/aerospace.toml` and
  `stow/borders/.config/borders/bordersrc`.
- `~/.config/sketchybar/` is a REAL dir, never committed; its sketchybarrc
  references plugins that do not exist (spotify.sh, weather.sh, volume.sh).
  Treat as design reference only.
- `~/.zprofile` is a real file: brew shellenv + JetBrains Toolbox PATH +
  OrbStack init + pipx PATH. The last three belong in
  `~/.config/shell/env.local` (gitignored) after cleanup.
- `~/.config/dotfiles/profile` contains `personal-macos` — a dead mechanism
  from the old layout; current scripts only honor `DOTFILES_PROFILE` env.
- LaunchAgents include `homebrew.mxcl.minidlna.plist` (formula installed,
  unwanted) and `homebrew.mxcl.ollama.plist` (STALE — the ollama formula is
  not installed; Ollama.app owns `/usr/local/bin/ollama`).
- Tailscale is the Mac App (`/Applications/Tailscale.app`), not a daemon.

## Repo gotchas relevant here

- `detect_os()` in `scripts/lib/common.sh` reads `/etc/os-release` and returns
  `unknown` on macOS. `bootstrap.sh` has its own `detect_bootstrap_os()`.
- Scripts use bash-4 features (`mapfile` in stow.sh backup path, `${var,,}` in
  the Linux branches). They run under `#!/usr/bin/env bash`.
- Known bug: in `scripts/lib/stow.sh`, `stow_one_package` with `--no` warns on
  conflicts but returns 0, so `dotfiles status` prints "stow dry-run clean"
  even when conflicts exist. Task 05 fixes this.
- `stow/global/xdg-terminal-exec/` is Linux-only but sits in the global layer.
- Neovim (LazyVim) and atuin configs live in `stow/os-omarchy/` but are wanted
  on macOS too -> promoted to global (task 09). After promotion, Omarchy
  machines will have symlinks pointing at the old layer path; their next
  `dotfiles apply` shows conflicts — choose "backup" in the wizard (task 28).
- Ghostty global config ends with `config-file = ?~/.config/ghostty/profile-overrides`;
  that include is the per-machine hook (fornax/nox use it for font-size).
  `macos-option-as-alt` goes in lamac's profile-overrides, NOT global config.
- Omarchy continues to use Waybar independently; its configuration is not part
  of the macOS menu-bar setup.
