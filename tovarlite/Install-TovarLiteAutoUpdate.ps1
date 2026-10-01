#Requires -Version 5.1
<#
.SYNOPSIS
  Copies TovarLite auto-update launcher scripts into an existing portable folder.
#>
[CmdletBinding()]
param(
    [string]$PortableRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$distRoot = Split-Path -Parent $PSCommandPath
$source = Join-Path $distRoot "portable"

if (-not $PortableRoot) {
    $defaultOut = Join-Path $distRoot "out\TovarLite-Portable"
    $runteliteDev = Join-Path $env:USERPROFILE "OneDrive\Desktop\Projects\Runtelite - Dev\distribution\out\TovarLite-Portable"
    if (Test-Path -LiteralPath (Join-Path $defaultOut "TovarLite.vbs")) {
        $PortableRoot = $defaultOut
    } elseif (Test-Path -LiteralPath (Join-Path $runteliteDev "TovarLite.vbs")) {
        $PortableRoot = $runteliteDev
    } elseif (Test-Path -LiteralPath ".\TovarLite.vbs") {
        $PortableRoot = (Resolve-Path ".").Path
    } else {
        throw "Pass -PortableRoot to your TovarLite-Portable folder (the one that contains TovarLite.vbs)."
    }
}

$PortableRoot = [System.IO.Path]::GetFullPath($PortableRoot)
$vbs = Join-Path $PortableRoot "TovarLite.vbs"
if (-not (Test-Path -LiteralPath $vbs)) {
    throw "Not a TovarLite portable folder (missing TovarLite.vbs): $PortableRoot"
}

$appDest = Join-Path $PortableRoot "App"
if (-not (Test-Path -LiteralPath $appDest)) {
    New-Item -ItemType Directory -Path $appDest -Force | Out-Null
}

$files = @(
    @{ From = "TovarLite.vbs"; To = (Join-Path $PortableRoot "TovarLite.vbs") }
    @{ From = "README.txt"; To = (Join-Path $PortableRoot "README.txt") }
    @{ From = "App\Play.bat"; To = (Join-Path $appDest "Play.bat") }
    @{ From = "App\Update-TovarLite.ps1"; To = (Join-Path $appDest "Update-TovarLite.ps1") }
    @{ From = "App\TovarLitePortableUI.ps1"; To = (Join-Path $appDest "TovarLitePortableUI.ps1") }
    @{ From = "App\Launch-TovarLite.vbs"; To = (Join-Path $appDest "Launch-TovarLite.vbs") }
    @{ From = "App\EnsureLauncherCredentialsFlag.ps1"; To = (Join-Path $appDest "EnsureLauncherCredentialsFlag.ps1") }
    @{ From = "App\Open-RuneLite-Configure.bat"; To = (Join-Path $appDest "Open-RuneLite-Configure.bat") }
    @{ From = "App\Re-import-settings.bat"; To = (Join-Path $appDest "Re-import-settings.bat") }
)

foreach ($item in $files) {
    $from = Join-Path $source $item.From
    if (-not (Test-Path -LiteralPath $from)) {
        throw "Missing source file: $from"
    }
    Copy-Item -LiteralPath $from -Destination $item.To -Force
    Write-Host "Updated $($item.To)"
}

Write-Host ""
Write-Host "TovarLite will auto-update on the next launch."
Write-Host "Start: $vbs"
exit 0
