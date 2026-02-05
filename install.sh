#!/usr/bin/env bash
set -euo pipefail

# One-liner (global install):
#   curl -fsSL "https://raw.githubusercontent.com/zjy365/dockerfile-skill/main/install.sh" | bash
#
# Project-local install:
#   CLAUDE_SKILLS_DIR="$(pwd)/.claude/skills" curl -fsSL "https://raw.githubusercontent.com/zjy365/dockerfile-skill/main/install.sh" | bash
#
# Overrides:
#   GITHUB_REPO="owner/repo" ... | bash
#   SKILL_DIR_NAME="custom-folder-name" ... | bash

SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
SKILL_DIR_NAME="${SKILL_DIR_NAME:-dockerfile-skill}"
GITHUB_REPO="${GITHUB_REPO:-zjy365/dockerfile-skill}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$SKILLS_DIR"
DEST="$SKILLS_DIR/$SKILL_DIR_NAME"

install_from_local() {
  # When run from a local clone of this repo.
  if [[ -f "$SCRIPT_DIR/SKILL.md" ]]; then
    rm -rf "$DEST"
    cp -R "$SCRIPT_DIR" "$DEST"
    echo "Installed from local repo: $DEST"
    return 0
  fi
  return 1
}

install_from_github() {
  local repo="$1"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  for ref in main master; do
    rm -rf "$tmp"/*
    local url="https://github.com/${repo}/archive/refs/heads/${ref}.tar.gz"
    local tarball="${tmp}/repo.tar.gz"

    if curl -fsSL "$url" -o "$tarball"; then
      tar -xzf "$tarball" -C "$tmp"

      # tarball expands to a single top folder like: dockerfile-skill-main/
      local top
      top="$(
        shopt -s nullglob
        set -- "$tmp"/*
        printf '%s' "${1:-}"
      )"

      if [[ -f "$top/SKILL.md" ]]; then
        rm -rf "$DEST"
        cp -R "$top" "$DEST"
        echo "Installed from GitHub (${repo}@${ref}): $DEST"
        return 0
      fi
    fi
  done

  return 1
}

if install_from_local; then
  exit 0
fi

if install_from_github "$GITHUB_REPO"; then
  exit 0
fi

cat >&2 <<EOF
install.sh error: failed to install skill.

Tried:
- Local install (requires SKILL.md next to install.sh)
- GitHub download from: ${GITHUB_REPO} (main/master)

Expected repo layout:
- SKILL.md at repo root
EOF
exit 1

