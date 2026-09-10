# Native Windows verification for the Ashenwake Godot project.
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    throw $Message
}

function Resolve-GodotExecutable([string]$Path) {
    if ($Path -match '(?i)\.exe$' -and $Path -notmatch '(?i)_console\.exe$') {
        $consolePath = Join-Path ([System.IO.Path]::GetDirectoryName($Path)) (
            [System.IO.Path]::GetFileNameWithoutExtension($Path) + "_console.exe"
        )
        if (Test-Path -LiteralPath $consolePath -PathType Leaf) {
            return $consolePath
        }
    }
    return $Path
}

function Find-Godot {
    foreach ($name in @("godot", "godot4")) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -ne $command) {
            return Resolve-GodotExecutable $command.Source
        }
    }
    $downloadNamedCommand = Get-Command "Godot*_console.exe", "Godot*.exe" -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "manager" } |
        Sort-Object @{ Expression = { if ($_.Name -match "_console\.exe$") { 0 } else { 1 } } }, Name |
        Select-Object -First 1
    if ($null -ne $downloadNamedCommand) {
        return Resolve-GodotExecutable $downloadNamedCommand.Source
    }

    $userHome = $env:USERPROFILE
    $searchRoots = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Godot"),
        (Join-Path $userHome "Downloads"),
        (Join-Path $userHome "Desktop"),
        (Join-Path $userHome "OneDrive\Desktop"),
        (Join-Path $env:LOCALAPPDATA "Programs"),
        "C:\Godot",
        "C:\Program Files\Godot",
        "C:\Program Files (x86)\Godot"
    )
    foreach ($root in $searchRoots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }
        $hit = Get-ChildItem -LiteralPath $root -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "manager" } |
            Sort-Object @{ Expression = { if ($_.Name -match "_console\.exe$") { 0 } else { 1 } } }, Name |
            Select-Object -First 1
        if ($null -ne $hit) {
            return Resolve-GodotExecutable $hit.FullName
        }
        $nested = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -Filter "Godot*.exe" -File -ErrorAction SilentlyContinue
            } |
            Where-Object { $_.Name -notmatch "manager" } |
            Sort-Object @{ Expression = { if ($_.Name -match "_console\.exe$") { 0 } else { 1 } } }, Name |
            Select-Object -First 1
        if ($null -ne $nested) {
            return Resolve-GodotExecutable $nested.FullName
        }
    }
    Fail "Godot was not found on PATH. Add the pinned Godot executable to PATH, then retry."
}

function Invoke-GodotStep([string]$Label, [string[]]$Arguments) {
    Write-Host "==> $Label" -ForegroundColor Cyan
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = @(& $script:Godot @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    foreach ($line in $output) {
        Write-Host $line
    }
    $outputText = ($output | Out-String)
    if ($exitCode -ne 0) {
        Fail "$Label failed (Godot exit code $exitCode)."
    }
    if ($outputText -match '(?m)^(SCRIPT ERROR:|ERROR: Failed to load script|ERROR: Failed to (create|instantiate) an autoload)') {
        Fail "$Label reported a script or autoload error."
    }
}

try {
    $Repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
    if (-not (Test-Path -LiteralPath (Join-Path $Repo "project.godot") -PathType Leaf)) {
        Fail "No project.godot found at repo root: $Repo"
    }

    $PinPath = Join-Path $Repo ".godot-version"
    if (-not (Test-Path -LiteralPath $PinPath -PathType Leaf)) {
        Fail "Missing Godot version pin: $PinPath"
    }

    $Pin = (Get-Content -LiteralPath $PinPath -Raw).Trim()
    if ($Pin -notmatch '^(?<version>\d+\.\d+\.\d+)-(?<channel>[A-Za-z0-9]+)$') {
        Fail "Invalid .godot-version '$Pin'. Expected an exact pin such as 4.7.2-stable."
    }
    $PinnedVersion = $Matches["version"]
    $PinnedChannel = $Matches["channel"].ToLowerInvariant()

    $script:Godot = Find-Godot
    $VersionOutput = (& $script:Godot --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        Fail "Could not query Godot version from '$script:Godot' (exit code $LASTEXITCODE)."
    }
    if ($VersionOutput -notmatch '(?<version>\d+\.\d+\.\d+)[\.\-](?<channel>stable|rc|beta|alpha|dev)\b') {
        Fail "Could not parse Godot version output: '$VersionOutput'"
    }
    $InstalledVersion = $Matches["version"]
    $InstalledChannel = $Matches["channel"].ToLowerInvariant()
    if ($InstalledVersion -ne $PinnedVersion -or $InstalledChannel -ne $PinnedChannel) {
        Fail "Godot version mismatch. Repo requires $Pin; '$script:Godot' reports '$VersionOutput'."
    }

    Write-Host "Verifying Ashenwake" -ForegroundColor Cyan
    Write-Host "  Repo:  $Repo"
    Write-Host "  Godot: $script:Godot ($VersionOutput)"
    Write-Host ""

    Invoke-GodotStep "Import resources" @("--headless", "--path", $Repo, "--import")
    Invoke-GodotStep "Check project scripts" @("--headless", "--path", $Repo, "--editor", "--quit")
    Invoke-GodotStep "Run verification checks" @("--headless", "--path", $Repo, "--script", "res://tools/ci_check.gd")
    Invoke-GodotStep "Run spawn smoke test" @("--headless", "--path", $Repo, "--script", "res://tools/smoke_test.gd")

    Write-Host ""
    Write-Host "Ashenwake verification passed." -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ""
    Write-Host "Ashenwake verification failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
