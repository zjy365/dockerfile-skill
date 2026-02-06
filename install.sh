#!/usr/bin/env bash
set -euo pipefail

DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/dockerfile-skill"
REPO="zjy365/dockerfile-skill"

mkdir -p "$(dirname "$DEST")"

if command -v git &>/dev/null; then
  rm -rf "$DEST"
  git clone --depth 1 "https://github.com/${REPO}.git" "$DEST"
else
  tmp="$(mktemp -d)"
  trap "rm -rf '$tmp'" EXIT
  curl -fsSL "https://github.com/${REPO}/archive/main.tar.gz" | tar -xz -C "$tmp"
  rm -rf "$DEST"
  mv "$tmp"/*/ "$DEST"
fi

echo "Installed: $DEST"
