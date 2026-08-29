#!/usr/bin/env bash
# Run from the Windows desktop shortcut (via WSL). Pulls latest scripts,
# commits local game edits if needed, then pushes Origin + GitHub using `gh`.
set -euo pipefail

# WSL can import Windows HOME (C:\Users\...), which breaks ~/game-sync.
if [[ "${HOME:-}" != /home/* ]]; then
  export HOME="/home/$(id -un)"
fi
export PATH="${HOME}/.local/bin:${PATH}"

REPO="${HOME}/game-sync"
if [[ ! -d "${REPO}/.git" ]]; then
  echo "Could not find ${REPO}."
  echo "Clone first: origin repo clone carlos-tovar/game-sync"
  exit 1
fi

cd "${REPO}"
chmod +x scripts/*.sh scripts/windows/*.sh 2>/dev/null || true

if [[ "${1:-}" != "--after-pull" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "==> Saving local game changes"
    git add -A
    git commit -m "Sync from Windows $(date -Iseconds)" || true
  fi
  echo "==> Updating from Origin (including this shortcut script)"
  git fetch origin
  git pull --rebase origin main || git pull origin main
  exec bash "${REPO}/scripts/windows/sync-from-desktop.sh" --after-pull
fi

# shellcheck source=../github-git.sh
source "${REPO}/scripts/github-git.sh"

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
echo
echo "Desktop icon:"
echo "  C:\\Users\\carlo\\OneDrive\\Desktop\\Sync Boss Fighter.lnk"
echo "  C:\\Users\\carlo\\Desktop\\Sync Boss Fighter.lnk"
