# Desktop launcher: never use `wsl -e bash` (PATH is empty → execvpe(bash) failed).
$ErrorActionPreference = "Continue"

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
    return $names
}

function Get-PreferredDistro {
    $names = @(Get-WslDistroNames)
    $skip = @("docker-desktop", "docker-desktop-data")
    $usable = @($names | Where-Object {
            $n = $_
            -not ($skip | Where-Object { $n -like $_ })
        })
    $ubuntu = @($usable | Where-Object { $_ -like "Ubuntu*" } | Select-Object -First 1)
    if ($ubuntu) { return $ubuntu }
    if ($usable.Count -gt 0) { return $usable[0] }
    return $null
}

Write-Host "Syncing Boss Fighter (Origin + GitHub)..." -ForegroundColor Cyan
Write-Host ""

$distro = Get-PreferredDistro
if (-not $distro) {
    Write-Host "No Ubuntu WSL distro found. In PowerShell run: wsl -l -v" -ForegroundColor Red
    Write-Host "Install Ubuntu from the Microsoft Store, then try again."
    Read-Host "Press Enter to close"
    exit 1
}

Write-Host "Using WSL distro: $distro"
$bashLine = 'export PATH="$HOME/.local/bin:$PATH"; exec /bin/bash "$HOME/game-sync/scripts/windows/sync-from-desktop.sh"'

# Never use default `wsl` — it is often Docker, which has no /bin/bash.
& wsl.exe -d $distro -- /bin/bash -lc $bashLine
$code = $LASTEXITCODE

Write-Host ""
if ($code -eq 0) {
    Write-Host "Finished." -ForegroundColor Green
} else {
    Write-Host "Sync exited with code $code." -ForegroundColor Red
}
Read-Host "Press Enter to close"
exit $code
