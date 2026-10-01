#Requires -Version 5.1
<#
.SYNOPSIS
  Compares the local TovarLite client / launcher against upstream RuneLite.

.DESCRIPTION
  Exit 0: current enough to launch (official launcher jar present, or shaded jar matches bootstrap).
  Exit 1: outdated.
  Exit 2: check failed (missing files / network).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppDir,
    [switch]$CheckUpstreamGit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

$AppDir = [System.IO.Path]::GetFullPath($AppDir)
$launcherJar = Join-Path $AppDir "RuneLite.jar"
if (Test-Path -LiteralPath $launcherJar) {
    Write-Host "Official RuneLite.jar is present; the launcher will refresh the client on start."
    exit 0
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $bootstrap = Invoke-RestMethod -Uri "https://static.runelite.net/bootstrap.json" -TimeoutSec 30 -Headers @{
        "User-Agent" = "TovarLite-Portable (+https://github.com/carlostovar1995/runelite)"
    }
} catch {
    Write-Host "Unable to read bootstrap.json: $($_.Exception.Message)"
    exit 2
}

$upstream = [string]$bootstrap.version
$local = ""
$pluginHub = Join-Path $AppDir "pluginhub-version.txt"
if (Test-Path -LiteralPath $pluginHub) {
    $local = (Get-Content -LiteralPath $pluginHub -Raw).Trim()
}
if (-not $local) {
    $shaded = Get-ChildItem -LiteralPath $AppDir -Filter "client-*-shaded.jar" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($shaded -and $shaded.Name -match "client-(.+)-shaded\.jar") {
        $local = $Matches[1]
    }
}
if (-not $local) {
    Write-Host "No local client version found."
    exit 2
}

Write-Host "Local client: $local"
Write-Host "Upstream client: $upstream"
if ((Compare-TovarLiteVersion $upstream $local) -gt 0) {
    Write-Host "Client is outdated."
    exit 1
}
Write-Host "Client matches upstream."
exit 0
