#!/usr/bin/env bash
# Push the current branch to Origin and, if configured, GitHub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.local/bin:${PATH}"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "Pushing ${BRANCH} to origin (Cursor Origin)..."
git push -u origin "${BRANCH}"

if git remote get-url github >/dev/null 2>&1; then
  echo "Pushing ${BRANCH} to github..."
  git push -u github "${BRANCH}"
else
  echo "No 'github' remote yet. Create a GitHub repo, then:"
  echo "  ./scripts/setup-github-remote.sh YOURUSER/game-sync"
fi
