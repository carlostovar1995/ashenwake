#!/usr/bin/env bash
# Daily sync is native Windows now. Do not install from WSL.
echo "Ashenwake sync is a Windows shortcut, not a WSL script."
echo "In PowerShell, from the Ashenwake folder:"
echo "  powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\windows\\install-desktop-shortcut.ps1"
exit 1
