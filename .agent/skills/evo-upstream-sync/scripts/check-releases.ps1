#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fetch upstream tags for all submodules and print release diff summary.

.USAGE
    .\check-releases.ps1
    .\check-releases.ps1 -SkipFetch   # use cached tags, no network
#>

param(
    [switch]$SkipFetch
)

$ErrorActionPreference = "Stop"

$ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$submodules = @(
    @{ path="evo-ai-crm-community";          pinned="v1.0.0-rc4";  upstream="upstream" },
    @{ path="evo-ai-frontend-community";     pinned="v1.0.0-rc4";  upstream="upstream" },
    @{ path="evo-auth-service-community";    pinned="v1.0.0-rc4";  upstream="upstream" },
    @{ path="evo-ai-core-service-community"; pinned="v1.0.0-rc4";  upstream="upstream" },
    @{ path="evo-ai-processor-community";    pinned="v1.0.0-rc4";  upstream="upstream" },
    @{ path="evo-bot-runtime";               pinned="v1.0.0-rc3";  upstream="upstream" },
    @{ path="evolution-go";                  pinned="v0.7.1";      upstream="upstream" },
    @{ path="evolution-api";                 pinned="2.4.0-rc2";   upstream="upstream" },
    @{ path="evo-nexus";                     pinned="v0.33.0";     upstream="upstream" }
)

Write-Host ""
Write-Host "=== Evo CRM — Upstream Release Check ===" -ForegroundColor Cyan
Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Host ""

$results = @()

foreach ($sm in $submodules) {
    $smPath = Join-Path $ROOT $sm.path

    if (-not (Test-Path $smPath)) {
        $results += [PSCustomObject]@{
            Submodule   = $sm.path
            Pinned      = $sm.pinned
            Latest      = "NOT FOUND"
            NewRelease  = "⚠️"
            LocalAhead  = "-"
        }
        continue
    }

    if (-not $SkipFetch) {
        try {
            & git -C $smPath fetch $sm.upstream --tags --quiet 2>&1 | Out-Null
        } catch {
            Write-Warning "fetch failed for $($sm.path): $_"
        }
    }

    $latestTag = & git -C $smPath tag --sort=-v:refname 2>$null | Select-Object -First 1
    if (-not $latestTag) { $latestTag = "(no tags)" }

    # Check if latest > pinned (naive string compare — works for semver with consistent format)
    $isNew = ($latestTag -ne $sm.pinned) -and ($latestTag -ne "(no tags)")

    # Count local commits ahead of pinned tag
    $localAhead = "-"
    try {
        $counts = & git -C $smPath rev-list --count "$($sm.pinned)..HEAD" 2>$null
        $localAhead = $counts.Trim()
    } catch {}

    $results += [PSCustomObject]@{
        Submodule   = $sm.path
        Pinned      = $sm.pinned
        Latest      = $latestTag
        NewRelease  = if ($isNew) { "🆕 YES" } else { "✅ no" }
        LocalAhead  = $localAhead
    }
}

$results | Format-Table -AutoSize

$newReleases = $results | Where-Object { $_.NewRelease -like "*YES*" }
if ($newReleases) {
    Write-Host "ACTION REQUIRED: $($newReleases.Count) submodule(s) have new upstream releases." -ForegroundColor Yellow
    Write-Host "Run 'evo-upstream-sync' skill to proceed with analysis and merge planning."
} else {
    Write-Host "All submodules are at latest upstream tag." -ForegroundColor Green
}
