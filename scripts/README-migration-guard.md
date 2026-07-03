# Migration Version Collision Guard

## What it checks

CRM (`evo-ai-crm-community`) and auth (`evo-auth-service-community`) are both Rails apps that share the same local Postgres database and the same `schema_migrations` table. When both apps have a migration with the same 14-char version prefix, whichever migrates second is **silently skipped** by Rails, corrupting the schema.

This guard fails when the two submodules have any overlapping version prefix in `db/migrate/`.

## How to run locally

From the umbrella root:

```sh
./scripts/check_migration_collision.sh
```

Exit codes: `0` no collision · `1` collision found · `2` unexpected repo state.

## How to fix when it flags

Renumber the offending migration in the repo with **fewer** migrations (auth, today) by adding 1 second to the timestamp:

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

If you migrated **auth first** on a local DB before this guard existed, `schema_migrations` will contain `20260622120000` while the CRM `messages.source` column is missing. Fix:

```sh
# Inside the CRM container:
bundle exec rails runner 'puts ActiveRecord::Base.connection.column_exists?(:messages, :source)'
# If false AND schema_migrations already contains 20260622120000:
psql "$DATABASE_URL" -c "DELETE FROM schema_migrations WHERE version = '20260622120000';"
bundle exec rails db:migrate
```

This is idempotent — safe to run whether or not `messages.source` already exists. Production is unaffected (never shared the DB).

## Convention (recommended, not enforced)

To reduce future collisions, prefer these hour ranges for new migrations:

- CRM: `HH=12` (`YYYYMMDD_120000_*`)
- auth: `HH=14` (`YYYYMMDD_140000_*`)

The guard flags collisions regardless of hour — this is just a soft rule to make them less likely.

## Limitations

- The guard runs in CI **only on PRs to the umbrella** (`evo-crm-community`). PRs opened directly against `evo-ai-crm-community` or `evo-auth-service-community` are not blocked by this guard — the collision is caught when the submodule bump lands in an umbrella PR.
- Only Rails/Rails collisions are checked. Other services (evo-flow via TypeORM) use a separate migration table and are out of scope.

## Related

- EVO-1911 — this guard.
- EVO-1679 — DB-per-service split (deferred). Would eliminate the need for this guard.
