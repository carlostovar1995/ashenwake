# Desktop launcher. Resolves Ubuntu at click time and runs the sync script
# with --exec so PowerShell cannot swallow a quoted bash -lc line.
# Never use default `wsl` — it is often Docker, which has no /bin/bash.
$ErrorActionPreference = "Continue"

function Get-WslDistroNames {
    $names = New-Object System.Collections.Generic.List[string]
    $lxss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    if (Test-Path $lxss) {
        foreach ($key in Get-ChildItem $lxss) {
            $name = (Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue).DistributionName
            if ($name -and -not $names.Contains($name)) {
                [void]$names.Add($name)
            }
        }
    }
    if ($names.Count -eq 0) {
        $stripped = ((& wsl.exe -l -q) | Out-String) -replace "`0", ""
        foreach ($line in ($stripped -split "`r?`n")) {
            $n = $line.Trim()
            if ($n -and -not $names.Contains($n)) { [void]$names.Add($n) }
        }
    }
    return $names
}

function Get-LinuxText {
    param([string[]]$Parts)
    return (($Parts | Out-String) -replace "`0", "").Trim()
}

function Get-PreferredDistro {
    $skip = @("docker-desktop", "docker-desktop-data")
    $wsl = Join-Path $env:SystemRoot "System32\wsl.exe"
    $usable = @(Get-WslDistroNames | Where-Object {
            $n = $_
            -not ($skip | Where-Object { $n -like "$_*" })
        })
    $ordered = @($usable | Where-Object { $_ -like "Ubuntu*" }) + @($usable | Where-Object { $_ -notlike "Ubuntu*" })
    foreach ($candidate in $ordered) {
        if (-not $candidate) { continue }
        Write-Host "Testing WSL distro: $candidate"
        $user = Get-LinuxText (& $wsl -d $candidate --exec /bin/bash -c "id -un")
        if (-not $user) { continue }
        $script = "/home/$user/game-sync/scripts/windows/sync-from-desktop.sh"
        & $wsl -d $candidate --exec /bin/bash -c "test -x /bin/bash -a -f $script"
        if ($LASTEXITCODE -eq 0) {
            return @{ Name = $candidate; User = $user; Script = $script }
        }
    }
    return $null
}

Write-Host "Syncing Boss Fighter (Origin + GitHub)..." -ForegroundColor Cyan
Write-Host ""

$distro = Get-PreferredDistro
if (-not $distro) {
    Write-Host "No Ubuntu WSL distro found that contains game-sync." -ForegroundColor Red
    Write-Host "In PowerShell run: wsl -l -v"
    Write-Host "Then open the Ubuntu app from Start once and try again."
    Read-Host "Press Enter to close"
    exit 1
}

Write-Host "Using WSL distro: $($distro.Name)"
Write-Host "Running $($distro.Script)"
Write-Host ""

$wsl = Join-Path $env:SystemRoot "System32\wsl.exe"
# --exec + absolute path: no nested quotes for PowerShell to mangle.
& $wsl -d $distro.Name --exec /bin/bash $distro.Script
$code = $LASTEXITCODE

Write-Host ""
if ($code -eq 0) {
    Write-Host "Finished." -ForegroundColor Green
} else {
    Write-Host "Sync exited with code $code." -ForegroundColor Red
}
Read-Host "Press Enter to close"
exit $code
