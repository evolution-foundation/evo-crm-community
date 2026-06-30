# Evo CRM Community — Troubleshooting

Common issues when bringing up the stack from a clean checkout, and how to fix
them. See [SETUP-GUIDE.md](./SETUP-GUIDE.md) for the full setup flow.

## The UI loads but every API/login call fails with "connection refused"

The frontend has the wrong API URLs. The `VITE_*` variables are read by the
browser, so they must point at the **host** ports published by
`docker-compose.yml`:

```
VITE_API_URL=http://localhost:3010
VITE_AUTH_API_URL=http://localhost:3011
VITE_WS_URL=http://localhost:3010
VITE_EVOAI_API_URL=http://localhost:5565
VITE_AGENT_PROCESSOR_URL=http://localhost:8011
```

The frontend image substitutes these into the built assets at **container
start** (no rebuild needed). After changing a value in `.env`, just recreate
the container so the entrypoint re-runs:

```bash
docker compose up -d --force-recreate evo-frontend
```

## WebSocket / live updates don't work

Make sure `VITE_WS_URL` is set (it must point at the CRM host port, `:3010` in
dev). If it's missing, the frontend falls back to the wrong port and the
WebSocket connection never opens. Recreate the frontend container after setting
it (`docker compose up -d --force-recreate evo-frontend`).

## `docker compose config` prints "variable is not set" warnings

A secret in `.env` contains an unescaped `$`. In `.env`, `$` starts a variable
reference. Escape it by doubling it (`$$`) — the shared secrets in
`.env.example` are already escaped this way.

## `evo-core` never becomes healthy

The dev stack pulls `evoapicloud/evo-ai-core-service-community:latest` from
Docker Hub. Confirm the image pulled and check its logs:

```bash
docker compose pull evo-core
docker compose logs evo-core
```

The Core needs Postgres reachable as host `postgres`; if it crashes on boot,
verify the `postgres` service is healthy (`docker compose ps`).

## Login wizard doesn't appear / "account already exists"

There is no pre-seeded login. The first user is created at
`http://localhost:5173/setup`.

> ⚠️ Do **not** run `make seed` to "fix" this on an existing install — it runs
> `db:schema:load`, which **drops and recreates every table** and wipes all
> your data. `make seed` is only for a fresh database (it's part of
> `make setup`).

If the wizard genuinely never ran (brand-new, empty database), seeding once is
fine:

```bash
make seed
```

If the database is in a bad state and you're OK losing all data, wipe and start
fresh:

```bash
make clean && make setup
```

## Ports already in use

The dev stack publishes non-default host ports to avoid collisions: CRM `3010`,
Auth `3011`, Core `5565`, Processor `8011`, Bot Runtime `8092`, Frontend
`5173`, Mailhog `18025`, plus Postgres `55434`, Redis `56381`. If one is taken,
stop the conflicting process or change the host side of the `ports:` mapping in
`docker-compose.yml`.

## Swarm: every request returns 502 Bad Gateway

The nginx gateway can't resolve the backend service names. The Swarm stack uses
`evocrm_`-prefixed names and sets the `*_UPSTREAM` env vars accordingly — if you
renamed services, update those vars on `evocrm_gateway`. See
[`nginx/README.md`](../nginx/README.md).

## Swarm: my `.env` changes have no effect

`docker-compose.swarm.yaml` does **not** read a `.env` file — all values are
inline. Edit the YAML directly. `.env.swarm.example` is only a reference
checklist of the values you need to fill in.
