# Places a clean, distro-pinned "Sync Boss Fighter" launcher on Windows.
param(
    [string]$DistroHint = "",
    [Parameter(Mandatory = $true)]
    [string]$LinuxUser
)

$ErrorActionPreference = "Stop"

# Read canonical distro names from the Windows WSL registry. This avoids
# stale/misleading $WSL_DISTRO_NAME values such as "Ubuntu" when Windows
# registered the distro as "Ubuntu-24.04".
$candidates = New-Object System.Collections.Generic.List[string]
$lxss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
if (Test-Path $lxss) {
    foreach ($key in Get-ChildItem $lxss) {
        $name = (Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue).DistributionName
        if ($name -and $name -notlike "docker-desktop*" -and -not $candidates.Contains($name)) {
            [void]$candidates.Add($name)
        }
    }
}
if ($DistroHint -and $DistroHint -notlike "docker-desktop*" -and -not $candidates.Contains($DistroHint)) {
    [void]$candidates.Add($DistroHint)
}

$DistroName = $null
$wsl = Join-Path $env:SystemRoot "System32\wsl.exe"
$repoScript = "/home/$LinuxUser/game-sync/scripts/windows/sync-from-desktop.sh"
foreach ($candidate in $candidates) {
    Write-Host "Testing WSL distro: $candidate"
    & $wsl --distribution $candidate --exec /bin/sh -c "test -x /bin/bash && test -f '$repoScript'" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $DistroName = $candidate
        break
    }
}
if (-not $DistroName) {
    Write-Host "Registered WSL distros:"
    & $wsl --list --verbose
    throw "Could not find the distro containing $repoScript"
}

$desks = New-Object System.Collections.Generic.List[string]
$primary = [Environment]::GetFolderPath("Desktop")
if ($primary) { [void]$desks.Add($primary) }
foreach ($extra in @(
        (Join-Path $env:USERPROFILE "Desktop"),
        (Join-Path $env:USERPROFILE "OneDrive\Desktop")
    )) {
    if ((Test-Path $extra) -and -not $desks.Contains($extra)) {
        [void]$desks.Add($extra)
    }
}

$created = @()

foreach ($desk in $desks) {
    # Remove every old launcher so Windows cannot keep opening the stale
    # `wsl -e bash` version from OneDrive Desktop or the local Desktop.
    foreach ($oldName in @(
            "Sync Boss Fighter.lnk",
            "Sync Boss Fighter.bat",
            "Sync-Boss-Fighter.ps1",
            "Boss Fighter Sync.cmd"
        )) {
        Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $desk $oldName)
    }

    $cmdPath = Join-Path $desk "Boss Fighter Sync.cmd"
    $lnkPath = Join-Path $desk "Sync Boss Fighter.lnk"

    # The distro was proven above to contain /bin/bash and the sync script.
    $cmd = @"
@echo off
title Sync Boss Fighter
echo Using WSL distro: $DistroName
echo.
"$env:SystemRoot\System32\wsl.exe" --distribution "$DistroName" --exec /bin/bash /home/$LinuxUser/game-sync/scripts/windows/sync-from-desktop.sh
echo.
pause
"@
    Set-Content -LiteralPath $cmdPath -Value $cmd -Encoding ASCII

    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath = $cmdPath
    $lnk.WorkingDirectory = $desk
    $lnk.WindowStyle = 1
    $lnk.Description = "Pull, save, and push Boss Fighter to Origin and GitHub"
    $lnk.IconLocation = "imageres.dll,109"
    $lnk.Save()

    $created += $lnkPath
}

Write-Host "Removed old launchers and created a distro-pinned shortcut:"
Write-Host "  WSL distro: $DistroName"
Write-Host "  Linux user: $LinuxUser"
foreach ($p in $created) { Write-Host "  $p" }
Write-Host "Double-click 'Sync Boss Fighter'."
