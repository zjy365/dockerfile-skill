#!/usr/bin/env bash
set -euo pipefail

# One-liner install:
#   curl -fsSL "https://raw.githubusercontent.com/zjy365/dockerfile-skill/main/install.sh" | bash
#
# Overrides:
#   INSTALL_DIR="$HOME/my-plugins" ... | bash
#   GITHUB_REPO="owner/repo" ... | bash

INSTALL_DIR="${INSTALL_DIR:-$HOME/.claude/plugins}"
PLUGIN_NAME="${PLUGIN_NAME:-dockerfile-skill}"
GITHUB_REPO="${GITHUB_REPO:-zjy365/dockerfile-skill}"

# Handle both direct execution and curl | bash (where BASH_SOURCE is empty)
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR=""
fi

mkdir -p "$INSTALL_DIR"
DEST="$INSTALL_DIR/$PLUGIN_NAME"

# Check if git is available
has_git() {
  command -v git &>/dev/null
}

install_from_local() {
  # When run from a local clone of this repo
  # Skip if SCRIPT_DIR is empty (curl | bash mode)
  if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/.claude-plugin/plugin.json" ]]; then
    rm -rf "$DEST"
    cp -R "$SCRIPT_DIR" "$DEST"
    echo "Installed from local repo: $DEST"
    return 0
  fi
  return 1
}

install_with_git() {
  local repo="$1"

  if [[ -d "$DEST/.git" ]]; then
    # Already installed with git, just pull
    echo "Updating existing installation..."
    git -C "$DEST" pull --ff-only
    echo "Updated: $DEST"
    return 0
  fi

  rm -rf "$DEST"
  if git clone --depth 1 "https://github.com/${repo}.git" "$DEST" 2>/dev/null; then
    echo "Installed from GitHub (git clone): $DEST"
    return 0
  fi

  return 1
}

# Global temp dir for cleanup
_INSTALL_TMP=""
cleanup_tmp() {
  [[ -n "$_INSTALL_TMP" && -d "$_INSTALL_TMP" ]] && rm -rf "$_INSTALL_TMP"
}
trap cleanup_tmp EXIT

install_from_tarball() {
  local repo="$1"
  _INSTALL_TMP="$(mktemp -d)"
  local tmp="$_INSTALL_TMP"

  for ref in main master; do
    rm -rf "${tmp:?}"/*
    local url="https://github.com/${repo}/archive/refs/heads/${ref}.tar.gz"
    local tarball="${tmp}/repo.tar.gz"

    if curl -fsSL "$url" -o "$tarball"; then
      tar -xzf "$tarball" -C "$tmp"

      local top
      top="$(
        shopt -s nullglob
        set -- "$tmp"/*
        printf '%s' "${1:-}"
      )"

      if [[ -f "$top/.claude-plugin/plugin.json" ]]; then
        rm -rf "$DEST"
        cp -R "$top" "$DEST"
        echo "Installed from GitHub (tarball): $DEST"
        echo "Note: Install with git for easier updates (git pull)"
        return 0
      fi
    fi
  done

  return 1
}

# Try installation methods in order
if install_from_local; then
  :
elif has_git && install_with_git "$GITHUB_REPO"; then
  :
elif install_from_tarball "$GITHUB_REPO"; then
  :
else
  cat >&2 <<EOF
install.sh error: failed to install plugin.

Tried:
- Local install (requires .claude-plugin/plugin.json)
- Git clone from: ${GITHUB_REPO}
- Tarball download from: ${GITHUB_REPO}

EOF
  exit 1
fi

cat <<EOF

✓ Plugin installed to: $DEST

To activate, run in Claude Code:
  /plugin add $DEST

To update (if installed with git):
  cd $DEST && git pull

EOF
