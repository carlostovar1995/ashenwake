# Install a native "Ashenwake" desktop shortcut that launches the game.
$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$godot = Join-Path $env:LOCALAPPDATA "Programs\Godot\Godot_v4.7.2-stable_win64.exe"
if (-not (Test-Path -LiteralPath $godot)) {
    $found = Get-ChildItem (Join-Path $env:LOCALAPPDATA "Programs\Godot") -Filter "Godot*_win64.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*console*" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($found) { $godot = $found.FullName }
}
if (-not (Test-Path -LiteralPath $godot)) {
    throw "Godot not found under $env:LOCALAPPDATA\Programs\Godot"
}

$iconIco = Join-Path $repo "ashenwake.ico"
if (-not (Test-Path -LiteralPath $iconIco)) {
    $iconIco = Join-Path $repo "icon.ico"
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
    foreach ($oldName in @("Boss Fighter.lnk", "Ashenwake.lnk")) {
        Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $desk $oldName)
    }

    $lnkPath = Join-Path $desk "Ashenwake.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath = $godot
    $lnk.Arguments = "--path `"$repo`""
    $lnk.WorkingDirectory = $repo
    $lnk.WindowStyle = 1
    $lnk.Description = "Play Ashenwake"
    if (Test-Path -LiteralPath $iconIco) {
        $lnk.IconLocation = "$iconIco,0"
    }
    $lnk.Save()
    $created += $lnkPath
}

Write-Host "Installed Ashenwake:"
foreach ($p in $created) { Write-Host "  $p" }
Write-Host "Godot: $godot"
Write-Host "Repo: $repo"
