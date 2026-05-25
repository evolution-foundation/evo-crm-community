---
name: evo-upstream-sync
description: This skill should be used when the user asks to "sync upstream", "check new releases", "update submodules from upstream", "absorb upstream tag", "pull upstream changes", "verificar releases dos mantenedores", "sincronizar com upstream", or "atualizar submodules". Orchestrates the full upstream sync lifecycle for the Evo CRM Community monorepo.
---

# Evo Upstream Sync

Orchestrates upstream release analysis, conflict detection, merge planning, validation, and documentation for all submodules in the Evo CRM Community monorepo.

## When to Use

Invoke this skill whenever a new upstream release is available or the user wants to evaluate whether to absorb upstream changes into local forks.

---

## Step 1 — Check New Releases

For each submodule with a known upstream remote, fetch tags and identify new releases:

```powershell
# Submodules with upstream remotes (from docs/upstream-sync-analysis.md)
$submodules = @(
    @{ path="evo-ai-crm-community";         pinned="v1.0.0-rc4" },
    @{ path="evo-ai-frontend-community";    pinned="v1.0.0-rc4" },
    @{ path="evo-auth-service-community";   pinned="v1.0.0-rc4" },
    @{ path="evo-ai-core-service-community";pinned="v1.0.0-rc4" },
    @{ path="evo-ai-processor-community";   pinned="v1.0.0-rc4" },
    @{ path="evo-bot-runtime";              pinned="v1.0.0-rc3" },
    @{ path="evolution-go";                 pinned="v0.7.1"     },
    @{ path="evolution-api";                pinned="2.4.0-rc2"  },
    @{ path="evo-nexus";                    pinned="v0.33.0"    }
)

foreach ($sm in $submodules) {
    git -C $sm.path fetch upstream --tags 2>&1
    $latestTag = git -C $sm.path tag --sort=-v:refname | Select-Object -First 1
    Write-Host "$($sm.path): pinned=$($sm.pinned) latest=$latestTag"
}
```

Output should show which submodules have tags newer than the pinned version. Submodules without upstream remote can be skipped.

---

## Step 2 — Analyze Diff: Upstream Tag vs Local HEAD

For each submodule with a new upstream tag, run this analysis:

```bash
# Commits in upstream new tag NOT yet in local HEAD (what we're absorbing)
git -C <submodule> log --oneline HEAD..<new-tag>

# Local commits above pinned tag (what we must preserve)
git -C <submodule> log --oneline <pinned-tag>..HEAD

# Files changed by upstream new commits (potential conflicts)
git -C <submodule> diff HEAD..<new-tag> --name-only

# Files changed locally since pinned tag
git -C <submodule> diff <pinned-tag>..HEAD --name-only

# Intersection = real conflict candidates (run in PowerShell):
# $upstreamFiles = git -C <submodule> diff "HEAD..<new-tag>" --name-only
# $localFiles    = git -C <submodule> diff "<pinned>..<new-tag>" --name-only
# $localFiles | Where-Object { $upstreamFiles -contains $_ }
```

> **Note**: Do NOT rely on `--grep="^custom:"` to find local customizations — most commits
> do not use that prefix. Inspect `log <pinned>..HEAD` directly and read each commit.

**High-risk files to check always** (from `references/risk-registry.md`):
- `docker-compose.yml` (root) — highest conflict probability
- `docker-entrypoint.sh` (frontend) — runtime env var substitution + branding call
- `nginx.conf` (frontend) — CSP headers
- `.env.example` (root) — new required variables
- `db/migrate/*` in `evo-auth-service-community` and `evo-ai-crm-community`

**For each high-risk file, check the actual diff:**
```bash
git -C <submodule> diff HEAD..<new-tag> -- <file>
```

Produce a conflict risk table:

| Submodule | File | Local change | Upstream change | Risk |
|---|---|---|---|---|

---

## Step 3 — Determine Strategy per Submodule

Before generating the merge plan, classify each submodule:

```
A. LocalAhead=0, no known customizations, diverged history → RESET
B. LocalAhead=0, clean history (FF possible)              → FAST-FORWARD
C. LocalAhead>0, commits rebase cleanly                   → REBASE
D. LocalAhead>0, cherry-pick specific commits             → CHERRY-PICK
E. Both sides changed same files                          → MANUAL-MERGE
F. No new upstream tag                                    → SKIP
```

> **RESET** (strategy A) is common when the fork origin changed (EvolutionAPI → evolution-foundation).
> FF will fail with "refusing to merge unrelated histories" or "diverging branches". Use:
> ```bash
> git -C <submodule> branch -f main <new-tag>
> git -C <submodule> checkout main
> ```
> Only safe when `git diff HEAD..<new-tag> --name-only` shows no files unique to local HEAD.

Generate the merge plan document at `docs/sync/SYNC-PLAN-<date>.md`. Include:

1. **Tag being absorbed** per submodule
2. **Strategy** (RESET / FAST-FORWARD / REBASE / CHERRY-PICK / MANUAL-MERGE / SKIP)
3. **Pre-sync safety tags** — create `custom/pre-sync-<date>` before touching anything:

```powershell
$DATE = "20260525"
git -C evo-ai-crm-community tag "custom/pre-sync-$DATE"
git -C evo-ai-frontend-community tag "custom/pre-sync-$DATE"
git -C evo-auth-service-community tag "custom/pre-sync-$DATE"
git -C evo-ai-core-service-community tag "custom/pre-sync-$DATE"
git -C evo-ai-processor-community tag "custom/pre-sync-$DATE"
```

4. **Conflict resolutions** for each high-risk file
5. **db:migrate reminder** if new migrations exist
6. **Test checklist** (copy from `references/test-checklist.md`)

---

## Step 4 — Apply and Validate

### 4a. Apply merge strategy per submodule

**RESET** (no local customizations, diverged history):
```bash
git -C <submodule> branch -f main <new-tag>
git -C <submodule> checkout main
# Verify: git log --oneline -3
```

**FAST-FORWARD** (clean history, no local commits):
```bash
git -C <submodule> checkout main
git -C <submodule> merge <new-tag> --ff-only
```

**REBASE** (local commits, clean rebase expected):
```bash
git -C <submodule> checkout -b sync/<new-tag>
git -C <submodule> rebase <new-tag>
# Resolve conflicts if any, then:
git -C <submodule> rebase --continue
# Promote to main:
git -C <submodule> branch -f main sync/<new-tag>
git -C <submodule> checkout main
```

**CHERRY-PICK** (pick specific commits onto new tag):
```bash
git -C <submodule> checkout -b sync/<new-tag> <new-tag>
git -C <submodule> cherry-pick <commit-sha>
# Resolve conflicts, commit, repeat for each commit
```

**For the root orchestrator (docker-compose.yml, .env.example):**
```bash
git fetch upstream
git diff main..upstream/main -- docker-compose.yml .env.example .gitmodules
# Manual review, then merge
git merge upstream/main --no-ff -m "sync(upstream): merge vX.Y.Z"
```

### 4b. Build validation

```powershell
# Full rebuild after applying changes
docker compose build --no-cache

# If build passes, start services
docker compose up -d

# Wait for health checks
Start-Sleep -Seconds 30
docker compose ps
```

### 4c. Smoke tests

Run in order — stop at first failure:

1. **Auth service health**: `curl http://localhost:3001/health`
2. **CRM service health**: `curl http://localhost:3000/health`
3. **Frontend loads**: Open `http://localhost:5173` — no 502/blank screen
4. **Setup flow**: Navigate to `http://localhost:5173/setup` — wizard renders
5. **Login**: POST to `http://localhost:3001/auth/sign_in` with seed credentials
6. **Core service**: `curl http://localhost:5555/health`
7. **Processor**: `curl http://localhost:8000/health`

If any smoke test fails:
1. Check `docker compose logs <service>`
2. If unrecoverable, rollback: `git -C <submodule> checkout custom/pre-sync-<date>`

---

## Step 5 — Document in docs/CHANGES-LOCAL.md

After successful sync, append an entry to `docs/CHANGES-LOCAL.md` for each conflict resolved:

```markdown
## [<date>] Sync upstream <submodule> <old-tag> → <new-tag>

- **Arquivo**: `caminho/relativo/do/arquivo`
- **Motivo da customização local**: descrição do por que foi alterado
- **Conflito encontrado**: sim/não — descrição do conflito
- **Resolução**: como foi resolvido (keep-local / keep-upstream / manual merge)
- **Branch no fork**: `develop` ou `custom/<feature>`
- **Como reaplicar após próximo sync**: diff inline ou referência ao commit `custom/...`
```

Also update `docs/upstream-sync-analysis.md` — change the "Upstream tag" and "Commits locais" columns to reflect the new baseline.

---

## Step 6 — Post-Sync Commit Convention

All custom commits added after a sync **must** use the `custom:` prefix so they are
identifiable in the next sync cycle:

```
custom: <short description>

Examples:
  custom: proxy health/config endpoint for evolution_go instances
  custom: white-label runtime branding injection
```

This enables filtering in the next sync:
```bash
git log --oneline --grep="^custom:" <new-tag>..HEAD
```

Also update `references/risk-registry.md` whenever a new file is customized or a
customization is removed (absorbed by upstream).

---

## Agent Integration

This skill is invoked by other agents in the _evo cycle. Do not modify those agents —
this section documents the integration contract.

| Agent | When to invoke evo-upstream-sync |
|---|---|
| **evo-master** | Menu option "Sync Upstream" or when user reports new release |
| **evo-sm** | Sprint planning: run `check-releases.ps1` before closing backlog |
| **evo-dev** | Before implementing in a submodule: verify pinned is current |
| **evo-dev-story** | If story touches a high-risk file (see risk-registry): warn user |
| **evo-retrospective** | Include upstream sync questions in retro template |
| **evo-document-project** | After sync: re-scan submodules, update upstream-sync-analysis.md |

**Full integration guide**: `references/agent-integration.md`

### Gate rule for evo-dev

Before any commit to `evo-ai-crm-community`, `evo-ai-frontend-community`, or
`evo-auth-service-community`, check:

```powershell
.\.agent\skills\evo-upstream-sync\scripts\check-releases.ps1 -SkipFetch
```

If any submodule shows `🆕 YES` → **pause implementation** → run sync → resume story.

---

## Additional Resources

- **`references/risk-registry.md`** — per-file risk classification for all submodules
- **`references/agent-integration.md`** — when each evo-* agent should invoke this skill
- **`references/test-checklist.md`** — full smoke + regression test checklist
- **`scripts/check-releases.ps1`** — fetches all upstream tags, auto-adds missing remotes
- **`docs/upstream-sync-analysis.md`** — fork topology and current status
- **`docs/CHANGES-LOCAL.md`** — log of all local customizations and conflict resolutions
