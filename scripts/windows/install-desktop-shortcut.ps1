# Places a clean "Sync Boss Fighter" launcher on Windows.
# The shortcut runs PowerShell so cmd.exe cannot pass quoted distro names to WSL.
param(
    [string]$DistroHint = "",
    [Parameter(Mandatory = $true)]
    [string]$LinuxUser
)

$ErrorActionPreference = "Stop"

$sourcePs1 = Join-Path $PSScriptRoot "Sync-Boss-Fighter.ps1"
if (-not (Test-Path -LiteralPath $sourcePs1)) {
    throw "Missing $sourcePs1"
}

$launcherPs1 = Join-Path $env:USERPROFILE "Sync-Boss-Fighter.ps1"
Copy-Item -LiteralPath $sourcePs1 -Destination $launcherPs1 -Force

$iconIco = Join-Path $env:USERPROFILE "game-sync-icon.ico"
$wslIcon = "\\wsl`$\$LinuxUser\game-sync\icon.ico"
foreach ($distroGuess in @($DistroHint, "Ubuntu")) {
    if (-not $distroGuess) { continue }
    $candidate = "\\wsl`$\$distroGuess\home\$LinuxUser\game-sync\icon.ico"
    if (Test-Path -LiteralPath $candidate) {
        $wslIcon = $candidate
        break
    }
}
if (Test-Path -LiteralPath $wslIcon) {
    Copy-Item -LiteralPath $wslIcon -Destination $iconIco -Force
}

$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
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
    $cmdLines = @(
        "@echo off",
        "title Sync Boss Fighter",
        "echo Syncing Boss Fighter to Origin and GitHub...",
        "echo.",
        "`"$powershell`" -NoProfile -ExecutionPolicy Bypass -File `"$launcherPs1`""
    )
    [System.IO.File]::WriteAllText($cmdPath, ($cmdLines -join "`r`n") + "`r`n")

    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath = $powershell
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPs1`""
    $lnk.WorkingDirectory = $env:USERPROFILE
    $lnk.WindowStyle = 1
    $lnk.Description = "Pull, save, and push Boss Fighter to Origin and GitHub"
    if (Test-Path -LiteralPath $iconIco) {
        $lnk.IconLocation = "$iconIco,0"
    } else {
        $lnk.IconLocation = "imageres.dll,109"
    }
    $lnk.Save()

    $created += $lnkPath
}

Write-Host "Installed PowerShell desktop shortcut (resolves Ubuntu at click time):"
Write-Host "  Launcher: $launcherPs1"
foreach ($p in $created) { Write-Host "  $p" }
Write-Host "Double-click 'Sync Boss Fighter'."
