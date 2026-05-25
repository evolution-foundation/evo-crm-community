#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Scan all submodules and the orchestrator for modified/untracked files.

.USAGE
    .\scan-changes.ps1
    .\scan-changes.ps1 -Verbose    # show file list per repo

.NOTES
    Push target is always the 'fork' remote inside submodules.
    Orchestrator pushes to 'origin' (which is Luizcc87/evo-crm-community).
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

$ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$submodules = @(
    "evo-ai-crm-community",
    "evo-ai-frontend-community",
    "evo-auth-service-community",
    "evo-ai-core-service-community",
    "evo-ai-processor-community",
    "evo-bot-runtime",
    "evolution-go",
    "evolution-api",
    "evo-nexus"
)

Write-Host ""
Write-Host "=== Evo CRM — Submodule Change Scanner ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Host ""

$results = @()

foreach ($sm in $submodules) {
    $smPath = Join-Path $ROOT $sm

    if (-not (Test-Path $smPath)) {
        continue
    }

    $statusLines = & git -C $smPath status --short 2>$null
    if (-not $statusLines) { continue }

    $modified   = @($statusLines | Where-Object { $_ -match '^\s?[MA]' -or $_ -match '^\s?M' })
    $untracked  = @($statusLines | Where-Object { $_ -match '^\?\?' })
    $deleted    = @($statusLines | Where-Object { $_ -match '^\s?D' })

    $branch = (& git -C $smPath rev-parse --abbrev-ref HEAD 2>$null).Trim()

    # Determine push remote
    $remotes = & git -C $smPath remote 2>$null
    $pushRemote = if ($remotes -contains "fork") { "fork" } else { "origin" }
    $pushUrl = (& git -C $smPath remote get-url $pushRemote 2>$null).Trim()

    $results += [PSCustomObject]@{
        Repo        = $sm
        Branch      = $branch
        Modified    = $modified.Count + $deleted.Count
        Untracked   = $untracked.Count
        PushRemote  = "$pushRemote → $pushUrl"
        StatusLines = $statusLines
    }
}

# Orchestrator itself
$orchStatus = & git -C $ROOT status --short 2>$null
if ($orchStatus) {
    $orchModified  = @($orchStatus | Where-Object { $_ -match '^\s?[MAD]' -or $_ -match '^ [MAD]' })
    $orchUntracked = @($orchStatus | Where-Object { $_ -match '^\?\?' })
    $orchBranch    = (& git -C $ROOT rev-parse --abbrev-ref HEAD 2>$null).Trim()
    $orchUrl       = (& git -C $ROOT remote get-url origin 2>$null).Trim()

    $results += [PSCustomObject]@{
        Repo        = "(orchestrator)"
        Branch      = $orchBranch
        Modified    = $orchModified.Count
        Untracked   = $orchUntracked.Count
        PushRemote  = "origin → $orchUrl"
        StatusLines = $orchStatus
    }
}

if (-not $results) {
    Write-Host "No changes found in any submodule or orchestrator." -ForegroundColor Green
    exit 0
}

$results | Select-Object Repo, Branch, Modified, Untracked, PushRemote | Format-Table -AutoSize

if ($Verbose) {
    foreach ($r in $results) {
        Write-Host "--- $($r.Repo) ---" -ForegroundColor Yellow
        $r.StatusLines | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
    }
}

# Warnings
$envFiles = $results | ForEach-Object { $_.StatusLines } | Where-Object { $_ -match '\.env$|\.env\.' -and $_ -notmatch '\.example' }
if ($envFiles) {
    Write-Host "WARNING: .env file(s) detected in changes — do NOT commit:" -ForegroundColor Red
    $envFiles | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
}

$detachedHeads = $results | Where-Object { $_.Branch -eq "HEAD" }
if ($detachedHeads) {
    Write-Host "WARNING: Detached HEAD in:" -ForegroundColor Red
    $detachedHeads | ForEach-Object { Write-Host "  $($_.Repo)" }
    Write-Host "  Fix: git -C <repo> checkout main (or develop)"
    Write-Host ""
}

Write-Host "Next step: run evo-commit-submodules skill to commit + push each repo." -ForegroundColor Cyan
