# Places a clean, distro-pinned "Sync Boss Fighter" launcher on Windows.
param(
    [Parameter(Mandatory = $true)]
    [string]$DistroName,
    [Parameter(Mandatory = $true)]
    [string]$LinuxUser
)

$ErrorActionPreference = "Stop"

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

    # DistroName comes from $WSL_DISTRO_NAME in the Ubuntu shell that runs
    # the installer. /bin/bash is absolute: no PATH lookup can fail.
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
