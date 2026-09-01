#!/usr/bin/env bash
# Git commands against github.com must use `gh`, not Windows Credential Manager.
# WSL often sends a cached GitHub token that 403s even when `gh auth` works.
github_git() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "Install GitHub CLI (gh), then: gh auth login" >&2
    return 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "Not logged in to GitHub. Run: gh auth login" >&2
    return 1
  fi
  git -c credential.helper= \
      -c credential.https://github.com.helper= \
      -c credential.https://github.com.helper="!gh auth git-credential" \
      "$@"
}

ensure_gh_repo_scope() {
  echo "Ensuring GitHub token can write private repos..."
  gh auth refresh -h github.com -s repo
}
