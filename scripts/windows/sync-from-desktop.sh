#!/usr/bin/env bash
# Run from the Windows desktop shortcut (via WSL). Pulls, commits local
# game edits if needed, wires GitHub once, then pushes Origin + GitHub.
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

REPO="${HOME}/game-sync"
if [[ ! -d "${REPO}/.git" ]]; then
  echo "Could not find ${REPO}."
  echo "Clone first: origin repo clone carlos-tovar/game-sync"
  exit 1
fi

cd "${REPO}"
chmod +x scripts/*.sh 2>/dev/null || true

echo "==> Updating from Origin"
git fetch origin
if git status --porcelain | grep -q .; then
  git pull --rebase origin main || git pull origin main
else
  git pull origin main
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "==> Saving local game changes"
  git add -A
  git commit -m "Sync from Windows $(date -Iseconds)" || true
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "==> Installing GitHub CLI"
  sudo apt-get update -qq
  sudo apt-get install -y gh
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "==> GitHub login (browser will open)"
  gh auth login
fi

if ! git remote get-url github >/dev/null 2>&1; then
  echo "==> Linking GitHub mirror"
  ./scripts/setup-github-remote.sh carlostovar1995/game-sync
else
  echo "==> Pushing Origin + GitHub"
  ./scripts/push-both.sh
fi

echo
echo "Done. Origin and GitHub should both be up to date."
echo "GitHub: https://github.com/carlostovar1995/game-sync"
