#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fetch upstream tags for all submodules and print release diff summary.

.USAGE
    .\check-releases.ps1
    .\check-releases.ps1 -SkipFetch   # use cached tags, no network

.NOTES
    Automatically adds missing 'upstream' remotes (evolution-foundation/*) before fetching.
    A missing remote previously caused silent false-negatives (reported pinned as latest).
#>

param(
    [switch]$SkipFetch
)

$ErrorActionPreference = "Stop"

$ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$submodules = @(
    @{ path="evo-ai-crm-community";          pinned="v1.0.0-rc4";  upstream="upstream"; upstreamUrl="https://github.com/evolution-foundation/evo-ai-crm-community.git" },
    @{ path="evo-ai-frontend-community";     pinned="v1.0.0-rc4";  upstream="upstream"; upstreamUrl="https://github.com/evolution-foundation/evo-ai-frontend-community.git" },
    @{ path="evo-auth-service-community";    pinned="v1.0.0-rc4";  upstream="upstream"; upstreamUrl="https://github.com/evolution-foundation/evo-auth-service-community.git" },
    @{ path="evo-ai-core-service-community"; pinned="v1.0.0-rc4";  upstream="upstream"; upstreamUrl="https://github.com/evolution-foundation/evo-ai-core-service-community.git" },
    @{ path="evo-ai-processor-community";    pinned="v1.0.0-rc4";  upstream="upstream"; upstreamUrl="https://github.com/evolution-foundation/evo-ai-processor-community.git" },
    @{ path="evo-bot-runtime";               pinned="v1.0.0-rc3";  upstream="upstream"; upstreamUrl="https://github.com/evolution-foundation/evo-bot-runtime.git" },
    @{ path="evolution-go";                  pinned="v0.7.1";      upstream="upstream"; upstreamUrl=$null },
    @{ path="evolution-api";                 pinned="2.4.0-rc2";   upstream="upstream"; upstreamUrl=$null },
    @{ path="evo-nexus";                     pinned="v0.33.0";     upstream="upstream"; upstreamUrl=$null }
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
            Submodule      = $sm.path
            Pinned         = $sm.pinned
            Latest         = "NOT FOUND"
            NewRelease     = "⚠️"
            LocalAhead     = "-"
            RemoteStatus   = "missing dir"
        }
        continue
    }

    # Ensure upstream remote exists before fetching
    $remoteStatus = "ok"
    $existingRemotes = & git -C $smPath remote 2>$null
    $hasUpstream = $existingRemotes -contains $sm.upstream

    if (-not $hasUpstream) {
        if ($sm.upstreamUrl) {
            try {
                & git -C $smPath remote add $sm.upstream $sm.upstreamUrl 2>&1 | Out-Null
                $remoteStatus = "added"
                Write-Host "  Added upstream remote for $($sm.path)" -ForegroundColor Yellow
            } catch {
                $remoteStatus = "add-failed"
                Write-Warning "Could not add upstream remote for $($sm.path): $_"
            }
        } else {
            $remoteStatus = "no-url"
            Write-Warning "$($sm.path): upstream remote missing and no URL configured — skipping fetch"
        }
    }

    if (-not $SkipFetch -and $remoteStatus -in @("ok","added")) {
        try {
            $fetchOut = & git -C $smPath fetch $sm.upstream --tags 2>&1
            # Surface new tags found
            $newTags = $fetchOut | Where-Object { $_ -match "\[new tag\]" }
            if ($newTags) {
                $newTags | ForEach-Object { Write-Host "  $($sm.path): $_" -ForegroundColor Green }
            }
        } catch {
            Write-Warning "fetch failed for $($sm.path): $_"
        }
    }

    $latestTag = & git -C $smPath tag --sort=-v:refname 2>$null | Select-Object -First 1
    if (-not $latestTag) { $latestTag = "(no tags)" }

    $isNew = ($latestTag -ne $sm.pinned) -and ($latestTag -ne "(no tags)")

    # Commits in upstream new tag not yet in local HEAD (missing upstream commits)
    $upstreamMissing = "-"
    if ($isNew) {
        try {
            $upstreamMissing = (& git -C $smPath rev-list --count "HEAD..$latestTag" 2>$null).Trim()
        } catch {}
    }

    # Local commits above pinned tag
    $localAhead = "-"
    try {
        $localAhead = (& git -C $smPath rev-list --count "$($sm.pinned)..HEAD" 2>$null).Trim()
    } catch {}

    $results += [PSCustomObject]@{
        Submodule      = $sm.path
        Pinned         = $sm.pinned
        Latest         = $latestTag
        NewRelease     = if ($isNew) { "🆕 YES" } else { "✅ no" }
        UpstreamMissing = $upstreamMissing
        LocalAhead     = $localAhead
        RemoteStatus   = $remoteStatus
    }
}

$results | Format-Table -AutoSize

$newReleases = $results | Where-Object { $_.NewRelease -like "*YES*" }
if ($newReleases) {
    Write-Host "ACTION REQUIRED: $($newReleases.Count) submodule(s) have new upstream releases." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "For each submodule with 🆕 YES, determine strategy:" -ForegroundColor Cyan
    Write-Host "  - LocalAhead=0 AND no known customizations → RESET (git branch -f main <tag> && git checkout main)"
    Write-Host "  - LocalAhead>0 with clean custom commits   → REBASE (git checkout -b sync/<tag> && git rebase <tag>)"
    Write-Host "  - LocalAhead>0 with mixed history          → CHERRY-PICK custom commits onto new tag"
    Write-Host "  - High-risk files overlap                  → MANUAL-MERGE"
    Write-Host ""
    Write-Host "Run evo-upstream-sync skill for full analysis and merge planning."
} else {
    Write-Host "All submodules are at latest upstream tag." -ForegroundColor Green
}

$noUrl = $results | Where-Object { $_.RemoteStatus -eq "no-url" }
if ($noUrl) {
    Write-Host ""
    Write-Host "WARNING: $($noUrl.Count) submodule(s) have no upstream URL configured in check-releases.ps1:" -ForegroundColor Red
    $noUrl | ForEach-Object { Write-Host "  - $($_.Submodule)" }
    Write-Host "Add upstreamUrl to the submodules array to enable auto-fetch."
}
