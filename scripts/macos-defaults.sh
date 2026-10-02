#!/usr/bin/env bash
set -euo pipefail

# Reviewed macOS defaults only. This script is never called by bootstrap,
# update, or apply; run it manually and approve each group.

dry=0

usage() {
  cat <<'EOF'
Usage: scripts/macos-defaults.sh [--dry-run]

Shows current vs target values for reviewed macOS defaults and asks y/N before
writing each group. No sudo is used.
EOF
}

confirm() {
  local prompt="$1" answer
  printf '%s [y/N] ' "$prompt" >/dev/tty
  IFS= read -r answer </dev/tty || true
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

read_default() {
  local domain="$1" key="$2"
  defaults read "$domain" "$key" 2>/dev/null || printf 'unset\n'
}

read_global_default() {
  local key="$1"
  defaults read -g "$key" 2>/dev/null || printf 'unset\n'
}

show_pair() {
  printf '  %-46s current=%s target=%s\n' "$1" "$2" "$3"
}

apply_or_print() {
  if [ "$dry" -eq 1 ]; then
    printf '  would run: %s\n' "$*"
  else
    "$@"
  fi
}

apply_dock() {
  printf '\nDock\n'
  show_pair 'com.apple.dock autohide' "$(read_default com.apple.dock autohide)" true
  show_pair 'com.apple.dock orientation' "$(read_default com.apple.dock orientation)" bottom
  show_pair 'com.apple.dock tilesize' "$(read_default com.apple.dock tilesize)" 47
  if [ "$dry" -eq 1 ] || confirm 'Apply Dock defaults?'; then
    apply_or_print defaults write com.apple.dock autohide -bool true
    apply_or_print defaults write com.apple.dock orientation bottom
    apply_or_print defaults write com.apple.dock tilesize -int 47
    apply_or_print killall Dock
  fi
}

apply_finder() {
  printf '\nFinder\n'
  show_pair 'com.apple.finder AppleShowAllFiles' "$(read_default com.apple.finder AppleShowAllFiles)" true
  show_pair '-g AppleShowAllExtensions' "$(read_global_default AppleShowAllExtensions)" true
  if [ "$dry" -eq 1 ] || confirm 'Apply Finder defaults?'; then
    apply_or_print defaults write com.apple.finder AppleShowAllFiles -bool true
    apply_or_print defaults write -g AppleShowAllExtensions -bool true
    apply_or_print killall Finder
  fi
}

apply_trackpad() {
  printf '\nTrackpad\n'
  show_pair 'com.apple.AppleMultitouchTrackpad Clicking' "$(read_default com.apple.AppleMultitouchTrackpad Clicking)" true
  if [ "$dry" -eq 1 ] || confirm 'Apply Trackpad defaults?'; then
    apply_or_print defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  fi
}

show_documented_only() {
  printf '\nDocumented only; not applied by this script\n'
  show_pair '-g KeyRepeat' "$(read_global_default KeyRepeat)" 2
  show_pair '-g InitialKeyRepeat' "$(read_global_default InitialKeyRepeat)" 15
  show_pair '-g ApplePressAndHoldEnabled' "$(read_global_default ApplePressAndHoldEnabled)" false
  printf '  To change these, run the documented commands manually after review.\n'
}

main() {
  case "${1:-}" in
    --dry-run) dry=1 ;;
    -h|--help) usage; return 0 ;;
    "") ;;
    *) usage >&2; return 2 ;;
  esac

  if [ "$(uname -s)" != "Darwin" ]; then
    printf 'macOS only\n' >&2
    return 1
  fi

  apply_dock
  apply_finder
  apply_trackpad
  show_documented_only
}

main "$@"
