# Install a native "Sync Ashenwake" desktop shortcut (no WSL).
$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$syncPs1 = Join-Path $PSScriptRoot "Sync-Ashenwake.ps1"
if (-not (Test-Path -LiteralPath $syncPs1)) {
    throw "Missing $syncPs1"
}

$iconIco = Join-Path $repo "icon.ico"
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
            "Boss Fighter Sync.cmd",
            "Sync Ashenwake.lnk",
            "Ashenwake Sync.cmd"
        )) {
        Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $desk $oldName)
    }

    $lnkPath = Join-Path $desk "Sync Ashenwake.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath = $powershell
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$syncPs1`""
    $lnk.WorkingDirectory = $repo
    $lnk.WindowStyle = 1
    $lnk.Description = "Pull, save, and push Ashenwake to GitHub"
    if (Test-Path -LiteralPath $iconIco) {
        $lnk.IconLocation = "$iconIco,0"
    } else {
        $lnk.IconLocation = "imageres.dll,109"
    }
    $lnk.Save()
    $created += $lnkPath
}

Write-Host "Installed Sync Ashenwake:"
foreach ($p in $created) { Write-Host "  $p" }
Write-Host "Repo: $repo"
