#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-flight checks before docker-publish.sh.

.USAGE
    .\preflight.ps1
    .\preflight.ps1 -Image evo-ai-crm-community   # check only one submodule
#>

param(
    [string]$Image = ""
)

$ErrorActionPreference = "SilentlyContinue"
$ROOT = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))

$pass = $true

function Check($label, $ok, $detail = "") {
    if ($ok) {
        Write-Host "  [OK] $label" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $label$(if ($detail) { " — $detail" })" -ForegroundColor Red
        $script:pass = $false
    }
}

Write-Host ""
Write-Host "=== Evo Docker Publish — Pre-flight ===" -ForegroundColor Cyan
Write-Host ""

# 1. Docker daemon running
$dockerOk = $null -ne (docker info 2>$null)
Check "Docker daemon running" $dockerOk "run: docker desktop or dockerd"

# 2. buildx builder evo-multiarch exists and is active
$builders = docker buildx ls 2>$null
$builderOk = $builders -match "evo-multiarch"
Check "buildx builder 'evo-multiarch' exists" $builderOk "run: docker buildx create --name evo-multiarch --driver docker-container --bootstrap"

# 3. builder supports amd64 + arm64
$inspectOut = docker buildx inspect evo-multiarch 2>$null | Out-String
$amd64Ok = $inspectOut -match "linux/amd64"
$arm64Ok  = $inspectOut -match "linux/arm64"
Check "builder supports linux/amd64" $amd64Ok
Check "builder supports linux/arm64" $arm64Ok "may need QEMU: docker run --privileged --rm tonistiigi/binfmt --install all"

# 4. Docker Hub login for lc1868
$authFile = "$env:USERPROFILE\.docker\config.json"
if (-not $authFile) { $authFile = "~/.docker/config.json" }
$loginOk = (Get-Content $authFile -Raw 2>$null) -match "lc1868|index\.docker\.io"
Check "Docker Hub login active (lc1868)" $loginOk "run: docker login -u lc1868"

# 5. Submodules populated
$submodules = @(
    @{ name="evo-auth-service-community";    image="evo-auth-service-community" },
    @{ name="evo-ai-crm-community";          image="evo-ai-crm-community" },
    @{ name="evo-ai-frontend-community";     image="evo-ai-frontend-community" },
    @{ name="evo-ai-processor-community";    image="evo-ai-processor-community" },
    @{ name="evo-ai-core-service-community"; image="evo-ai-core-service-community" },
    @{ name="evo-bot-runtime";               image="evo-bot-runtime" },
    @{ name="evolution-go";                  image="evolution-go" }
)

Write-Host ""
Write-Host "  Submodules:" -ForegroundColor Cyan

foreach ($sm in $submodules) {
    if ($Image -and $sm.image -ne $Image) { continue }

    $smPath = Join-Path $ROOT $sm.name
    $populated = (Test-Path $smPath) -and ((Get-ChildItem $smPath -Force | Measure-Object).Count -gt 0)
    Check "  $($sm.name) populated" $populated "run: git submodule update --init $($sm.name)"

    if ($populated) {
        $modified = & git -C $smPath status --short 2>$null | Where-Object { $_ -match '^\s?[MAD]' -and $_ -notmatch '^\?\?' }
        $cleanOk = ($modified.Count -eq 0)
        Check "  $($sm.name) working tree clean" $cleanOk "$($modified.Count) file(s) modified — commit first with evo-commit-submodules"
    }
}

Write-Host ""
if ($pass) {
    Write-Host "All checks passed. Ready to run docker-publish.sh." -ForegroundColor Green
} else {
    Write-Host "Pre-flight FAILED. Fix issues above before publishing." -ForegroundColor Red
    exit 1
}
