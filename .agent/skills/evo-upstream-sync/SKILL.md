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

For each submodule with a new upstream tag, identify which local-custom files conflict:

```bash
# List files changed between upstream tag and local HEAD
git -C <submodule> diff <upstream-new-tag>..HEAD --name-only

# Count commits ahead/behind
git -C <submodule> rev-list --left-right --count <upstream-new-tag>...HEAD

# Show local commits with custom: prefix (customizations)
git -C <submodule> log --oneline --grep="^custom:" <upstream-new-tag>..HEAD

# Show diff for high-risk files specifically
git -C <submodule> diff <upstream-new-tag>..HEAD -- docker-compose.yml docker-entrypoint.sh nginx.conf
```

**High-risk files to check always** (from `references/risk-registry.md`):
- `docker-compose.yml` (root) — highest conflict probability
- `docker-entrypoint.sh` (frontend) — runtime env var substitution logic
- `nginx.conf` (frontend) — CSP headers
- `.env.example` (root) — new required variables
- Any migration file in `evo-auth-service-community/db/migrate/`

Produce a conflict risk table:

| Submodule | File | Local change | Upstream change | Risk |
|---|---|---|---|---|

---

## Step 3 — Generate Merge Plan

Based on the conflict analysis, create a merge plan document at `docs/sync/SYNC-PLAN-<date>.md`.

The plan must include:

1. **Tag being absorbed** — e.g. `v1.0.0-rc3` for each submodule
2. **Strategy per submodule**:
   - `SKIP` — no new upstream tag, no action
   - `FAST-FORWARD` — no local commits, just update pointer
   - `REBASE` — local commits exist, rebase on new tag (preferred for small sets)
   - `CHERRY-PICK` — cherry-pick custom: commits onto new upstream tag
   - `MANUAL-MERGE` — high conflict, requires careful line-by-line review
3. **Pre-sync safety tags** — create `custom/pre-sync-<date>` on each modified submodule before touching anything
4. **Test checklist** (copy from `references/test-checklist.md`)

Template command for pre-sync tags:

```bash
DATE=$(date +%Y%m%d)
git -C evo-ai-crm-community tag custom/pre-sync-$DATE
git -C evo-ai-frontend-community tag custom/pre-sync-$DATE
git -C evo-auth-service-community tag custom/pre-sync-$DATE
```

---

## Step 4 — Apply and Validate

### 4a. Apply merge strategy per submodule

**For FAST-FORWARD submodules:**
```bash
git -C <submodule> checkout main
git -C <submodule> merge upstream/<new-tag> --ff-only
```

**For REBASE/CHERRY-PICK submodules:**
```bash
# Create sync branch
git -C <submodule> checkout -b sync/<new-tag>
git -C <submodule> rebase <new-tag>
# Resolve conflicts, then:
git -C <submodule> rebase --continue
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

## Additional Resources

- **`references/risk-registry.md`** — per-file risk classification for all submodules
- **`references/test-checklist.md`** — full smoke + regression test checklist
- **`scripts/check-releases.ps1`** — fetches all upstream tags and prints diff summary
- **`docs/upstream-sync-analysis.md`** — fork topology and current status
- **`docs/CHANGES-LOCAL.md`** — log of all local customizations
- **`scripts/check-upstream-status.ps1`** — existing upstream status script
