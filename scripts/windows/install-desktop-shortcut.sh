#!/usr/bin/env bash
# Copy the Sync Boss Fighter shortcut to the Windows desktop.
# Run once in Ubuntu:  ./scripts/windows/install-desktop-shortcut.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PS1="${ROOT}/scripts/windows/install-desktop-shortcut.ps1"

if [[ ! -f "$PS1" ]]; then
  echo "Missing $PS1" >&2
  exit 1
fi

WIN_PS1="$(wslpath -w "$PS1")"
echo "Installing desktop shortcut..."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS1"

echo
echo "Usual locations:"
echo "  C:\\Users\\carlo\\OneDrive\\Desktop\\Sync Boss Fighter.lnk"
echo "  C:\\Users\\carlo\\Desktop\\Sync Boss Fighter.lnk"
echo "Look on your Windows desktop for 'Sync Boss Fighter'."
