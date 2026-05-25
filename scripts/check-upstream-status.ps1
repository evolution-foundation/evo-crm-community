param(
    [switch]$SkipFetch
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "=== $Title ==="
}

function Get-GitOutput {
    param(
        [string[]]$Arguments,
        [string]$WorkingDirectory
    )

    $result = & git -C $WorkingDirectory @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in $WorkingDirectory`n$result"
    }

    return @($result | ForEach-Object { $_.ToString() })
}

function Parse-CountPair {
    param([string]$Value)

    $parts = $Value.Trim() -split "\s+"
    if ($parts.Count -lt 2) {
        throw "Unexpected rev-list count format: $Value"
    }

    return $parts
}

function Get-BranchCandidate {
    param([string]$WorkingDirectory)

    $headBranch = (& git -C $WorkingDirectory rev-parse --abbrev-ref HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $headBranch -and $headBranch.Trim() -ne "HEAD") {
        return $headBranch.Trim()
    }

    $originHead = (& git -C $WorkingDirectory symbolic-ref --short refs/remotes/origin/HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $originHead) {
        return ($originHead -replace "^origin/", "").Trim()
    }

    foreach ($candidate in @("main", "master", "develop")) {
        & git -C $WorkingDirectory rev-parse --verify "origin/$candidate" *> $null
        if ($LASTEXITCODE -eq 0) {
            return $candidate
        }
    }

    return $null
}

function Show-RepoComparison {
    param(
        [string]$Label,
        [string]$WorkingDirectory,
        [string]$LocalRef,
        [string]$RemoteRef
    )

    $counts = Get-GitOutput -Arguments @("rev-list", "--left-right", "--count", "$LocalRef...$RemoteRef") -WorkingDirectory $WorkingDirectory
    $parts = Parse-CountPair -Value ($counts -join " ")

    Write-Host "$Label"
    Write-Host "  Local only : $($parts[0])"
    Write-Host "  Remote only: $($parts[1])"

    $incoming = Get-GitOutput -Arguments @("log", "--oneline", "$LocalRef..$RemoteRef", "-n", "5") -WorkingDirectory $WorkingDirectory
    if ($incoming.Count -gt 0 -and $incoming[0]) {
        Write-Host "  Incoming:"
        $incoming | ForEach-Object { Write-Host "    $_" }
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if (-not $SkipFetch) {
    Write-Section "Fetch"
    & git -C $repoRoot fetch --all --prune
    if ($LASTEXITCODE -ne 0) {
        throw "git fetch --all --prune failed"
    }

    & git -C $repoRoot submodule foreach --quiet "git fetch --all --prune || true"
}

Write-Section "Root Repository"
$status = Get-GitOutput -Arguments @("status", "--short", "--branch") -WorkingDirectory $repoRoot
$status | ForEach-Object { Write-Host $_ }

$remotes = Get-GitOutput -Arguments @("remote", "-v") -WorkingDirectory $repoRoot
$remotes | ForEach-Object { Write-Host $_ }

& git -C $repoRoot rev-parse --verify upstream/main *> $null
if ($LASTEXITCODE -eq 0) {
    Show-RepoComparison -Label "main vs upstream/main" -WorkingDirectory $repoRoot -LocalRef "main" -RemoteRef "upstream/main"
}

& git -C $repoRoot rev-parse --verify origin/main *> $null
if ($LASTEXITCODE -eq 0) {
    Show-RepoComparison -Label "main vs origin/main" -WorkingDirectory $repoRoot -LocalRef "main" -RemoteRef "origin/main"
}

Write-Section "Submodules"
$submodules = Get-GitOutput -Arguments @("config", "--file", ".gitmodules", "--get-regexp", "^submodule\..*\.(path|url)$") -WorkingDirectory $repoRoot
$submoduleMap = @{}

foreach ($line in $submodules) {
    if ($line -match "^submodule\.(.+?)\.(path|url)\s+(.+)$") {
        $name = $matches[1]
        $field = $matches[2]
        $value = $matches[3]

        if (-not $submoduleMap.ContainsKey($name)) {
            $submoduleMap[$name] = @{}
        }

        $submoduleMap[$name][$field] = $value
    }
}

foreach ($name in ($submoduleMap.Keys | Sort-Object)) {
    $relativePath = $submoduleMap[$name]["path"]
    $submodulePath = Join-Path $repoRoot $relativePath

    if (-not (Test-Path $submodulePath)) {
        Write-Host "$relativePath"
        Write-Host "  Missing on disk"
        continue
    }

    $branch = Get-BranchCandidate -WorkingDirectory $submodulePath
    $statusLines = Get-GitOutput -Arguments @("status", "--short", "--branch") -WorkingDirectory $submodulePath

    Write-Host $relativePath
    $statusLines | ForEach-Object { Write-Host "  $_" }

    if (-not $branch) {
        Write-Host "  Could not determine tracking branch"
        continue
    }

    & git -C $submodulePath rev-parse --verify "origin/$branch" *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Missing remote ref origin/$branch"
        continue
    }

    $counts = Get-GitOutput -Arguments @("rev-list", "--left-right", "--count", "HEAD...origin/$branch") -WorkingDirectory $submodulePath
    $parts = Parse-CountPair -Value ($counts -join " ")
    Write-Host "  Tracking    : origin/$branch"
    Write-Host "  Local only  : $($parts[0])"
    Write-Host "  Remote only : $($parts[1])"

    $incoming = Get-GitOutput -Arguments @("log", "--oneline", "HEAD..origin/$branch", "-n", "3") -WorkingDirectory $submodulePath
    if ($incoming.Count -gt 0 -and $incoming[0]) {
        Write-Host "  Incoming:"
        $incoming | ForEach-Object { Write-Host "    $_" }
    }
}
