#!/usr/bin/env bash
# Push the current branch to Origin and, if configured, GitHub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="${HOME}/.local/bin:${PATH}"
# shellcheck source=github-git.sh
source "${ROOT}/scripts/github-git.sh"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "Pushing ${BRANCH} to origin (Cursor Origin)..."
git push -u origin "${BRANCH}"
echo "Pushing tags to origin..."
git push origin --tags

if git remote get-url github >/dev/null 2>&1; then
  echo "Pushing ${BRANCH} to github..."
  # GitHub is only a mirror. Never make it the branch upstream: plain
  # `git pull` must continue to read from Cursor Origin.
  github_git push github "${BRANCH}"
  echo "Pushing tags to github..."
  github_git push github --tags
  git branch --set-upstream-to="origin/${BRANCH}" "${BRANCH}" >/dev/null
else
  echo "No 'github' remote yet. Create a GitHub repo, then:"
  echo "  ./scripts/setup-github-remote.sh carlostovar1995/game-sync"
fi
