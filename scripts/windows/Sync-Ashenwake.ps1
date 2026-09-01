# Pull, optionally commit, and push Ashenwake to GitHub.
# No WSL. No Origin. Run from the desktop shortcut or this file.
$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location -LiteralPath $Repo

Write-Host "Syncing Ashenwake to GitHub..." -ForegroundColor Cyan
Write-Host "  $Repo"
Write-Host ""

function Assert-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is not on PATH. Install Git for Windows, then try again."
    }
}

Assert-Git

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if (-not $branch) { throw "Not a git repo: $Repo" }

Write-Host "==> Pulling origin/$branch"
git pull --rebase origin $branch
if ($LASTEXITCODE -ne 0) {
    git pull origin $branch
    if ($LASTEXITCODE -ne 0) { throw "git pull failed" }
}

$dirty = git status --porcelain
if ($dirty) {
    Write-Host "==> Committing local changes"
    git add -A
    $stamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    git commit -m "Sync Ashenwake $stamp"
    if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
} else {
    Write-Host "==> Working tree clean"
}

Write-Host "==> Pushing origin/$branch"
git push -u origin $branch
if ($LASTEXITCODE -ne 0) { throw "git push failed" }
git push origin --tags
if ($LASTEXITCODE -ne 0) {
    Write-Host "Tag push skipped or failed (ok if there are no new tags)."
}

Write-Host ""
Write-Host "Done. GitHub: https://github.com/carlostovar1995/ashenwake" -ForegroundColor Green
