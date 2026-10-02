#Requires -Version 5.1
# Replays the scripted scenario in a real window at a fixed 60 fps timestep and
# saves a PNG at each fixed moment to tools/out/shots/<boss>_<moment>.png. Moments are defined in
# SHOT_MOMENTS in tools/baseline/scenario.gd. Old PNGs are cleared first.
#   .\tools\baseline-shots.ps1 [-Seed 1337] [-Boss all|colossus|dawnwarden]
param(
    [int]$Seed = 1337,
    [ValidateSet('all', 'colossus', 'dawnwarden')][string]$Boss = 'all'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'baseline\common.ps1')

try {
    $godot = Find-Godot
    Assert-PinnedGodot $godot
    $shots = Join-Path (Get-OutDir) 'shots'
    if (Test-Path -LiteralPath $shots) { Remove-Item -LiteralPath $shots -Recurse -Force }
    $bosses = if ($Boss -eq 'all') { @('colossus', 'dawnwarden') } else { @($Boss) }
    foreach ($b in $bosses) {
        Invoke-GodotRun $godot @(
            '--fixed-fps', '60',
            'res://tools/baseline/scenario.tscn',
            '--', '--shots', "--seed=$Seed", "--boss=$b"
        ) "Screenshot run ($b)" | Out-Null
    }
    $files = @(Get-ChildItem -LiteralPath $shots -Filter '*.png' -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { throw 'No screenshots were written.' }
    Write-Host ''
    Write-Host "Saved $($files.Count) screenshots to $shots" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "baseline-shots failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
