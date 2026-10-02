#Requires -Version 5.1
# Scripted 5-player + boss scenario, headless, fixed seed. Writes
# tools/out/scenario_<boss>.json and checks the result digest is identical
# across -Repeat runs (default 2), so a mismatch means the build is not
# deterministic, not that a regression slipped in.
#   .\tools\baseline-scenario.ps1 [-Seconds 60] [-Seed 1337] [-Boss all|colossus|dawnwarden] [-Repeat 2] [-NoPhase2]
param(
    [int]$Seconds = 60,
    [int]$Seed = 1337,
    [ValidateSet('all', 'colossus', 'dawnwarden')][string]$Boss = 'all',
    [int]$Repeat = 2,
    [switch]$NoPhase2,
    [switch]$UpdateBaseline
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'baseline\common.ps1')

try {
    $godot = Find-Godot
    Assert-PinnedGodot $godot
    $phase2 = if ($NoPhase2) { 0 } else { 1 }
    $bosses = if ($Boss -eq 'all') { @('colossus', 'dawnwarden') } else { @($Boss) }
    $summary = @()
    $compared = @()
    $differs = $false
    foreach ($b in $bosses) {
        $digests = @()
        for ($i = 1; $i -le $Repeat; $i++) {
            $run = Invoke-GodotRun $godot @(
                '--headless', '--fixed-fps', '60',
                'res://tools/baseline/scenario.tscn',
                '--', "--seconds=$Seconds", "--seed=$Seed", "--boss=$b", "--phase2=$phase2"
            ) "Scenario $b, run $i of $Repeat"
            $line = $run.Lines | Where-Object { $_ -match '^BASELINE_SCENARIO_DIGEST ' } | Select-Object -Last 1
            if (-not $line) { throw 'Scenario finished without printing a digest.' }
            $digests += ($line -split ' ')[1]
        }
        if (($digests | Select-Object -Unique).Count -ne 1) {
            Write-Host "Digests differ between runs:`n$($digests -join "`n")" -ForegroundColor Red
            throw "Scenario ($b) is not deterministic; do not trust a comparison until this is fixed."
        }
        $summary += "$b digest $($digests[0])"
        $report = Join-Path (Get-OutDir) "scenario_$b.json"
        $reference = Join-Path $script:Repo "docs\baseline\scenario_$b.json"
        if ($UpdateBaseline) {
            New-Item -ItemType Directory -Force -Path (Split-Path $reference -Parent) | Out-Null
            Copy-Item -LiteralPath $report -Destination $reference -Force
            Write-Host "Baseline updated: $reference" -ForegroundColor Yellow
        }
        elseif (Test-Path -LiteralPath $reference) {
            $new = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
            $old = Get-Content -LiteralPath $reference -Raw | ConvertFrom-Json
            $same = ($new.meta.seed -eq $old.meta.seed) -and ($new.meta.sim_seconds -eq $old.meta.sim_seconds) -and
                ($new.meta.phase2_forced -eq $old.meta.phase2_forced) -and ($new.meta.godot -eq $old.meta.godot)
            if (-not $same) {
                $compared += "$b : settings differ from the reference, not compared"
            }
            elseif ($new.digest -eq $old.digest) {
                $compared += "$b : matches docs/baseline"
            }
            else {
                $compared += "$b : DIFFERS from docs/baseline (diff $report against $reference)"
                $differs = $true
            }
        }
    }
    Write-Host ''
    $summary | ForEach-Object { Write-Host "Scenario OK. $_" -ForegroundColor Green }
    Write-Host "Reports: $(Get-OutDir)\scenario_<boss>.json"
    foreach ($line in $compared) {
        $color = if ($line -match 'matches') { 'Green' } else { 'Red' }
        Write-Host $line -ForegroundColor $color
    }
    if ($differs) { exit 3 }
    exit 0
}
catch {
    Write-Host "baseline-scenario failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
