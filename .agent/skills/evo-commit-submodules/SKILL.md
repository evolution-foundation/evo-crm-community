---
name: evo-commit-submodules
description: Use when user asks to "commit changes", "push submodule", "salvar alterações nos forks", "commitar submodules", "push para fork", "mapear mudanças por repositório". Scans all submodules for modified/untracked files, groups by target fork remote, guides commit + push per repo, then updates the orchestrator pointer.
---

# Evo Commit Submodules

Maps modified/untracked files across all submodules, commits to their respective fork remotes (`Luizcc87/*`), then updates the orchestrator submodule pointer.

## Remote topology

Each submodule has three remotes:
- `origin` → `evolution-foundation/<repo>` (upstream source — **read only**)
- `upstream` → same as origin (alias used by evo-upstream-sync)
- `fork` → `Luizcc87/<repo>` (**push target for all local commits**)

The orchestrator (`evo-crm-community`) pushes to:
- `origin` → `Luizcc87/evo-crm-community`

---

## Step 1 — Scan all repos for changes

Run the scan script to get a full picture before touching anything:

```powershell
.\.agent\skills\evo-commit-submodules\scripts\scan-changes.ps1
```

The script prints a table:

| Repo | Branch | Modified | Untracked | Push remote |
|---|---|---|---|---|
| evo-ai-crm-community | main | 2 | 0 | fork → Luizcc87/... |
| evo-ai-frontend-community | main | 0 | 1 | fork → Luizcc87/... |
| (orchestrator) | docs/proxy-health-logs | 3 | 2 | origin → Luizcc87/... |

Submodules with zero changes are omitted from the table.

---

## Step 2 — Classify each change

For each file flagged, determine the correct commit prefix:

| Prefix | When |
|---|---|
| `custom:` | New feature / customization not in upstream |
| `fix:` | Bug fix (local or upstream-sourced) |
| `docs:` | Documentation only |
| `chore:` | Config, deps, tooling — no behavior change |
| `sync(upstream):` | Absorbing upstream tag (reserved for evo-upstream-sync) |

**Rule**: if the file is in `risk-registry.md` → also update `docs/CHANGES-LOCAL.md`.

---

## Step 3 — Commit per submodule

For each submodule with changes:

```bash
# 1. Confirm current branch
git -C <submodule> status

# 2. Stage files (prefer explicit paths over git add .)
git -C <submodule> add <file1> <file2>

# 3. Commit with correct prefix
git -C <submodule> commit -m "custom: <description>"

# 4. Push to fork (NEVER to origin/upstream)
git -C <submodule> push fork HEAD:<branch>
```

> **Branch rule**: push the current branch as-is. If on `main`, push to `fork/main`.
> Do NOT force-push unless explicitly requested.

---

## Step 4 — Commit orchestrator changes

After all submodule pushes, update the orchestrator:

```bash
# Stage submodule pointer updates + any root files changed
git add <submodule-dirs> <root-files>

# Commit
git commit -m "chore: update submodule pointers + <brief summary>"

# Push orchestrator to its fork
git push origin HEAD
```

Root files that commonly change alongside submodule work:
- `docker-compose.yml` — service config changes
- `.env.example` — new env vars
- `docs/CHANGES-LOCAL.md` — always when submodule was customized
- `AGENTS.md` / `CLAUDE.md` — rule updates

---

## Step 5 — Verify

```powershell
# Confirm nothing left staged or unstaged
git status
git submodule foreach 'git status --short'

# Confirm remote received the push
git -C <submodule> log --oneline fork/<branch> -3
```

---

## Safety rules

1. **Never push to `origin` or `upstream` inside a submodule** — those point to evolution-foundation.
2. **Never `git add .` blindly** — check `git status` first; `.env` files must never be committed.
3. **Never push if `check-releases.ps1` shows `🆕 YES`** — sync upstream first.
4. **Never amend a commit that was already pushed** — create a new one instead.
5. **If submodule is in detached HEAD**, checkout the correct branch before committing:
   ```bash
   git -C <submodule> checkout main   # or develop / custom/<branch>
   ```

---

## Agent Integration

| Agent | When to invoke evo-commit-submodules |
|---|---|
| **evo-dev** | After implementing a story — commit + push all touched submodules |
| **evo-dev-story** | End of story implementation — final commit step |
| **evo-master** | Menu option "Commit & Push changes" |
| **evo-upstream-sync** | After sync applied — commit resolved files before updating orchestrator |

**Do NOT invoke during**: active rebase, conflict resolution mid-flight, or when `evo-upstream-sync` is running.
