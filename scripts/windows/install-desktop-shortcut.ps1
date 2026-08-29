# Places "Sync Boss Fighter" on the Windows desktop.
$ErrorActionPreference = "Stop"

$desk = [Environment]::GetFolderPath("Desktop")
$batSrc = Join-Path $PSScriptRoot "Sync-Boss-Fighter.bat"
$batDest = Join-Path $desk "Sync Boss Fighter.bat"
$lnkPath = Join-Path $desk "Sync Boss Fighter.lnk"

if (-not (Test-Path $batSrc)) {
    throw "Missing $batSrc"
}

Copy-Item -Force $batSrc $batDest

$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($lnkPath)
$lnk.TargetPath = $batDest
$lnk.WorkingDirectory = $desk
$lnk.WindowStyle = 1
$lnk.Description = "Pull, save, and push Boss Fighter to Origin and GitHub"
$lnk.IconLocation = "imageres.dll,109"
$lnk.Save()

Write-Host "Desktop shortcut created:"
Write-Host "  $lnkPath"
Write-Host "Double-click 'Sync Boss Fighter' to update Origin and GitHub."
