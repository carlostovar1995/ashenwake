#Requires -Version 5.1
<#
.SYNOPSIS
  Downloads the official RuneLite.jar launcher when TovarLite is missing it or it is older
  than the latest GitHub release. The official launcher then auto-updates the game client.

.DESCRIPTION
  Version compare contract (tested in distribution/tests/test_update_tovarlite.py):
    Compare-TovarLiteVersion "1.13.1" "1.12.37-SNAPSHOT"  ->  1
    Compare-TovarLiteVersion "2.8.0"  "2.7.7"             ->  1
    Compare-TovarLiteVersion "2.8.0"  "2.8.0"             ->  0
    Compare-TovarLiteVersion "1.12.37" "1.12.37-SNAPSHOT" ->  0

  Exit codes:
    0  launcher jar is present (already current, just updated, or refresh failed but a jar remains)
    1  no RuneLite.jar and the download failed
#>
[CmdletBinding()]
param(
    [string]$AppDir = $PSScriptRoot,
    [switch]$SkipDownload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-TovarLiteLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    try {
        $logDir = Join-Path $env:USERPROFILE ".runelite\logs"
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -LiteralPath (Join-Path $logDir "tovarlite-launcher.log") -Value $line
    } catch { }
}

function Get-TovarLiteVersionParts {
    param([string]$Version)
    if ([string]::IsNullOrWhiteSpace($Version)) { return @(0) }
    $v = $Version.Trim()
    if ($v.StartsWith("v") -or $v.StartsWith("V")) { $v = $v.Substring(1) }
    $cutDash = $v.IndexOf([char]"-")
    $cutPlus = $v.IndexOf([char]"+")
    $cut = -1
    if ($cutDash -ge 0) { $cut = $cutDash }
    if ($cutPlus -ge 0 -and ($cut -lt 0 -or $cutPlus -lt $cut)) { $cut = $cutPlus }
    if ($cut -ge 0) { $v = $v.Substring(0, $cut) }
    $parts = New-Object System.Collections.Generic.List[int]
    foreach ($piece in $v.Split(".")) {
        $digits = ($piece -replace "[^0-9]", "")
        if ([string]::IsNullOrEmpty($digits)) { $parts.Add(0) } else { $parts.Add([int]$digits) }
    }
    if ($parts.Count -eq 0) { $parts.Add(0) }
    return ,$parts.ToArray()
}

function Compare-TovarLiteVersion {
    param([string]$Left, [string]$Right)
    $a = @(Get-TovarLiteVersionParts $Left)
    $b = @(Get-TovarLiteVersionParts $Right)
    $n = [Math]::Max($a.Length, $b.Length)
    for ($i = 0; $i -lt $n; $i++) {
        $av = if ($i -lt $a.Length) { $a[$i] } else { 0 }
        $bv = if ($i -lt $b.Length) { $b[$i] } else { 0 }
        if ($av -gt $bv) { return 1 }
        if ($av -lt $bv) { return -1 }
    }
    return 0
}

function Get-TovarLiteWebJson {
    param([string]$Uri)
    $headers = @{
        "User-Agent" = "TovarLite-Portable (+https://github.com/carlostovar1995/runelite)"
        "Accept"     = "application/vnd.github+json"
    }
    return Invoke-RestMethod -Uri $Uri -Headers $headers -TimeoutSec 30
}

function Get-TovarLiteLatestLauncher {
    $release = Get-TovarLiteWebJson "https://api.github.com/repos/runelite/launcher/releases/latest"
    $tag = [string]$release.tag_name
    $asset = @($release.assets) | Where-Object { $_.name -eq "RuneLite.jar" } | Select-Object -First 1
    if (-not $asset) {
        throw "GitHub release $tag has no RuneLite.jar asset."
    }
    return [pscustomobject]@{
        Tag = $tag
        Url = [string]$asset.browser_download_url
        Size = [int64]$asset.size
    }
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

if ([string]::IsNullOrWhiteSpace($AppDir)) {
    $AppDir = $PSScriptRoot
}
$AppDir = [System.IO.Path]::GetFullPath($AppDir)
$jarPath = Join-Path $AppDir "RuneLite.jar"
$versionPath = Join-Path $AppDir "runelite-launcher-version.txt"
$tmpPath = Join-Path $AppDir "RuneLite.jar.tmp"

if ($env:TOVARLITE_SKIP_UPDATE -eq "1") {
    Write-TovarLiteLog "Skipping launcher jar refresh (TOVARLITE_SKIP_UPDATE=1)."
    if (Test-Path -LiteralPath $jarPath) { exit 0 }
    Write-TovarLiteLog "No RuneLite.jar present and updates are skipped."
    exit 1
}

$localVersion = ""
if (Test-Path -LiteralPath $versionPath) {
    $localVersion = (Get-Content -LiteralPath $versionPath -Raw -ErrorAction SilentlyContinue)
    if ($null -eq $localVersion) { $localVersion = "" }
    $localVersion = $localVersion.Trim()
}

if ($SkipDownload) {
    if (Test-Path -LiteralPath $jarPath) { exit 0 }
    exit 1
}

try {
    Write-TovarLiteLog "Checking GitHub for the latest official RuneLite launcher..."
    $latest = Get-TovarLiteLatestLauncher
    Write-TovarLiteLog ("Latest official launcher: {0}" -f $latest.Tag)

    $hasJar = Test-Path -LiteralPath $jarPath
    $needs = -not $hasJar
    if ($hasJar -and [string]::IsNullOrWhiteSpace($localVersion)) {
        $needs = $true
    } elseif ($hasJar -and (Compare-TovarLiteVersion $latest.Tag $localVersion) -gt 0) {
        $needs = $true
    }

    if (-not $needs) {
        Write-TovarLiteLog ("RuneLite.jar already current ({0})." -f $localVersion)
        exit 0
    }

    Write-TovarLiteLog ("Downloading {0} ({1} bytes)..." -f $latest.Url, $latest.Size)
    $headers = @{ "User-Agent" = "TovarLite-Portable (+https://github.com/carlostovar1995/runelite)" }
    Invoke-WebRequest -Uri $latest.Url -Headers $headers -OutFile $tmpPath -TimeoutSec 120 -UseBasicParsing

    $actual = (Get-Item -LiteralPath $tmpPath).Length
    if ($latest.Size -gt 0 -and $actual -ne $latest.Size) {
        throw "Downloaded size $actual does not match expected $($latest.Size)."
    }
    if ($actual -lt 100000) {
        throw "Downloaded RuneLite.jar is too small ($actual bytes)."
    }

    if (Test-Path -LiteralPath $jarPath) {
        Remove-Item -LiteralPath $jarPath -Force
    }
    Move-Item -LiteralPath $tmpPath -Destination $jarPath -Force
    [System.IO.File]::WriteAllText($versionPath, $latest.Tag.Trim() + [Environment]::NewLine)
    Write-TovarLiteLog ("Installed RuneLite.jar {0}." -f $latest.Tag)
    exit 0
} catch {
    Write-TovarLiteLog ("Launcher update failed: {0}" -f $_.Exception.Message)
    if (Test-Path -LiteralPath $tmpPath) {
        Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $jarPath) {
        Write-TovarLiteLog "Keeping the existing RuneLite.jar and continuing."
        exit 0
    }
    exit 1
}
