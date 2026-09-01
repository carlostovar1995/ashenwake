#!/usr/bin/env bash
# One-shot Origin setup for WSL (not PowerShell). Idempotent.
set -euo pipefail

if grep -qi microsoft /proc/version 2>/dev/null; then
  : # WSL
elif [[ "$(uname -s)" == "Linux" || "$(uname -s)" == "Darwin" ]]; then
  :
else
  echo "Run this inside WSL or a Unix shell, not Windows PowerShell." >&2
  echo "From PowerShell:  wsl" >&2
  echo "Or:  .\\scripts\\setup-windows.ps1" >&2
  exit 1
fi

MARKER='export PATH="$HOME/.local/bin:$PATH"'
BASHRC="${HOME}/.bashrc"
touch "${BASHRC}"
if ! grep -qF '.local/bin' "${BASHRC}"; then
  echo "${MARKER}" >> "${BASHRC}"
fi
export PATH="${HOME}/.local/bin:${PATH}"

if ! command -v origin >/dev/null 2>&1; then
  echo "Installing Origin CLI..."
  curl -fsSL https://downloads.cursor.com/origin/install.sh | sh
  export PATH="${HOME}/.local/bin:${PATH}"
fi

if ! command -v origin >/dev/null 2>&1; then
  echo "origin still not on PATH. Run: source ~/.bashrc" >&2
  exit 1
fi

echo "Using $(command -v origin)"

if [[ ! -d "${PWD}/.git" ]] && [[ ! -d "${HOME}/game-sync/.git" ]] && [[ ! -d "/mnt/c/Users/${USER}/game-sync/.git" ]]; then
  echo
  echo "Next (interactive — sign in if asked):"
  echo "  origin auth login"
  echo "  origin repo clone carlos-tovar/game-sync"
else
  echo "A game-sync git checkout already exists nearby. Pull instead of cloning again:"
  echo "  cd <clone> && git pull"
fi
