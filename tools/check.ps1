#Requires -Version 5.1
# Project checks: gdformat, gdlint, headless import + boot, GdUnit4.
# Prints only failures (first $MaxLines lines per step) plus a one-line summary.
# Exit code is non-zero if any step fails.
param([int]$MaxLines = 15, [int]$GodotTimeoutSec = 300)

$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

if (-not $env:GODOT -or -not (Test-Path $env:GODOT)) {
    Write-Output 'check: FAILED (GODOT env var is unset or not a Godot executable)'
    exit 1
}

$dirs = @('scripts', 'tools', 'tests') | Where-Object { Test-Path $_ }
$failed = @()

function Add-Failure([string]$Name, [string[]]$Lines) {
    $script:failed += $Name
    Write-Output "--- $Name ---"
    $Lines | Select-Object -First $MaxLines
    if ($Lines.Count -gt $MaxLines) { Write-Output "... $($Lines.Count - $MaxLines) more lines" }
}

# Runs a command line through cmd so stderr is plain text (no PS 5.1 NativeCommandError wrapping).
function Invoke-Native([string]$CommandLine) {
    $lines = & cmd.exe /d /c "$CommandLine 2>&1"
    return @{ Code = $LASTEXITCODE; Lines = @($lines | ForEach-Object { "$_" }) }
}

# Godot runs with a hard timeout: a hung headless Godot must not hang the check.
function Invoke-Godot([string[]]$GodotArgs) {
    $out = [IO.Path]::GetTempFileName()
    $err = [IO.Path]::GetTempFileName()
    $p = Start-Process $env:GODOT -ArgumentList $GodotArgs -WorkingDirectory $root -PassThru -NoNewWindow `
        -RedirectStandardOutput $out -RedirectStandardError $err
    $null = $p.Handle  # keep the handle so ExitCode is populated
    if (-not $p.WaitForExit($GodotTimeoutSec * 1000)) {
        & taskkill.exe /PID $p.Id /T /F | Out-Null
        $lines = @("timed out after ${GodotTimeoutSec}s")
        $code = 124
    } else {
        $p.WaitForExit()
        $code = $p.ExitCode
        $lines = @(Get-Content $out, $err | ForEach-Object { "$_" })
    }
    Remove-Item -LiteralPath $out -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $err -ErrorAction SilentlyContinue
    return @{ Code = $code; Lines = $lines }
}

$d = $dirs -join ' '

$r = Invoke-Native "gdformat --check $d"
if ($r.Code -ne 0) { Add-Failure 'gdformat' $r.Lines }

$r = Invoke-Native "gdlint $d"
if ($r.Code -ne 0) { Add-Failure 'gdlint' $r.Lines }

# Refresh the import / global class cache so addon class_names resolve.
$r = Invoke-Godot @('--headless', '--path', '.', '--editor', '--quit')
if ($r.Code -ne 0) { Add-Failure 'import' $r.Lines }

$r = Invoke-Godot @('--headless', '--path', '.', '--quit-after', '120')
$errs = @($r.Lines | Where-Object { $_ -match 'SCRIPT ERROR|^ERROR:|Parse Error' })
if ($r.Code -ne 0 -or $errs.Count) { Add-Failure 'boot' $(if ($errs.Count) { $errs } else { $r.Lines }) }

$r = Invoke-Godot @('--headless', '--path', '.', '-s', '-d', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '--add', 'res://tests', '--ignoreHeadlessMode')
if ($r.Code -ne 0) {
    $hits = @($r.Lines | Where-Object { $_ -match 'FAILED|ERROR|Overall Summary' } | Select-Object -Unique)
    Add-Failure 'gdunit4' $(if ($hits.Count) { $hits } else { $r.Lines })
}

if ($failed.Count) {
    Write-Output "check: FAILED ($($failed -join ', '))"
    exit 1
}
Write-Output 'check: OK (gdformat, gdlint, import, boot, gdunit4)'
exit 0
