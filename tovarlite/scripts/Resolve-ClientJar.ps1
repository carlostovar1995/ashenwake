#Requires -Version 5.1
<#
.SYNOPSIS
  Resolves the newest client-*-shaded.jar in a directory.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Directory,
    [switch]$NameOnly
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $Directory)) { exit 1 }
$hit = Get-ChildItem -LiteralPath $Directory -Filter "client-*-shaded.jar" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
if (-not $hit) { exit 1 }
if ($NameOnly) { Write-Output $hit.Name } else { Write-Output $hit.FullName }
exit 0
