#!/usr/bin/env bash
# Persist Origin CLI on PATH in WSL bash. Safe to re-run.
set -euo pipefail

MARKER='export PATH="$HOME/.local/bin:$PATH"'
BASHRC="${HOME}/.bashrc"

touch "${BASHRC}"
if ! grep -qF '.local/bin:$PATH' "${BASHRC}" && ! grep -qF '.local/bin:$PATH"' "${BASHRC}"; then
  echo "${MARKER}" >> "${BASHRC}"
  echo "Added ~/.local/bin to PATH in ${BASHRC}"
else
  echo "~/.local/bin already referenced in ${BASHRC}"
fi

export PATH="${HOME}/.local/bin:${PATH}"

if command -v origin >/dev/null 2>&1; then
  echo "origin: $(command -v origin)"
  origin version 2>/dev/null || origin --version 2>/dev/null || true
else
  echo "origin is not installed yet. In WSL run:"
  echo "  curl -fsSL https://downloads.cursor.com/origin/install.sh | sh"
  echo "  source ~/.bashrc"
  exit 1
fi
