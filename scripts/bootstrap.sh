#!/usr/bin/env bash
# bootstrap.sh — curl-friendly first-run setup.
#   curl -fsSL <raw-url>/scripts/bootstrap.sh | bash
#
# Clones (or updates) the repo, checks out the working branch, applies the
# stow layers for this machine, and symlinks `dotfiles` onto PATH.
set -Eeuo pipefail

# bash >= 4 is required for the full run, but a fresh Mac only has 3.2 and
# gets modern bash FROM the prerequisites this script installs. So: re-exec
# now if a modern bash already exists (and we were started from a file);
# otherwise continue under 3.2 — main() re-execs right after prerequisites,
# before any bash-4 code path (mapfile etc.) can run.
# In piped mode (curl | bash) $0 is the shell itself, not this script.
_bootstrap_is_script_file() {
  case "${0##*/}" in
    bash|sh|zsh|dash) return 1 ;;
  esac
  [ -f "$0" ]
}

if [ "${BASH_VERSINFO[0]}" -lt 4 ] && [ -z "${DOTFILES_BASH_REEXEC:-}" ]; then
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [ -x "$_b" ] && _bootstrap_is_script_file; then
      DOTFILES_BASH_REEXEC=1 exec "$_b" "$0" "$@"
    fi
  done
  if [ "$(uname -s)" != "Darwin" ]; then
    printf 'err this tool needs bash >= 4\n' >&2
    exit 1
  fi
fi

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/jfrancolopez/dotfiles.git}"
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
BRANCH="${DOTFILES_BRANCH:-main}"
BIN_DIR="$HOME/.local/bin"
DRY_RUN=0
MINIMAL=0
ZSHRC_GUARD_MARKER="# dotfiles bootstrap zsh-newuser-install guard"

say() { printf '\033[34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn\033[0m %s\n' "$*" >&2; }

print_diagnostics() {
  local reason="$1" cmd pkg pkg_info install_info_path
  {
    printf '\n%s\n' '--- BOOTSTRAP DIAGNOSTICS START ---'
    printf 'reason: %s\n' "$reason"
    printf 'date: %s\n' "$(date 2>/dev/null || true)"
    printf 'bash: %s\n' "$BASH_VERSION"
    printf 'user: %s\n' "${USER:-unknown}"
    printf 'home: %s\n' "$HOME"
    printf 'pwd: %s\n' "$PWD"
    printf 'path: %s\n' "$PATH"
    printf 'repo_url: %s\n' "$REPO_URL"
    printf 'dotfiles_dir: %s\n' "$DOTFILES_DIR"
    printf 'branch: %s\n' "$BRANCH"
    printf 'dry_run: %s\n' "$DRY_RUN"
    printf 'profile: %s\n' "${DOTFILES_PROFILE:-<auto>}"
    printf 'os_detected: %s\n' "$(detect_bootstrap_os 2>/dev/null || printf unknown)"
    printf '\ncommands:\n'
    for cmd in bash git curl sudo pacman stow zsh; do
      if command -v "$cmd" >/dev/null 2>&1; then
        printf '  %s: %s\n' "$cmd" "$(command -v "$cmd")"
      else
        printf '  %s: MISSING\n' "$cmd"
      fi
    done
    if [[ -r /etc/os-release ]]; then
      printf '\n/etc/os-release:\n'
      sed 's/^/  /' /etc/os-release
    fi
    if command -v pacman >/dev/null 2>&1; then
      printf '\npacman packages:\n'
      for pkg in git stow zsh curl bash ca-certificates; do
        pkg_info="$(pacman -Q "$pkg" 2>/dev/null || true)"
        if [[ -n "$pkg_info" ]]; then
          printf '  %s\n' "$pkg_info"
        else
          printf '  %s: NOT INSTALLED\n' "$pkg"
        fi
      done
      printf '\npacman hook/script symlink references:\n'
      grep -Rns 'symlink' /etc/pacman.d/hooks /usr/share/libalpm/hooks /usr/share/libalpm/scripts 2>/dev/null | sed 's/^/  /' || printf '  none found\n'
      printf '\npacman info hook/script files:\n'
      for pkg_info in /usr/share/libalpm/hooks/*info* /usr/share/libalpm/scripts/*info*; do
        [[ -e "$pkg_info" ]] || continue
        printf '  %s\n' "$pkg_info"
        sed -n '1,80p' "$pkg_info" 2>/dev/null | sed 's/^/    /' || true
      done
      if command -v install-info >/dev/null 2>&1; then
        install_info_path="$(command -v install-info)"
        printf '\ninstall-info command:\n'
        printf '  path: %s\n' "$install_info_path"
        if [[ -L "$install_info_path" ]]; then
          printf '  symlink_target: %s\n' "$(readlink "$install_info_path" 2>/dev/null || true)"
        fi
      fi
    fi
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
      printf '\ndotfiles git status:\n'
      git -C "$DOTFILES_DIR" status --short --branch 2>/dev/null | sed 's/^/  /' || true
      printf '\ndotfiles HEAD:\n'
      git -C "$DOTFILES_DIR" log --oneline -1 2>/dev/null | sed 's/^/  /' || true
    else
      printf '\ndotfiles git status:\n  no checkout at %s\n' "$DOTFILES_DIR"
    fi
    printf '%s\n\n' '--- BOOTSTRAP DIAGNOSTICS END ---'
  } >&2
}

die() {
  local reason="$1" fix="$2"
  printf 'ERROR:\n%s\n%s\n' "$reason" "$fix" >&2
  exit 1
}

on_error() {
  local line="$1" command="$2" status="$3"
  trap - ERR
  printf 'ERROR:\nbootstrap failed at line %s with exit status %s: %s\n' "$line" "$status" "$command" >&2
  printf 'Fix the command above, then rerun bootstrap. It is safe to rerun.\n' >&2
  print_diagnostics "fatal error at line $line"
  exit "$status"
}

trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR

repo_dirty() {
  [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null || true)" ]]
}

legacy_flat_layout() {
  [[ -d "$DOTFILES_DIR/stow/shell" && ! -d "$DOTFILES_DIR/stow/global" ]]
}

show_repo_dirty_help() {
  warn "repo has local changes; skipping bootstrap pull to protect your work"
  git -C "$DOTFILES_DIR" status --short --branch || true
  printf '\nReview them first (nothing is reset for you):\n'
  printf '  git -C %s status\n' "$DOTFILES_DIR"
  printf '  git -C %s diff\n' "$DOTFILES_DIR"
  if legacy_flat_layout; then
    printf '\nThis checkout still uses the old flat stow layout (stow/shell, stow/git, ...).\n'
    printf 'Those paths no longer exist upstream, so the modified files cannot merge.\n'
    printf 'Stash them (kept recoverable; do NOT use -u, untracked files stay put),\n'
    printf 'then rerun the same bootstrap command you just ran:\n'
    printf '  git -C %s stash push -m "pre-layer-migration"\n' "$DOTFILES_DIR"
    printf 'Recover any stashed edit later with: git -C %s stash show -p\n\n' "$DOTFILES_DIR"
  else
    printf '\nThen commit or stash intentionally and rerun:\n'
    printf '  git -C %s stash push -m "pre-bootstrap"\n' "$DOTFILES_DIR"
    printf '  %s/scripts/dotfiles update\n\n' "$DOTFILES_DIR"
  fi
}

# Pre-layer checkouts (flat stow/shell, stow/ssh, ...) stowed ssh with
# directory folding, so ~/.ssh is a symlink into the repo and key material
# (id_*, authorized_keys, known_hosts) accumulated untracked inside the
# checkout. Move that material into a real ~/.ssh before any git or stow step:
# keys must never live in the repo, and removing the checkout must never be
# able to lock you out of the machine. Tracked files are copied so the
# checkout stays clean for the ff-only pull; untracked files are moved;
# nothing is deleted.
# shellcheck disable=SC2088  # literal ~/ in user-facing messages
rescue_ssh_from_legacy_checkout() {
  local ssh_link="$HOME/.ssh" link_target staging entry rel backup_root
  [[ -L "$ssh_link" ]] || return 0
  link_target="$(readlink "$ssh_link")"
  [[ "$link_target" == /* ]] || link_target="$HOME/$link_target"
  case "$link_target" in
    "$DOTFILES_DIR"/*) ;;
    *) return 0 ;; # ~/.ssh is managed some other way; not ours to touch
  esac

  if [[ ! -d "$link_target" ]]; then
    warn "~/.ssh is a dangling symlink into the repo: $link_target"
    if [[ $DRY_RUN -eq 1 ]]; then
      warn "dry-run: would move the dead symlink aside and create a real ~/.ssh"
      return 0
    fi
    backup_root="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y-%m-%d-%H%M%S)}"
    mkdir -p "$backup_root"
    mv "$ssh_link" "$backup_root/.ssh.dead-symlink"
    mkdir -m 700 "$ssh_link"
    warn "created an empty ~/.ssh; restore authorized_keys and keys from backups BEFORE closing this session"
    return 0
  fi

  say "Migrating ~/.ssh out of the legacy checkout ($link_target)"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would convert ~/.ssh to a real directory and move key material out of the repo"
    return 0
  fi

  staging="$(mktemp -d "$HOME/.ssh.rescue.XXXXXX")"
  chmod 700 "$staging"
  while IFS= read -r -d '' entry; do
    rel="${entry#"$DOTFILES_DIR"/}"
    if git -C "$DOTFILES_DIR" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
      # Tracked (e.g. the old stowed config): copy, so the checkout stays
      # clean and the ff-only pull can delete the old path itself.
      cp -pR "$entry" "$staging/"
    else
      # Untracked (private keys, authorized_keys, known_hosts): move out of
      # the repo so they can never be committed or lost with the checkout.
      mv "$entry" "$staging/"
    fi
  done < <(find "$link_target" -mindepth 1 -maxdepth 1 -print0)

  rm "$ssh_link"
  mv "$staging" "$ssh_link"
  chmod 700 "$ssh_link"
  say "~/.ssh is now a real directory; key material moved out of the repo"
  say "Verify a NEW ssh login works before closing this session"
}

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--dry-run] [--minimal] [--profile profile-<host>-<os>]

Options:
  --minimal   Headless-server guard: proceed only on Debian/Ubuntu, where the
              layer system already applies terminal-only config and packages.
              Refuses to run on Omarchy/macOS so a desktop machine cannot be
              bootstrapped by a server runbook. See docs/server-minimal.md.

Environment:
  DOTFILES_REPO_URL  Git repo URL (default: jfrancolopez/dotfiles)
  DOTFILES_DIR       Checkout path (default: ~/dotfiles)
  DOTFILES_BRANCH    Git branch (default: main)
  DOTFILES_BOOTSTRAP_DIAGNOSTICS=1  Print copy-paste diagnostics
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --minimal) MINIMAL=1; shift ;;
    --profile)
      [[ -n "${2:-}" ]] || { warn "--profile requires a value"; exit 2; }
      export DOTFILES_PROFILE="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) warn "unknown option: $1"; usage; exit 2 ;;
  esac
done

detect_bootstrap_os() {
  if [[ -n "${DOTFILES_BOOTSTRAP_OS:-}" ]]; then
    case "$DOTFILES_BOOTSTRAP_OS" in
      macos|omarchy|debian|ubuntu|unknown) echo "$DOTFILES_BOOTSTRAP_OS"; return 0 ;;
    esac
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
    return 0
  fi
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    local id="${ID-}" id_like="${ID_LIKE-}"
    case "${id,,}:${id_like,,}" in
      arch:*|*:*arch*) echo "omarchy" ;;
      ubuntu:*) echo "ubuntu" ;;
      debian:*|*:*debian*) echo "debian" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

if [[ "${DOTFILES_BOOTSTRAP_DIAGNOSTICS:-0}" == "1" ]]; then
  print_diagnostics "requested by DOTFILES_BOOTSTRAP_DIAGNOSTICS=1"
fi

# --minimal changes nothing about the flow: on Debian/Ubuntu the plain
# bootstrap is already minimal (global + os-<os> layers, terminal-only apt
# packages). The flag exists so server runbooks are explicit and cannot be
# pasted onto a desktop machine by mistake.
require_minimal_target() {
  [[ "$MINIMAL" -eq 1 ]] || return 0
  local os
  os="$(detect_bootstrap_os)"
  case "$os" in
    debian|ubuntu)
      say "Minimal server bootstrap on $os (same flow as plain bootstrap; guard only)"
      ;;
    *)
      die \
        "--minimal is for headless Debian/Ubuntu servers, but this machine detected as: $os." \
        "Run bootstrap without --minimal on desktop machines. See docs/server-minimal.md."
      ;;
  esac
}

install_bootstrap_prereqs() {
  local prereqs=(git stow zsh curl bash ca-certificates) missing=() pkg

  case "$(detect_bootstrap_os)" in
    omarchy)
      if ! command -v pacman >/dev/null 2>&1; then
        if [[ $DRY_RUN -eq 1 ]]; then
          warn "dry-run: pacman is not available on this host"
          return 0
        fi
        die \
          "pacman is required to install bootstrap prerequisites." \
          "Install pacman/base system packages or run this on a complete Omarchy installation."
      fi
      for pkg in "${prereqs[@]}"; do
        pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
      done
      [[ ${#missing[@]} -eq 0 ]] && return 0
      local pacman_install_args=(-S --needed)
      if ! pacman_sync_databases_exist; then
        pacman_install_args=(-Syu --needed)
        say "Pacman sync databases are missing; syncing before installing prerequisites"
      fi
      say "Installing bootstrap prerequisites with pacman: ${missing[*]}"
      if [[ $DRY_RUN -eq 1 ]]; then
        warn "dry-run: would run sudo pacman ${pacman_install_args[*]} ${missing[*]}"
        return 0
      fi
      local pacman_status=0 still_missing=()
      trap - ERR
      set +e
      if { : </dev/tty; } 2>/dev/null; then
        # shellcheck disable=SC2024
        sudo pacman "${pacman_install_args[@]}" "${missing[@]}" </dev/tty
      else
        sudo pacman "${pacman_install_args[@]}" "${missing[@]}"
      fi
      pacman_status=$?
      set -e
      trap 'on_error "$LINENO" "$BASH_COMMAND" "$?"' ERR

      say "pacman prerequisite install returned: $pacman_status"
      for pkg in "${missing[@]}"; do
        pacman -Qq "$pkg" >/dev/null 2>&1 || still_missing+=("$pkg")
      done
      if [[ ${#still_missing[@]} -gt 0 ]]; then
        print_diagnostics "pacman failed and prerequisites are still missing: ${still_missing[*]}"
        die \
          "pacman failed before installing bootstrap prerequisites: ${still_missing[*]}" \
          "Fix pacman, then rerun bootstrap. Already installed prerequisites will be reused."
      fi
      say "bootstrap prerequisites present after pacman"
      if [[ $pacman_status -ne 0 ]]; then
        warn "pacman reported an error after installing prerequisites; continuing because required packages are present"
      fi
      return 0
      ;;
    macos)
      # Written for /bin/bash 3.2: this branch runs before the modern-bash
      # re-exec on a fresh Mac. No mapfile, no ${var,,}.
      local mac_prereqs="git stow zsh bash" still_missing=()
      if ! command -v brew >/dev/null 2>&1; then
        if [ -x /opt/homebrew/bin/brew ]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
          eval "$(/usr/local/bin/brew shellenv)"
        fi
      fi
      if ! command -v brew >/dev/null 2>&1; then
        if [ "$DRY_RUN" -eq 1 ]; then
          warn "dry-run: Homebrew is not installed on this Mac"
          return 0
        fi
        die \
          "Homebrew is required to install bootstrap prerequisites on macOS." \
          "Install it from https://brew.sh, then rerun bootstrap."
      fi
      for pkg in $mac_prereqs; do
        brew list --formula --versions "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
      done
      [ ${#missing[@]} -eq 0 ] && return 0
      say "Installing bootstrap prerequisites with brew: ${missing[*]}"
      if [ "$DRY_RUN" -eq 1 ]; then
        warn "dry-run: would run brew install ${missing[*]}"
        return 0
      fi
      if ! brew install "${missing[@]}"; then
        die \
          "brew failed installing bootstrap prerequisites: ${missing[*]}" \
          "Fix brew (try: brew doctor), then rerun bootstrap."
      fi
      for pkg in $mac_prereqs; do
        brew list --formula --versions "$pkg" >/dev/null 2>&1 || still_missing+=("$pkg")
      done
      if [ ${#still_missing[@]} -gt 0 ]; then
        die \
          "Prerequisites still missing after brew install: ${still_missing[*]}" \
          "Install them manually, then rerun bootstrap."
      fi
      return 0
      ;;
    debian|ubuntu)
      for pkg in git stow zsh curl bash ca-certificates; do
        dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
      done
      [[ ${#missing[@]} -eq 0 ]] && return 0
      say "Installing bootstrap prerequisites with apt: ${missing[*]}"
      if [[ $DRY_RUN -eq 1 ]]; then
        warn "dry-run: would install apt prerequisites: ${missing[*]}"
        return 0
      fi
      sudo apt-get update
      sudo apt-get install -y "${missing[@]}"
      ;;
    *)
      warn "cannot install prerequisites automatically on this OS: ${prereqs[*]}"
      [[ $DRY_RUN -eq 1 ]] && return 0
      die \
        "Unsupported OS for automatic prerequisite installation: $(detect_bootstrap_os)." \
        "Install these prerequisites manually, then rerun bootstrap: ${prereqs[*]}"
      ;;
  esac
  return 0
}

pacman_sync_databases_exist() {
  local sync_dir="${DOTFILES_PACMAN_SYNC_DIR:-/var/lib/pacman/sync}" db
  for db in "$sync_dir"/*.db; do
    [[ -e "$db" ]] && return 0
  done
  return 1
}

install_zshrc_guard() {
  local zshrc="$HOME/.zshrc"
  if [[ -e "$zshrc" || -L "$zshrc" ]]; then
    return 0
  fi

  say "Installing temporary zsh first-run guard"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would create temporary $zshrc until managed zsh config is stowed"
    return 0
  fi

  printf '%s\n# Replaced by stowed dotfiles zsh config during bootstrap.\n' "$ZSHRC_GUARD_MARKER" >"$zshrc"
  return 0
}

remove_zshrc_guard() {
  local zshrc="$HOME/.zshrc"
  if [[ ! -f "$zshrc" || -L "$zshrc" ]]; then
    return 0
  fi
  if sed -n '1p' "$zshrc" | grep -Fxq "$ZSHRC_GUARD_MARKER"; then
    say "Removing temporary zsh first-run guard"
    if [[ $DRY_RUN -eq 1 ]]; then
      warn "dry-run: would remove temporary $zshrc before stow"
    else
      rm -f "$zshrc"
    fi
  fi
  return 0
}

install_oh_my_zsh() {
  local omz_dir="$HOME/.oh-my-zsh"
  if [[ -r "$omz_dir/oh-my-zsh.sh" ]]; then
    return 0
  fi
  if [[ -e "$omz_dir" ]]; then
    die \
      "Found $omz_dir, but it does not contain oh-my-zsh.sh." \
      "Move or remove the incomplete directory, then rerun bootstrap."
  fi

  say "Installing Oh My Zsh"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would clone Oh My Zsh to $omz_dir"
    return 0
  fi

  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
  return 0
}

install_oh_my_zsh_plugin() {
  local name="$1" url="$2" plugin_dir
  plugin_dir="$HOME/.oh-my-zsh/custom/plugins/$name"
  if [[ -d "$plugin_dir" ]]; then
    return 0
  fi
  if [[ -e "$plugin_dir" ]]; then
    die \
      "Found $plugin_dir, but it is not a directory." \
      "Move or remove that path, then rerun bootstrap."
  fi

  say "Installing Oh My Zsh plugin: $name"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would clone $url to $plugin_dir"
    return 0
  fi

  git clone --depth=1 "$url" "$plugin_dir"
  return 0
}

install_powerlevel10k() {
  local theme_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  if [[ -d "$theme_dir" ]]; then
    return 0
  fi
  if [[ -e "$theme_dir" ]]; then
    die \
      "Found $theme_dir, but it is not a directory." \
      "Move or remove that path, then rerun bootstrap."
  fi

  say "Installing Powerlevel10k"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would clone Powerlevel10k to $theme_dir"
    return 0
  fi

  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
  return 0
}

apply_bootstrap_shell_config() {
  local pkg failed=0

  remove_zshrc_guard
  say "Applying managed shell config"
  if [[ ! -r "$DOTFILES_DIR/scripts/lib/common.sh" || ! -r "$DOTFILES_DIR/scripts/lib/stow.sh" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      warn "dry-run: repo checkout is not present, so shell config stow cannot be simulated"
      return 0
    fi
    die \
      "Cannot find dotfiles stow helpers in $DOTFILES_DIR." \
      "Fix the checkout, then rerun bootstrap."
  fi
  if ! command -v stow >/dev/null 2>&1; then
    if [[ $DRY_RUN -eq 1 ]]; then
      warn "dry-run: stow is not available, so shell config stow cannot be simulated"
      return 0
    fi
    die \
      "stow is required before applying managed shell config." \
      "Fix bootstrap prerequisites, then rerun bootstrap."
  fi

  export DOTFILES_STOW_CONFLICTS="${DOTFILES_STOW_CONFLICTS:-backup}"
  (
    info() { say "$*"; }
    have_tty() { [[ -r /dev/tty && -w /dev/tty ]] && { : </dev/tty >/dev/tty; } 2>/dev/null; }
    # shellcheck source=scripts/lib/stow.sh
    . "$DOTFILES_DIR/scripts/lib/stow.sh"
    for pkg in bash shell zsh scripts; do
      [[ -d "$DOTFILES_DIR/stow/global/$pkg" ]] || continue
      info "stow bootstrap package: global/$pkg"
      if [[ $DRY_RUN -eq 1 ]]; then
        stow_one_package global "$pkg" --no --verbose || failed=1
      else
        stow_one_package global "$pkg" || failed=1
      fi
    done
    exit "$failed"
  )
}

# 1. clone or update
run_bootstrap_repo_flow() {
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  say "Updating existing repo at $DOTFILES_DIR"
  if [[ $DRY_RUN -eq 1 ]]; then
    git -C "$DOTFILES_DIR" fetch --dry-run || true
  else
    git -C "$DOTFILES_DIR" fetch --all --prune
  fi
else
  say "Cloning $REPO_URL -> $DOTFILES_DIR"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would clone $REPO_URL to $DOTFILES_DIR"
  else
    if [[ -e "$DOTFILES_DIR" ]]; then
      die \
        "Found $DOTFILES_DIR, but it is not a Git checkout." \
        "Move it aside or set DOTFILES_DIR to another path, then rerun bootstrap."
    fi
    git clone "$REPO_URL" "$DOTFILES_DIR"
  fi
fi
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  if [[ $DRY_RUN -eq 0 ]]; then
    if repo_dirty; then
      show_repo_dirty_help
      die \
        "Refusing to update a dotfiles checkout with local changes." \
        "Commit, stash, or discard those changes intentionally, then rerun bootstrap."
    else
      if git -C "$DOTFILES_DIR" rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
        git -C "$DOTFILES_DIR" checkout "$BRANCH"
      else
        git -C "$DOTFILES_DIR" checkout -b "$BRANCH" "origin/$BRANCH"
      fi
      git -C "$DOTFILES_DIR" pull --ff-only origin "$BRANCH"
    fi
  else
    say "Dry-run branch: $BRANCH"
  fi
fi

if [[ $DRY_RUN -eq 1 ]]; then
  say "Would configure repo-local Git hooks"
elif [[ -d "$DOTFILES_DIR/.githooks" ]]; then
  git -C "$DOTFILES_DIR" config core.hooksPath .githooks
fi

# 2. symlink the CLI onto PATH before stow so fallback exists if conflicts occur.
if [[ $DRY_RUN -eq 1 ]]; then
  say "Would create $BIN_DIR"
  say "Would link dotfiles -> $BIN_DIR/dotfiles"
else
  mkdir -p "$BIN_DIR"
  ln -sf "$DOTFILES_DIR/scripts/dotfiles" "$BIN_DIR/dotfiles"
  say "Linked dotfiles -> $BIN_DIR/dotfiles"
fi

# 3. Make dotfiles available to the current bootstrap shell immediately.
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) export PATH="$BIN_DIR:$PATH" ;;
esac

install_oh_my_zsh
install_oh_my_zsh_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git
install_oh_my_zsh_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
install_powerlevel10k

# 4. Stow only shell/CLI config before the longer package/update phase so a new
# terminal cannot fall into zsh-newuser-install on fresh installs. Full layer
# stow happens after pacman and AUR packages are handled by `dotfiles update`.
# Conflicts are reported (nonzero) but must not abort bootstrap: the full
# `dotfiles update` below runs the interactive conflict wizard.
if ! apply_bootstrap_shell_config; then
  warn "shell config stow reported conflicts; dotfiles update will handle them"
fi

# 5. Install declared packages, then re-apply layers with conflict wizard.
say "Running dotfiles update"
if [[ $DRY_RUN -eq 1 ]]; then
  if [[ -x "$DOTFILES_DIR/scripts/dotfiles" ]]; then
    if ! "$DOTFILES_DIR/scripts/dotfiles" update --dry-run; then
      warn "dry-run: dotfiles update reported conflicts"
    fi
  else
    warn "dry-run: repo checkout is not present, so dotfiles update cannot be simulated"
    warn "dry-run: would run $DOTFILES_DIR/scripts/dotfiles update --dry-run after clone"
  fi
else
  DOTFILES_ASSUME_YES=1 DOTFILES_STOW_CONFLICTS="${DOTFILES_STOW_CONFLICTS:-backup}" "$DOTFILES_DIR/scripts/dotfiles" update
fi
}

bootstrap_summary() {
  local host host_upper
  host="$(hostname -s 2>/dev/null || uname -n | cut -d. -f1)"
  host_upper="$(printf '%s' "$host" | tr '[:lower:]' '[:upper:]')"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '\nBootstrap dry-run complete for %s. No changes were made.\n' "$host_upper"
    return 0
  fi
  printf '\nBootstrap complete for %s.\n\n' "$host_upper"
  printf 'Ready:\n'
  printf '  dotfiles command installed: %s\n' "$(command -v dotfiles 2>/dev/null || printf '%s' "$BIN_DIR/dotfiles")"
  printf '  managed shell config applied\n'
  printf '  packages checked and stow applied\n'
  printf '\nNeeds manual action:\n'
  if [ "$(detect_bootstrap_os)" = "macos" ]; then
    printf "  Tailscale: if this profile installs it, run sudo \"\$(brew --prefix)/bin/tailscaled\" install-system-daemon && tailscale up\n"
    printf '  macOS Accessibility: System Settings -> Privacy & Security -> Accessibility; enable AeroSpace, borders, Rectangle, Raycast, and LinearMouse\n'
    printf '    (AeroSpace/Rectangle shortcuts and LinearMouse scrolling do nothing until this is granted)\n'
    printf '  Raycast: Cmd-Space is preconfigured; if Spotlight still opens, log out and back in once\n'
  else
    printf '  Tailscale: run sudo tailscale up\n'
  fi
  printf '  GitHub SSH: run dotfiles git setup-ssh\n'
  printf '  Recovery pack: build the encrypted recovery pack when ready\n'
  printf '  Atuin: run atuin login && atuin sync\n'
  printf '\nRecommended:\n'
  printf '  open a new terminal or run exec zsh -l\n'
  printf '  run dotfiles status && dotfiles doctor\n'
}

# Minimal clone so a piped run (curl | bash under bash 3.2) has a tracked
# bootstrap.sh file to re-exec. run_bootstrap_repo_flow handles the rest.
ensure_minimal_checkout() {
  [ -d "$DOTFILES_DIR/.git" ] && return 0
  if [ -e "$DOTFILES_DIR" ]; then
    die \
      "Found $DOTFILES_DIR, but it is not a Git checkout." \
      "Move it aside or set DOTFILES_DIR to another path, then rerun bootstrap."
  fi
  say "Cloning $REPO_URL -> $DOTFILES_DIR (to continue under modern bash)"
  git clone "$REPO_URL" "$DOTFILES_DIR"
}

reexec_with_modern_bash() {
  [ "${BASH_VERSINFO[0]}" -ge 4 ] && return 0
  if [ -n "${DOTFILES_BASH_REEXEC:-}" ]; then
    die "bash >= 4 is still unavailable after re-exec." \
        "Run: brew install bash, then rerun bootstrap."
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "dry-run: continuing under bash 3.2; a real run installs brew bash first"
    return 0
  fi
  local _b target=""
  if _bootstrap_is_script_file; then
    target="$0"
  else
    ensure_minimal_checkout
    target="$DOTFILES_DIR/scripts/bootstrap.sh"
  fi
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [ -x "$_b" ]; then
      say "Re-executing bootstrap under $_b"
      DOTFILES_BASH_REEXEC=1 exec "$_b" "$target" "$@"
    fi
  done
  die "bash >= 4 is required to continue." \
      "Run: brew install bash, then rerun bootstrap."
}

main() {
  require_minimal_target
  install_bootstrap_prereqs
  reexec_with_modern_bash "$@"
  # Server-migration logic only: run the legacy rescue for --minimal runs or
  # when the checkout is still on the old flat layout. Desktop machines on
  # the layer layout never enter this path and keep the pre-existing flow.
  if [[ -d "$DOTFILES_DIR/.git" ]] && { [[ "$MINIMAL" -eq 1 ]] || legacy_flat_layout; }; then
    rescue_ssh_from_legacy_checkout
  fi
  install_zshrc_guard
  run_bootstrap_repo_flow
  bootstrap_summary
}

# Test fixtures source this file to exercise individual functions without
# running the full flow (tests/legacy-ssh-migration.sh).
if [[ "${DOTFILES_BOOTSTRAP_SOURCE_ONLY:-0}" == "1" ]]; then
  # shellcheck disable=SC2317  # exit runs only when executed, not sourced
  return 0 2>/dev/null || exit 0
fi

main "$@"
