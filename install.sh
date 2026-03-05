#!/usr/bin/env bash
set -euo pipefail

REPO="zjy365/sealos-deploy"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

SKILLS=(
  "sealos-deploy"
  "dockerfile-skill"
  "cloud-native-readiness"
  "docker-to-sealos"
)

echo "Installing Sealos Deploy..."
echo ""

# Download repo
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if command -v git &>/dev/null; then
  git clone --depth 1 "https://github.com/${REPO}.git" "$tmp/repo" 2>/dev/null
else
  curl -fsSL "https://github.com/${REPO}/archive/main.tar.gz" | tar -xz -C "$tmp"
  mv "$tmp"/sealos-deploy-main "$tmp/repo"
fi

# Install skills
mkdir -p "$SKILLS_DIR"

for skill in "${SKILLS[@]}"; do
  src="$tmp/repo/skills/$skill"
  dest="$SKILLS_DIR/$skill"

  if [ ! -d "$src" ]; then
    echo "  ✗ $skill — not found, skipping"
    continue
  fi

  rm -rf "$dest"
  cp -R "$src" "$dest"
done

chmod +x "$SKILLS_DIR/sealos-deploy/scripts/sealos-auth.mjs" 2>/dev/null || true

echo "  ✓ Installed to $SKILLS_DIR"
echo ""
echo "Usage — in Claude Code:"
echo "  /sealos-deploy <github-url>"
echo ""
