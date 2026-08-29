# Run this in Windows PowerShell (not Ubuntu). Finds the Ubuntu disk and
# installs the desktop icon without using the default `wsl` (often Docker).
$ErrorActionPreference = "Stop"

function Get-WslDistroNames {
    $names = @()
    $raw = & wsl.exe -l -q --utf8 2>$null
    if ($raw) {
        $names = @($raw | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    }
    if ($names.Count -eq 0) {
        $stripped = ((& wsl.exe -l -q) | Out-String) -replace "`0", ""
        $names = @($stripped -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }
    return @($names | Where-Object { $_ -and $_ -notlike "docker-desktop*" })
}

Write-Host "WSL distros:"
& wsl.exe -l -v

$distro = @(Get-WslDistroNames | Where-Object { $_ -like "Ubuntu*" } | Select-Object -First 1)
if (-not $distro) {
    $distro = @(Get-WslDistroNames | Select-Object -First 1)
}
if (-not $distro) {
    throw "No Ubuntu WSL distro found. Open Ubuntu from the Start menu once, then retry."
}

Write-Host "Installing shortcut via distro: $distro"
$bash = 'cd "$HOME/game-sync" && git pull origin main && chmod +x scripts/windows/*.sh && ./scripts/windows/install-desktop-shortcut.sh'
& wsl.exe -d $distro -- /bin/bash -lc $bash
if ($LASTEXITCODE -ne 0) {
    throw "Install failed (exit $LASTEXITCODE). Open Ubuntu and run: cd ~/game-sync && git pull origin main && ./scripts/windows/install-desktop-shortcut.sh"
}

Write-Host "Done. Double-click Sync Boss Fighter on the desktop."
