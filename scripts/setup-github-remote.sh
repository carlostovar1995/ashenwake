#!/usr/bin/env bash
# Add GitHub as a second remote so non-Cursor users can clone.
# Origin stays the Cursor Cloud Agent host.
#
# 1. Create an empty GitHub repo (no README) at https://github.com/new
#    or run:  gh auth login && gh repo create YOURUSER/game-sync --private
# 2. From the game-sync clone:
#      ./scripts/setup-github-remote.sh YOURUSER/game-sync
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.local/bin:${PATH}"

SLUG="${1:-}"
if [[ -z "$SLUG" || "$SLUG" != */* ]]; then
  echo "Usage: $0 GITHUB_USER/REPO" >&2
  echo "Example: $0 carlostovar1995/game-sync" >&2
  exit 2
fi

URL="https://github.com/${SLUG}.git"

if git remote get-url github >/dev/null 2>&1; then
  echo "Updating github remote -> ${URL}"
  git remote set-url github "$URL"
else
  echo "Adding github remote -> ${URL}"
  git remote add github "$URL"
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh auth setup-git >/dev/null 2>&1 || true
  if ! gh repo view "$SLUG" >/dev/null 2>&1; then
    echo "Creating private GitHub repo ${SLUG}..."
    gh repo create "$SLUG" --private --source=. --remote=github --description "Boss Fighter (Godot) — mirror of Cursor Origin game-sync"
  fi
fi

echo "Pushing main to GitHub (this can take a while)..."
git push -u github main

echo
echo "GitHub: https://github.com/${SLUG}"
echo "Origin: https://cursor.com/codebase/carlos-tovar/game-sync"
echo "Later, from this folder:  ./scripts/push-both.sh"
