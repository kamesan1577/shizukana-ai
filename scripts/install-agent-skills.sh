#!/usr/bin/env bash
set -euo pipefail

echo "Installing Apple design skill..."
npx skills add dickwu/apple-design-skill

echo "Installing anti-slop skills..."
npx skills add miqdadbadjuber/anti-slop

echo
echo "Done."
echo "Verify that Codex can discover the installed skills before starting UI work."
