# Code Review — EVO-1354

**Issue:** [EVO-1354 — Exportar customers/subscriptions/audit em CSV/JSON via link assinado](https://linear.app/evoai/issue/EVO-1354)
**PRs:**
- Rails: https://github.com/evolution-foundation/evo-enterprise-licensing-ruby/pull/26 (~2.2k LOC)
- Go: https://github.com/evolution-foundation/evo-ai-licensing/pull/10 (~2.1k LOC)

**Reviewer:** Claude (adversarial code review)
**Date:** 2026-06-01 (Round A) · 2026-06-01 (Round B) · 2026-06-01 (Round C)
**Status:** Round A — all 2 Critical + 5 High fixed (verified). Round B — 2 Medium + 1 Low new (all fixed in Round C). Round C — closes N1/N2/L3.

**Summary:**
- Round A: 2 Critical · 5 High · 4 Medium · 2 Low — Critical+High all resolved
- Round B: 0 Critical · 0 High · 2 Medium (new) · 1 Low (new) — all resolved in Round C
- Round C: closes N1, N2, L3 (Ruby-only)

---

## 🔴 CRITICAL

### C1 — Rails migration CHECK constraint contradicts the model's `EXPORT_TYPES`. No export will ever succeed.
- `db/migrate/20260529000001_create_evo_enterprise_licensing_exports.rb` → `EXPORT_TYPES = %w[customers subscriptions audit]` → DB-level `CHECK (export_type IN ('customers','subscriptions','audit'))`.
- `app/models/evo/enterprise/licensing/export.rb` → `EXPORT_TYPES = %w[agencies tenants audit]` and `ExportQueries.base_scope` only handles `agencies/tenants/audit`.
- AR validation accepts `agencies`/`tenants`; the INSERT then fails with `PG::CheckViolation`. AR rejects `customers`/`subscriptions` before any INSERT.
- Net effect: **only `audit` exports are persistable**; all `agencies`/`tenants` requests 500. Every integration test that POSTs `agencies`/`tenants` (`exports_spec.rb` AC1, AC8 happy path, AC9, AC10) fails on CI.
- The PR body claims tests pass on CI ("blocked locally by tzinfo, will run green") — false; they will not.
- **Fix:** migration must use `%w[agencies tenants audit]` (Rails owns those entities per the two-store decision in the Linear description).

### C2 — Rails `STORAGE_DRIVER=r2` crashes on boot.
- `app/services/evo/enterprise/licensing/export_storage.rb` — `build()` handles `"disk"`/`"s3"`/else; `r2` falls through to `raise ArgumentError, "unknown STORAGE_DRIVER"`.
- The PR body and EVO-1354 spec both list `r2` as supported (`STORAGE_DRIVER=s3|r2|disk`). The paired Go service does route `r2` to S3 with the R2 endpoint (`internal/storage/factory.go`).
- A prod deploy that follows the spec → operator sets `STORAGE_DRIVER=r2` → Rails service fails to boot.
- **Fix:** add an `"r2"` branch that constructs `S3` with the R2 endpoint template + `force_path_style: true`.

---

## 🟡 HIGH

### H1 — Go download endpoint extension-sniff is brittle and panics on short keys.
- `internal/export/handler.go` — `ext := key[len(key)-3:]; switch ext { case "csv": ...; case "son": ... }`.
- Matches `"son"` to detect `.json`. If `key` length < 3 (route accepts `{key}`), the slice panics → 500 (untrapped). If a future format has 3-char ext like `tsv`, it silently falls through to no `Content-Type`.
- **Fix:** use `filepath.Ext(key)` + an explicit map, and guard `len(key) >= 4` before slicing.

### H2 — Go `Service.writeAudit` silently swallows DB errors.
- `internal/export/service.go` — `if err := ... Create(row).Error; err != nil { _ = err }`. No log, no metric.
- AC7 / FR80 demand audit rows for every `export.requested|completed|failed`. If the audit insert fails (FK gone, RLS, disk-full Postgres), the operation is invisible — direct compliance gap.
- **Fix:** `slog.Error("export audit write failed", ...)` at minimum; surface to a counter.

### H3 — Go `Service.Status` calls `Presign(..., time.Until(*job.ExpiresAt))` with potentially negative TTL.
- `internal/export/service.go` — once `ExpiresAt` is in the past (which can occur in the 15-min cleanup grace window before sweep runs), `time.Until` returns a negative duration.
- AWS SDK v2 `PresignGetObject` with negative `Expires` produces an SDK error or a URL with `X-Amz-Expires` zero/garbage; on the disk driver, `Presign` builds a URL whose `expires` is in the past (already-expired link).
- The error from `Presign` is swallowed (`if err == nil { resp.FileURL = url }`), so the client gets `{status:"completed"}` with no `file_url` and no signal why.
- **Fix:** when `time.Until(*ExpiresAt) <= 0`, skip presigning and surface a distinct state (e.g., `expired: true`) — or fall through to the cleanup branch.

### H4 — Go service `cmd/server/main.go` reuses `adminToken` as the HMAC secret and mutates the process env.
- `cmd/server/main.go`: `if os.Getenv("EXPORT_HMAC_SECRET") == "" { os.Setenv("EXPORT_HMAC_SECRET", adminToken) }`.
- Two problems: (1) leaking the admin bearer compromises the HMAC and vice-versa; in prod deploys that forget `EXPORT_HMAC_SECRET`, a compromised signed URL gives an attacker material to compare against the admin token. (2) Mutating `os.Setenv` from `main()` is observable to every subsequent `os.Getenv` in the process.
- **Fix:** fail-fast if `EXPORT_HMAC_SECRET` is unset in prod; don't fall back to `adminToken`; if a dev default is required, scope it to a `DEV_MODE` check and don't write back to `os.Setenv`.

### H5 — `applyFilters` in Go uses string interpolation for the column name in the default branch.
- `internal/export/queries.go` — `q = q.Where(fmt.Sprintf("%s = ?", k), v)`.
- Not exploitable today (the `SanitizeFilters` allowlist gates `k` to known column names), but the pattern is fragile — any future maintainer who adds a filter key to the allowlist before adding the matching column on the table introduces a SQL-injectable surface. Two layers from a vuln, not one.
- **Fix:** map filter key → column name explicitly (like the Rails `FILTER_APPLIERS` lambda table) instead of interpolating.

---

## 🟠 MEDIUM

### M1 — Go `Service.writeAudit` hardcodes `Actor: job.RequestedBy` which is hardcoded `"admin"` upstream.
- `handler.go` enqueues with `RequestedBy: "admin"` for every call. AC7 / FR80 want `user_id` in the audit. With the global Bearer token there is no per-user identity in evo-ai-licensing today, but the audit row should at least carry the source IP / request ID. Right now every `export.requested` event is indistinguishable.

### M2 — Go audit filter allowlist is missing the spec-mandated `user_id` / `tenant_id`.
- Linear spec: audit filters = `event_type, user_id, occurred_after, occurred_before, tenant_id`.
- `internal/export/queries.go` allows `event_type, actor, occurred_after, occurred_before`. `user_id`/`tenant_id` silently dropped by `SanitizeFilters` — caller gets an unfiltered audit export they didn't ask for. AC6 partially fails.

### M3 — Go `applyFilters` uses `created_at` for `occurred_after`/`occurred_before` on the audit table.
- `internal/export/queries.go` — comment notes "Go audit table uses created_at, not occurred_at". For the licensing service this is essentially the same value, but the spec semantics ("event occurrence time") may diverge for backfilled rows. Document or rename the filter consistently across the two engines so a UI sending the same `occurred_after` value to both gets matching result sets.

### M4 — Rails RLS fallback is permissive (`OR current_setting('app.current_agency_id', true) IS NULL`).
- `db/migrate/20260529000001_create_evo_enterprise_licensing_exports.rb`. Same pattern as audit_log/tenants per migration comments. Worth noting that for the export table — which links agency_id to file_path and row_count — any Sidekiq job that forgets to bind `app.current_agency_id` sees every agency's rows. Pattern is documented; flagging for awareness.

---

## 🟢 LOW

### L1 — Go `WriteJSON` interleaves `json.NewEncoder` writes with manual `,` bytes
Produces output like `[\n{...}\n,{...}\n]` (extra newlines between commas). Valid JSON, but ugly for diffs and inconsistent with the comment "deterministic output".

### L2 — Rails `ExportSerializer` derives both `failed_at` and `completed_at` from the same `completed_at` column
Based on `status`. Works, but the column name lies. Either rename the column to `terminal_at` to match the doc-string explanation, or add separate timestamps. Documented trade-off, low priority.

---

## Cross-AC verification gaps not covered by tests

- **AC2 deviation** (Go subscription header `plan,price_cents` absent) — flagged by author in PR body; pending Davidson's decision. Confirm path before merge.
- **AC10 retention sweeper:** Rails sweep uses `expires_at + INTERVAL '15 minutes' <= now()`; Go sweep uses `expires_at < now - CleanupGrace`. Both correct, but their grace windows must stay aligned (15 min hardcoded in both). Worth a constant in a shared spec doc.

---

## Next steps

Awaiting decision on:

1. **Fix automatically** — patch C1, C2, H1–H5, M-tier across both repos (each commit/PR push requires explicit approval per CLAUDE.md standing rule).
2. **Action items** — post as `Review Follow-ups (AI)` comment block on EVO-1354 / both PRs.
3. **Drill-in** — examine a specific finding in depth.

Per CLAUDE.md: no commits, PR writes, or Linear writes will happen without explicit user authorization.

---

# Round B — 2026-06-01

Dev pushed fix commits `b43f62d0` (Rails) and `16c75ea2` (Go) addressing Round A Critical + High items.

## ✅ Verification of Round A fixes

| ID  | Fix                                                                                  | Verified |
| --- | ------------------------------------------------------------------------------------ | -------- |
| C1  | Rails migration `EXPORT_TYPES` → `%w[agencies tenants audit]` matches model          | ✅        |
| C2  | Rails `STORAGE_DRIVER=r2` branch added, S3 client + R2 endpoint + path-style         | ✅        |
| H1  | Go download uses `filepath.Ext` + map + `octet-stream` default; no slice panic       | ✅        |
| H2  | Go `writeAudit` uses `slog.ErrorContext` with event/job_id/export_type               | ✅        |
| H3  | Go `Service.Status` guards `ttl <= 0`; new `expired: true` field                     | ✅        |
| H4  | Go `EXPORT_HMAC_SECRET` required in non-dev mode; dev fallback gated on `--dev` flag | ✅        |
| H5  | Go `applyFilters` uses `equalityColumns` map; no more `fmt.Sprintf` interpolation    | ✅        |

---

## 🟠 NEW — MEDIUM

### N1 — Rails `aws-sdk-s3` moved to `add_development_dependency` is a **breaking deployment change**, and the lazy `require` has no `LoadError` rescue.

- `evo-enterprise-licensing.gemspec` — the `aws-sdk-s3` line dropped from runtime to dev-only.
- `export_storage.rb` — both `"s3"` and the new `"r2"` branches do `require "aws-sdk-s3"` lazily.
- **Two problems:**
  1. **Breaking for existing prod deployments.** Any host already running `STORAGE_DRIVER=s3` was getting `aws-sdk-s3` from the gem's runtime dep. After this PR, those hosts must add `aws-sdk-s3` to their own Gemfile before deploying — otherwise the `require` raises `LoadError` and boot/first-request crashes. No release-note flag for this.
  2. **`LoadError` surfaces as a cryptic 500.** `build()` doesn't rescue `LoadError` to produce an operator-friendly message. A missing gem currently bubbles up as `cannot load such file -- aws-sdk-s3`, leaving operators to guess.
- **Fix:** add a `rescue LoadError` around the `require` calls that re-raises with a clear message like `"aws-sdk-s3 gem is required when STORAGE_DRIVER=#{driver}; add `gem 'aws-sdk-s3'` to your Gemfile"`. Call this out in EVO-1354 release notes / Mintlify docs (3-language) so hosts add the bundler step before upgrading.

### N2 — Rails `security.role_denied` only emitted from the Pundit-rescue path, NOT from the filter-denial path.

- `render_export_denied` (Pundit rescue) now calls both `write_export_denied_audit` and `write_role_denied_audit` ✅.
- `render_export_denied_for_filter` (cross-agency `tenant_id` rejection) still only calls `write_export_denied_audit`.
- The new rescue-block comment says *"We also emit the generic `security.role_denied` event the base controller would have written, so SIEM tooling subscribed to that channel still sees the denial."* — but a cross-agency `tenant_id` probe is exactly the kind of forensic event SIEM would want, and that path bypasses the role-denied mirror.
- **Fix:** call `write_role_denied_audit(fake)` from `render_export_denied_for_filter` too, so both denial sources produce the same two-row pair.

---

## 🟢 NEW — LOW

### L3 — Rails `write_role_denied_audit` sets `subject_type: "Export"` for a role-gate denial.

The subject of a role check is the policy/action, not an `Export` instance (none exists yet — denial occurred before creation). Minor semantic nit; not load-bearing for any consumer, but inconsistent with the typical use of `subject_type`. Acceptable to defer.

---

## Still deferred (carried from Round A)

These remain open per the dev's stated scope split (Round A = Critical + High):

- **M1** — Go audit `Actor` hardcoded to `"admin"` (no per-user identity / request_id).
- **M2** — Go audit allowlist missing spec-mandated `user_id` / `tenant_id`.
- **M3** — Go `created_at` vs spec's `occurred_at` semantics on audit filters.
- **M4** — Rails RLS permissive fallback on the export table.
- **L1** — Go `WriteJSON` embedded newlines between commas.
- **L2** — Rails serializer derives `failed_at`/`completed_at` from one column.
- **AC2** — Go `subscriptions` header missing `plan`/`price_cents`; awaiting Davidson's call.
- **CI gate** — Rails RSpec suite has not been run on Linux CI yet (tzinfo blocker on Windows). C1 in particular needed test execution to catch — must be exercised before merge.

---

## Round B recommendation

**Round A fixes look correct and the new commits don't regress anything tested.** N1/N2/L3 are small and not merge-blockers individually, but **N1 has operator-facing impact** (breaking deploy + cryptic error) and should at minimum land in the CHANGELOG / Mintlify release notes for v1.0.0-rcN.

**Highest-leverage open item:** kick the Rails RSpec suite on the Linux CI runner so the migration↔model fix (C1) gets validated end-to-end. Right now we have a syntax-pass-only confirmation.

---

# Round C — 2026-06-01

Dev pushed fix commit `4353bdd` (Rails) addressing Round B items. Go side unchanged.

## ✅ Verification of Round B fixes

| ID  | Fix                                                                                                                | Verified |
| --- | ------------------------------------------------------------------------------------------------------------------ | -------- |
| N1  | `require_aws_sdk_s3!` rescues `LoadError` and re-raises with operator-friendly message naming gem + bundler step   | ✅        |
| N2  | `render_export_denied_for_filter` now calls both `write_export_denied_audit` and `write_role_denied_audit`         | ✅        |
| L3  | `write_role_denied_audit` sets `subject_type: nil` (no `Export` exists at role/filter denial); `write_export_denied_audit` keeps `"Export"` because that event IS about the attempted Export | ✅        |

## Scope decisions

- **N1 release-note:** dropped. No production operators on enterprise `STORAGE_DRIVER=s3` yet, so the "breaking deploy" framing is moot pre-1.0. The `rescue LoadError` was still applied because it improves UX for other devs on the team going forward.
- **Go side:** untouched this round. Round C is Ruby-only.

## Still deferred (carried from Round A/B)

- **M1** — Go audit `Actor` hardcoded to `"admin"`.
- **M2** — Go audit allowlist missing `user_id` / `tenant_id`.
- **M3** — Go `created_at` vs spec's `occurred_at` semantics on audit filters.
- **M4** — Rails RLS permissive fallback on the export table.
- **L1** — Go `WriteJSON` embedded newlines between commas.
- **L2** — Rails serializer derives `failed_at`/`completed_at` from one column.
- **AC2** — Go `subscriptions` header missing `plan`/`price_cents`; awaiting Davidson's call.
- **CI gate** — Rails RSpec suite on Linux CI (tzinfo blocker on Windows). C1 in particular still needs end-to-end execution before merge.

## Round C recommendation

All Critical + High + new Medium/Low findings from rounds A and B are now closed in code. The only remaining merge blockers are external: Davidson's decision on the subscriptions schema (AC2) and the Linux RSpec run that validates C1 end-to-end. Once those clear, the PR pair is mergeable.
