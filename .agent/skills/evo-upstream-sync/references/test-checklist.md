# Test Checklist — Post Upstream Sync

Run after every upstream sync. Stop at first failure — diagnose before continuing.

---

## Phase 1: Build

- [ ] `docker compose build --no-cache` completes without errors
- [ ] No image pull failures (check registry credentials if needed)
- [ ] No Go/Ruby/Python compile errors in build output

---

## Phase 2: Service Start

```powershell
docker compose up -d
Start-Sleep -Seconds 30
docker compose ps
```

- [ ] All containers show `Up` (not `Restarting` or `Exit`)
- [ ] No container crash-loops in `docker compose ps`

---

## Phase 3: Health Checks

```bash
curl -sf http://localhost:3001/health   # evo-auth-service
curl -sf http://localhost:3000/health   # evo-ai-crm-community
curl -sf http://localhost:5555/health   # evo-ai-core-service
curl -sf http://localhost:8000/health   # evo-ai-processor
curl -sf http://localhost:8080/health   # evo-bot-runtime (if applicable)
```

- [ ] Auth service returns 200
- [ ] CRM service returns 200
- [ ] Core service returns 200
- [ ] Processor returns 200

---

## Phase 4: Frontend

- [ ] `http://localhost:5173` loads without blank screen or 502
- [ ] Browser console: no critical JS errors (CSP violations, module load failures)
- [ ] `http://localhost:5173/setup` — setup wizard renders correctly

---

## Phase 5: Auth Flow

```bash
curl -X POST http://localhost:3001/auth/sign_in \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"password"}'
```

- [ ] Returns 200 with JWT token
- [ ] Token is usable for subsequent API calls

---

## Phase 6: Database

```bash
docker compose exec evo-crm rails db:migrate:status 2>&1 | grep down
docker compose exec evo-auth rails db:migrate:status 2>&1 | grep down
```

- [ ] No pending `down` migrations in CRM
- [ ] No pending `down` migrations in Auth
- [ ] New upstream migrations applied without error

---

## Phase 7: Regression Checks (for high-risk files)

### docker-entrypoint.sh (if changed)
- [ ] Frontend env vars are substituted correctly at runtime
- [ ] `VITE_WS_URL` fallback works when env var not set
- [ ] No placeholder warnings in container logs

### nginx.conf (if changed)
- [ ] CSP headers present: `Content-Security-Policy` in response headers
- [ ] No CSP violation errors for Cloudflare Insights
- [ ] Static assets load (no 404 for .js/.css)

### .env.example (if new vars added)
- [ ] Identify new required vars and add to `.env`
- [ ] Document new vars in `docs/CHANGES-LOCAL.md`

---

## Phase 8: Smoke Test — Core Feature

- [ ] Login via frontend UI works
- [ ] Dashboard loads after login
- [ ] At least one CRUD operation works (create a contact or conversation)

---

## Rollback Procedure

If any phase fails:

```bash
# Identify the pre-sync tag (created in Step 3 of the skill)
DATE=<YYYYMMDD>

# Rollback affected submodule
git -C <submodule> checkout custom/pre-sync-$DATE

# Rebuild
docker compose build --no-cache
docker compose up -d
```

Document the failure in `docs/sync/SYNC-PLAN-<date>.md` with error details.
