# Places "Sync Boss Fighter" on the Windows desktop (OneDrive Desktop if used).
$ErrorActionPreference = "Stop"

$batSrc = Join-Path $PSScriptRoot "Sync-Boss-Fighter.bat"
if (-not (Test-Path $batSrc)) {
    throw "Missing $batSrc"
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
    $batDest = Join-Path $desk "Sync Boss Fighter.bat"
    $lnkPath = Join-Path $desk "Sync Boss Fighter.lnk"
    Copy-Item -Force $batSrc $batDest

    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath = $batDest
    $lnk.WorkingDirectory = $desk
    $lnk.WindowStyle = 1
    $lnk.Description = "Pull, save, and push Boss Fighter to Origin and GitHub"
    $lnk.IconLocation = "imageres.dll,109"
    $lnk.Save()

    $created += $lnkPath
}

Write-Host "Desktop shortcut created at:"
foreach ($p in $created) {
    Write-Host "  $p"
}
Write-Host "Double-click 'Sync Boss Fighter' to update Origin and GitHub."
