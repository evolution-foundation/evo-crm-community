# Migration Version Collision Guard

## What it checks

CRM (`evo-ai-crm-community`) and auth (`evo-auth-service-community`) are both Rails apps that share the same local Postgres database and the same `schema_migrations` table. When both apps have a migration with the same 14-char version prefix, whichever migrates second is **silently skipped** by Rails, corrupting the schema.

This guard fails when the two submodules have any overlapping version prefix in `db/migrate/`.

## How to run locally

From the umbrella root:

```sh
./scripts/check_migration_collision.sh
```

Exit codes: `0` no collision · `1` collision found · `2` unexpected repo state (missing dirs or no migration files — usually an un-initialized submodule).

### Reproducing CI behavior locally

CI (`actions/checkout@v4` with `submodules: recursive`) reads the submodule SHAs **pinned in the umbrella tree**, not the tip of each submodule branch. If your working tree has newer submodule commits than what the umbrella records, the script will disagree with CI. To reproduce CI exactly:

```sh
git submodule update --init --recursive   # forces checkout of the pinned SHAs
./scripts/check_migration_collision.sh
```

If this diverges from a run against your working tree, someone has an un-bumped submodule pointer somewhere and CI will be the source of truth.

## How to fix when it flags

Renumber the migration on the side that has **not** been applied to any live deployment yet (typically the one still confined to a feature branch — never one already run against a prod/staging DB). Bumping the timestamp by 1 second is enough:

```sh
cd evo-auth-service-community
git mv db/migrate/YYYYMMDDHHMMSS_foo.rb db/migrate/YYYYMMDDHHMMS(S+1)_foo.rb
```

The class name inside the file does not need to change — Rails resolves migrations by class name, not filename.

If `db/schema.rb` has `version:` equal to the renamed migration (i.e. it was the top migration), regenerate the schema:

```sh
RAILS_ENV=test bundle exec rails db:drop db:create db:migrate
git add db/schema.rb
```

## Recovery — historical collision `20260622120000`

If you migrated **auth first** on a DB before this guard existed, `schema_migrations` will contain `20260622120000` while the CRM `messages.source` column is missing. Symptom: message operations fail with `PG::UndefinedColumn: column messages.source does not exist` — the container may boot fine and pass health checks (the image ships a build-time schema cache that masks the missing column until real SQL hits it). Setups without a schema cache instead crashloop at boot with `Undeclared attribute type for enum 'source'`.

All commands run DB-side, from the deployment directory. Do NOT use `rails runner` inside the CRM container for this: in production it eager-loads the app, which loads the broken `Message` model and crashes with the very error you are trying to fix (`rails db:migrate` is safe — rake tasks skip eager loading). The `psql` client is always available in the `postgres` container.

Diagnose (0 rows = bitten; seeing `source` means the problem is something else — stop here):

```sh
docker compose exec postgres psql -U postgres -d evo_community -c \
  "SELECT column_name FROM information_schema.columns WHERE table_name='messages' AND column_name='source';"
```

Fix:

```sh
# 1. Remove the poisoned row that makes Rails skip the CRM migration
docker compose exec postgres psql -U postgres -d evo_community -c \
  "DELETE FROM schema_migrations WHERE version = '20260622120000';"

# 2. Re-run CRM migrations (works even while the app is crashlooping)
docker compose run --rm evo-crm bundle exec rails db:migrate

# 3. Bring the CRM back up
docker compose restart evo-crm evo-crm-sidekiq
```

Substitute `postgres` / `evo_community` if you customized `POSTGRES_USERNAME` / `POSTGRES_DATABASE` in `.env`. Run the diagnose step first — on a healthy DB, deleting the row and re-migrating would fail on the duplicate column.

From v1.0.0-rc7 on, the CRM migration `20260705120000_heal_messages_source_after_version_collision` performs this repair automatically on upgrade.

## Convention (recommended, not enforced)

To reduce future collisions, prefer these hour ranges for new migrations:

- CRM: `HH=12` (`YYYYMMDD120000_*`)
- auth: `HH=14` (`YYYYMMDD140000_*`)

The guard flags collisions regardless of hour — this is just a soft rule to make them less likely.

## Limitations

- The guard runs in CI **only on PRs to the umbrella** (`evo-crm-community`). PRs opened directly against `evo-ai-crm-community` or `evo-auth-service-community` are not blocked by this guard — the collision is caught when the submodule bump lands in an umbrella PR.
- Only Rails/Rails collisions are checked. Other services (evo-flow via TypeORM) use a separate migration table and are out of scope.

## Related

- EVO-1911 — this guard.
- EVO-1679 — DB-per-service split (deferred). Would eliminate the need for this guard.
