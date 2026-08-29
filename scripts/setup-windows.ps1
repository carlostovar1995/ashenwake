# Origin CLI does not run in PowerShell. This only starts WSL and runs Linux setup.
# From Windows PowerShell:
#   powershell -ExecutionPolicy Bypass -File scripts\setup-windows.ps1

$ErrorActionPreference = "Stop"

if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Host "WSL is not installed. Open PowerShell as Administrator, then:"
    Write-Host "  wsl --install"
    Write-Host "Reboot, open Ubuntu from the Start menu, and run scripts/setup-origin.sh there."
    exit 1
}

$linux = @'
export PATH="$HOME/.local/bin:$PATH"
if [ -f "$HOME/game-sync/scripts/setup-origin.sh" ]; then
  bash "$HOME/game-sync/scripts/setup-origin.sh"
elif [ -f "./scripts/setup-origin.sh" ]; then
  bash "./scripts/setup-origin.sh"
else
  curl -fsSL https://downloads.cursor.com/origin/install.sh | sh
  if ! grep -qF '.local/bin' ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  fi
  export PATH="$HOME/.local/bin:$PATH"
  echo "Origin installed. Next:"
  echo "  origin auth login"
  echo "  origin repo clone carlos-tovar/game-sync"
fi
'@

Write-Host "Running Origin setup inside WSL (not PowerShell)..."
wsl.exe -d Ubuntu -e /bin/bash -lc $linux
if ($LASTEXITCODE -ne 0) {
    wsl.exe -e /bin/bash -lc $linux
}
