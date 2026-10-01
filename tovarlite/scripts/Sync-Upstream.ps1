#Requires -Version 5.1
<#
.SYNOPSIS
  Compatibility wrapper. New launches use App\Update-TovarLite.ps1 instead of a Gradle rebuild.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptsDir = Split-Path -Parent $PSCommandPath
$distRoot = Split-Path -Parent $scriptsDir
$candidates = @(
    (Join-Path $distRoot "out\TovarLite-Portable\App"),
    (Join-Path $distRoot "portable\App")
)

$appDir = $null
$updater = $null
foreach ($dir in $candidates) {
    $ps1 = Join-Path $dir "Update-TovarLite.ps1"
    if (Test-Path -LiteralPath $ps1) {
        $appDir = $dir
        $updater = $ps1
        break
    }
}

if (-not $updater) {
    Write-Host "Update-TovarLite.ps1 not found. Copy distribution/portable/App into your TovarLite-Portable folder."
    exit 1
}

Write-Host "Refreshing official RuneLite launcher in $appDir"
& $updater -AppDir $appDir
exit $LASTEXITCODE
