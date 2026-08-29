# Places "Sync Boss Fighter" on the Windows desktop.
# The .lnk starts PowerShell (not `wsl -e bash`).
$ErrorActionPreference = "Stop"

$ps1Src = Join-Path $PSScriptRoot "Sync-Boss-Fighter.ps1"
$batSrc = Join-Path $PSScriptRoot "Sync-Boss-Fighter.bat"
if (-not (Test-Path $ps1Src)) { throw "Missing $ps1Src" }

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
$pwsh = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

foreach ($desk in $desks) {
    $ps1Dest = Join-Path $desk "Sync-Boss-Fighter.ps1"
    $batDest = Join-Path $desk "Sync Boss Fighter.bat"
    $lnkPath = Join-Path $desk "Sync Boss Fighter.lnk"
    Copy-Item -Force $ps1Src $ps1Dest
    if (Test-Path $batSrc) { Copy-Item -Force $batSrc $batDest }

    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath = $pwsh
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ps1Dest`""
    $lnk.WorkingDirectory = $desk
    $lnk.WindowStyle = 1
    $lnk.Description = "Pull, save, and push Boss Fighter to Origin and GitHub"
    $lnk.IconLocation = "$pwsh,0"
    $lnk.Save()

    $created += $lnkPath
}

Write-Host "Desktop shortcut created at:"
foreach ($p in $created) { Write-Host "  $p" }
Write-Host "Double-click 'Sync Boss Fighter' (the icon, not the .ps1)."
