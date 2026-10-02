#Requires -Version 5.1
# Worst-case overlapping-VFX perf run (60 chase dummies, 5 scripted casters).
# Opens a real window: draw calls and GPU time are 0 under --headless.
# Writes tools/out/perf.json. Close other GPU-heavy apps first and run it a
# few times; frame time varies run to run, object counts should not.
#   .\tools\baseline-perf.ps1 [-Seconds 30] [-Warmup 6] [-Dummies 60]
param(
    [int]$Seconds = 30,
    [int]$Warmup = 6,
    [int]$Dummies = 60,
    [int]$Seed = 1337
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'baseline\common.ps1')

try {
    $godot = Find-Godot
    Assert-PinnedGodot $godot
    Invoke-GodotRun $godot @(
        'res://tools/baseline/perf.tscn',
        '--', "--seconds=$Seconds", "--warmup=$Warmup", "--dummies=$Dummies", "--seed=$Seed"
    ) 'Perf run' | Out-Null
    $report = Join-Path (Get-OutDir) 'perf.json'
    if (-not (Test-Path -LiteralPath $report)) { throw 'Perf run did not write perf.json.' }
    Write-Host ''
    Write-Host "Perf OK. Report: $report" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "baseline-perf failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
