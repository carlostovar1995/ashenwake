#Requires -Version 5.1
# Shared helpers for the baseline-*.ps1 commands. Dot-source this file.

$script:Repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

function Find-Godot {
    if ($env:GODOT -and (Test-Path -LiteralPath $env:GODOT -PathType Leaf)) {
        return Get-ConsoleBuild $env:GODOT
    }
    foreach ($name in @('godot', 'godot4')) {
        $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $cmd) { return Get-ConsoleBuild $cmd.Source }
    }
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Godot'),
        'C:\Godot',
        'C:\Program Files\Godot'
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $hit = Get-ChildItem -LiteralPath $root -Filter 'Godot*.exe' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch 'manager' } |
            Sort-Object @{ Expression = { if ($_.Name -match '_console\.exe$') { 0 } else { 1 } } }, Name |
            Select-Object -First 1
        if ($null -ne $hit) { return Get-ConsoleBuild $hit.FullName }
    }
    throw 'Godot not found. Set $env:GODOT or put the pinned Godot on PATH.'
}

# The console build is the one whose stdout PowerShell can capture.
function Get-ConsoleBuild([string]$Path) {
    if ($Path -match '(?i)\.exe$' -and $Path -notmatch '(?i)_console\.exe$') {
        $console = Join-Path (Split-Path $Path -Parent) ([IO.Path]::GetFileNameWithoutExtension($Path) + '_console.exe')
        if (Test-Path -LiteralPath $console -PathType Leaf) { return $console }
    }
    return $Path
}

function Assert-PinnedGodot([string]$Godot) {
    $pin = (Get-Content -LiteralPath (Join-Path $script:Repo '.godot-version') -Raw).Trim()
    $line = & cmd.exe /d /c "`"$Godot`" --version 2>&1"
    $version = ($line | Out-String).Trim()
    $want = $pin -replace '-', '.'
    if ($version -notlike "$want*") {
        throw "Godot version mismatch. Repo pins $pin; '$Godot' reports '$version'."
    }
}

# Runs Godot against the project, echoing its output minus addon polling noise.
# Returns @{ Code; Lines }. Throws if the run reports a script error.
function Invoke-GodotRun([string]$Godot, [string[]]$GodotArgs, [string]$Label) {
    Write-Host "==> $Label" -ForegroundColor Cyan
    $quoted = ($GodotArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join ' '
    $lines = @()
    & cmd.exe /d /c "`"$Godot`" --path `"$script:Repo`" $quoted 2>&1" | ForEach-Object {
        $text = "$_"
        if ($text -match '^\[MCP Runtime\]') { return }
        $lines += $text
        if ($text -match '^(baseline-|BASELINE_|SCRIPT ERROR|ERROR:)') { Write-Host $text }
    }
    $code = $LASTEXITCODE
    $errors = @($lines | Where-Object { $_ -match '^SCRIPT ERROR|^ERROR: Failed to load script|Parse Error' })
    if ($errors.Count -gt 0) {
        $errors | Select-Object -First 15 | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        throw "$Label reported $($errors.Count) script error line(s)."
    }
    if ($code -ne 0) { throw "$Label failed (Godot exit code $code)." }
    return @{ Code = $code; Lines = $lines }
}

function Get-OutDir {
    $dir = Join-Path $script:Repo 'tools\out'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return $dir
}
