<#
.SYNOPSIS
  Ensures %LOCALAPPDATA%\RuneLite\settings.json clientArguments includes
  --insecure-write-credentials (Jagex Accounts dev flow). Idempotent.
  Does not read or write Jagex passwords.
#>
$ErrorActionPreference = "Stop"
$flag = "--insecure-write-credentials"
$path = Join-Path $env:LOCALAPPDATA "RuneLite\settings.json"

if (-not (Test-Path -LiteralPath $path)) {
    Write-Host "RuneLite launcher not found (install official launcher first): $path" -ForegroundColor DarkYellow
    exit 0
}

$raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
$j = $raw | ConvertFrom-Json

$list = New-Object System.Collections.ArrayList
if ($j.PSObject.Properties.Name -contains "clientArguments" -and $j.clientArguments) {
    foreach ($a in @($j.clientArguments)) {
        if ($null -ne $a -and "$a" -ne "") {
            [void]$list.Add([string]$a)
        }
    }
}

if ($list -notcontains $flag) {
    [void]$list.Add($flag)
    $out = @($list.ToArray())
    if ($j.PSObject.Properties.Name -contains "clientArguments") {
        $j.clientArguments = $out
    } else {
        $j | Add-Member -NotePropertyName clientArguments -NotePropertyValue $out -Force
    }
    $json = $j | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Added $flag to official RuneLite launcher." -ForegroundColor Green
} else {
    Write-Host "Official RuneLite launcher already includes $flag." -ForegroundColor DarkGray
}
exit 0
