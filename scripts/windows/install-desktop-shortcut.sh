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
DISTRO="${WSL_DISTRO_NAME:-}"
if [[ -z "$DISTRO" ]]; then
  echo "WSL_DISTRO_NAME is missing. Open the Ubuntu app from Start and run this script there." >&2
  exit 1
fi

echo "Installing desktop shortcut for WSL distro: ${DISTRO}"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS1" \
  -DistroName "$DISTRO" \
  -LinuxUser "$USER"

echo
echo "Old launchers were removed. Look for the new 'Sync Boss Fighter'."
