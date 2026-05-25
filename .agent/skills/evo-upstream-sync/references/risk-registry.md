# Risk Registry — Local Customizations per File

Last updated: 2026-05-25 (post rc4 sync)
Source: docs/CHANGES-LOCAL.md + sync experience

---

## Root Orchestrator (evo-crm-community)

| File | Local Change | Conflict Risk | Notes |
|---|---|---|---|
| `docker-compose.yml` | Images, ports, env vars, extra services | **HIGH** | Upstream modifies frequently |
| `.env.example` | Production vars added | **MEDIUM** | New upstream vars must be merged in |
| `scripts/docker-publish.sh` | New file — multi-arch build/push | **LOW** | Not in upstream |
| `docs/local/stack-swarm-vps.yaml` | New file — Portainer Swarm VPS | **NONE** | Local-only |
| `.github/dependabot.yml` | New file — submodule monitoring | **LOW** | Upstream does not have it |

---

## evo-ai-frontend-community

| File | Local Change | Conflict Risk | Notes |
|---|---|---|---|
| `docker-entrypoint.sh` | Calls `branding-entrypoint.sh` at end of file | **HIGH** | rc4 simplified this script significantly — the branding call line must survive every upstream merge |
| `nginx.conf` | CSP: removed cloudflareinsights.com (rc4 decision) | **MEDIUM** | Upstream may tighten/loosen CSP again; review diff on every sync |
| `docker-entrypoint.d/branding-entrypoint.sh` | New file — white-label runtime injection | **NONE** | New dir, not in upstream |
| `src/branding/config.ts` | New file — branding config with runtime placeholders | **NONE** | New dir, not in upstream |
| `src/components/AppLogo.tsx` | Consumes brandingConfig.logoUrl with fallback | **MEDIUM** | Upstream touches this component; verify on sync |
| `src/components/layout/components/Sidebar.tsx` | Uses brandingConfig for footer (appName, docsUrl) | **MEDIUM** | Upstream touches sidebar frequently |
| `src/components/channels/forms/whatsapp/ProxyPanel.tsx` | New file — proxy health/config UI | **NONE** | New file, not in upstream |
| `src/components/channels/forms/whatsapp/EvolutionGoForm.tsx` | Integrates ProxyPanel | **MEDIUM** | Upstream may update channel forms |
| `src/services/channels/evolutionGoService.ts` | Proxy API calls added | **MEDIUM** | Upstream may update service layer |
| `src/services/journeys/journeyService.ts` | Improved error messages (405, connection failure) | **LOW** | Small change, easy to reapply |
| `index.html` | Title + favicon use runtime placeholders | **LOW** | Patch mínimo de 2 linhas |

**Strategy on next sync:** cherry-pick `feat(white-label)` commit + `custom:` commits onto new tag. Verify `docker-entrypoint.sh` still calls `branding-entrypoint.sh` after merge.

---

## evo-ai-crm-community

| File | Local Change | Conflict Risk | Notes |
|---|---|---|---|
| `app/controllers/api/v1/evolution_go/proxy_controller.rb` | New file — proxy health/config endpoint | **NONE** | New file, not in upstream |
| `config/routes.rb` | `resource :proxy` added in evolution_go scope | **MEDIUM** | Upstream adds routes in rc releases; verify proxy route survives |

**Strategy on next sync:** RESET to new tag + cherry-pick `custom: proxy health/config endpoint` commit (1 commit, 2 files). Confirm `config/routes.rb` still has the proxy route after cherry-pick.

> **Lesson from rc4**: This submodule had 94 apparent "local commits" but they were all upstream
> commits from the old EvolutionAPI fork — no real local customizations except `sync_whatsapp_subscription`
> which was already absorbed by rc4. Always check `git log HEAD..<new-tag>` to see what's actually missing.

---

## evo-auth-service-community

| File | Local Change | Conflict Risk | Notes |
|---|---|---|---|
| `db/seeds.rb` | `require_relative 'seeds/white_label'` + `require_relative 'seeds/dev_admin'` | **MEDIUM** | Upstream modifies seeds in every release; verify requires survive |
| `db/seeds/white_label.rb` | New file — white-label seed (ACCOUNT_NAME, SUPPORT_EMAIL, etc.) | **LOW** | New file; check if upstream adds conflicting seed entries |
| `db/seeds/dev_admin.rb` | New file — auto-creates dev admin user | **NONE** | New file; skipped in production |
| `spec/db/seeds/white_label_spec.rb` | New file — specs for white_label seed | **NONE** | New file |

**Strategy on next sync:** REBASE (1 commit rebases cleanly — confirmed in rc4 sync).

> **MFA warning**: rc4 migration `20260518140000_invalidate_plaintext_backup_codes` prompts
> MFA re-setup for existing users. Document this in SYNC-PLAN when migrating.

---

## evo-ai-core-service-community

No local customizations. The apparent "local commit" (Merge PR #1 from EvolutionAPI/develop)
was already contained in the upstream rc4 tag.

**Strategy on next sync:** RESET to new tag (always safe).

---

## evo-ai-processor-community

No local customizations as of rc4. All local fixes (stage_name, link_product_to_pipeline_item,
knowledge_nexus_search, manage_conversation_labels, error handling) were absorbed by upstream
before rc4.

**Strategy on next sync:** RESET to new tag (always safe). Verify by running:
```bash
git diff HEAD..<new-tag> --name-only  # should show only docs/changelog
```

---

## evolution-go

| File | Local Change | Conflict Risk | Notes |
|---|---|---|---|
| `pkg/instance/*`, `pkg/routes/*`, `pkg/config/*` | Proxy health monitor + API endpoint | **MEDIUM** | Core service files; verify on upstream updates |

**Strategy on next sync:** REBASE or CHERRY-PICK custom commits onto new tag.

---

## Pure Upstream Submodules (no local changes as of rc4)

These can be RESET directly to any new upstream tag:

| Submodule | Pinned Tag | Strategy |
|---|---|---|
| evo-ai-core-service-community | v1.0.0-rc4 | RESET |
| evo-ai-processor-community | v1.0.0-rc4 | RESET |
| evo-bot-runtime | v1.0.0-rc3 | RESET when rc4 arrives |
| evolution-api | 2.4.0-rc2 | RESET |
| evo-nexus | v0.33.0 | RESET |

> **RESET procedure** (when history diverged at fork origin change):
> ```bash
> git -C <submodule> branch -f main <new-tag>
> git -C <submodule> checkout main
> ```
> FF (`merge --ff-only`) will fail with diverged histories — use RESET instead.

---

## Conflict Resolution Rules

1. **Keep local** — new files, white-label config, proxy features not in upstream
2. **Keep upstream** — security fixes, new features, bug fixes from upstream
3. **Manual merge** — both sides changed same section; resolve line by line
4. **Document always** — every resolution recorded in `docs/CHANGES-LOCAL.md`

## db:migrate Reminder

After any sync that adds new migrations, run:
```bash
docker compose exec evo-auth bundle exec rails db:migrate:status | grep down
docker compose exec evo-crm  bundle exec rails db:migrate:status | grep down
# If any 'down': run db:migrate
docker compose exec evo-auth bundle exec rails db:migrate
docker compose exec evo-crm  bundle exec rails db:migrate
```
