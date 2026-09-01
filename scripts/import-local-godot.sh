#!/usr/bin/env bash
# Copy a local Godot project into this Origin repo without dropping the Cursor kit.
# Run in WSL, from the game-sync clone (or pass --repo).
#
#   ./scripts/import-local-godot.sh "/mnt/c/Users/carlo/OneDrive/Desktop/Projects/Boss Game"
#   ./scripts/import-local-godot.sh --push "C:\Users\carlo\OneDrive\Desktop\Projects\Boss Game"
set -euo pipefail

usage() {
  echo "Usage: $0 [--push] [--repo DIR] GODOT_PROJECT_PATH" >&2
  exit 2
}

PUSH=0
REPO=""
SRC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push) PUSH=1; shift ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    -h|--help) usage ;;
    *)
      SRC="$1"
      shift
      ;;
  esac
done

win_to_wsl() {
  local p="$1"
  p="${p//\\//}"
  if [[ "$p" =~ ^[A-Za-z]: ]]; then
    local drive
    drive="$(echo "${p:0:1}" | tr 'A-Z' 'a-z')"
    echo "/mnt/${drive}${p:2}"
  else
    echo "$p"
  fi
}

find_repo() {
  local cand
  for cand in \
    "$PWD" \
    "${HOME}/game-sync" \
    "/mnt/c/Users/${USER}/game-sync" \
    "/mnt/c/Users/carlo/game-sync" \
    "/mnt/c/Users/carlo/OneDrive/Desktop/game-sync"
  do
    if [[ -d "${cand}/.git" && -f "${cand}/.cursor/environment.json" ]]; then
      echo "${cand}"
      return 0
    fi
  done
  return 1
}

if [[ -z "$SRC" ]]; then
  echo "Missing Godot project path." >&2
  usage
fi

SRC="$(win_to_wsl "$SRC")"

if [[ ! -e "$SRC" ]]; then
  echo "Source not found: $SRC" >&2
  echo "In WSL, Windows C: is /mnt/c/..." >&2
  echo
  echo "Nearby under /mnt/c/Users/${USER:-carlo}:" >&2
  ls -la "/mnt/c/Users/${USER:-carlo}" 2>/dev/null | head -n 30 || true
  echo
  echo "OneDrive / Desktop folders:" >&2
  ls -d /mnt/c/Users/"${USER:-carlo}"/OneDrive* /mnt/c/Users/"${USER:-carlo}"/Desktop 2>/dev/null || true
  echo
  echo "Searching for project.godot (this can take a minute)..." >&2
  find /mnt/c/Users/"${USER:-carlo}" -maxdepth 6 -name project.godot 2>/dev/null | head -n 20 || true
  echo
  echo "Or drag the Godot project folder from File Explorer into this Ubuntu window to paste its real path." >&2
  exit 1
fi

GODOT_ROOT=""
if [[ -f "$SRC/project.godot" ]]; then
  GODOT_ROOT="$SRC"
else
  local_hit="$(find "$SRC" -maxdepth 3 -name project.godot -print 2>/dev/null | head -n 1 || true)"
  if [[ -n "$local_hit" ]]; then
    GODOT_ROOT="$(dirname "$local_hit")"
  fi
fi

if [[ -z "$GODOT_ROOT" || ! -f "$GODOT_ROOT/project.godot" ]]; then
  echo "No project.godot under: $SRC" >&2
  exit 1
fi

if [[ -z "$REPO" ]]; then
  REPO="$(find_repo || true)"
fi
if [[ -z "$REPO" ]]; then
  echo "Could not find the game-sync git clone. cd into it or pass --repo." >&2
  exit 1
fi

echo "Godot project: $GODOT_ROOT"
echo "Repo:          $REPO"

mkdir -p "$REPO"
if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude '.git/' \
    --exclude '.godot/' \
    --exclude '.mono/' \
    --exclude '.cursor/' \
    --exclude 'agent-tools/' \
    "$GODOT_ROOT"/ "$REPO"/
else
  tmp="$(mktemp -d)"
  cp -a "$GODOT_ROOT"/. "$tmp"/
  rm -rf "$tmp/.git" "$tmp/.godot" "$tmp/.mono" "$tmp/.cursor"
  cp -a "$tmp"/. "$REPO"/
  rm -rf "$tmp"
fi

cd "$REPO"

KIT_PATHS=(
  .cursor
  AGENTS.md
  README.md
  .cursorignore
  .gitattributes
  .gitignore
  scripts/cloud-agent-install.sh
  scripts/verify-headless.sh
  scripts/setup-origin.sh
  scripts/ensure-origin-path.sh
  scripts/setup-windows.ps1
  scripts/import-local-godot.sh
  tools/ci_check.gd
  tools/ci_check.gd.uid
)
for p in "${KIT_PATHS[@]}"; do
  if git cat-file -e "HEAD:${p}" 2>/dev/null; then
    git checkout HEAD -- "$p"
  fi
done

if grep -q 'config/features' project.godot; then
  ver="$(grep 'config/features' project.godot | grep -oE '4\.[0-9]+(\.[0-9]+)?' | head -n 1 || true)"
  if [[ -n "${ver:-}" ]]; then
    echo "${ver}-stable" > .godot-version
    echo "Pinned .godot-version to ${ver}-stable"
  fi
fi

echo
echo "Import finished. project.godot name:"
grep '^config/name=' project.godot || true

if [[ "$PUSH" -eq 1 ]]; then
  export PATH="${HOME}/.local/bin:${PATH}"
  if [[ -z "$(git config user.email || true)" || -z "$(git config user.name || true)" ]]; then
    echo
    echo "Git needs a name and email before it can commit. In this same Ubuntu window run:"
    echo "  git config --global user.name \"Carlos Tovar\""
    echo "  git config --global user.email \"carlostovar1995@gmail.com\""
    echo "  git add -A"
    echo "  git commit -m \"Import Godot project from local Boss Game folder\""
    echo "  git push -u origin HEAD"
    exit 1
  fi
  git add -A
  if git diff --cached --quiet; then
    echo "No changes to commit."
  else
    git commit -m "Import Godot project from local Boss Game folder"
  fi
  ./scripts/push-both.sh
  echo "Pushed. Cloud Agents can use this revision."
else
  echo
  echo "Review, then:"
  echo "  cd \"$REPO\""
  echo "  git add -A && git commit -m 'Import Godot project from local Boss Game folder' && git push"
fi
