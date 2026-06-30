# Evo CRM — API Gateway

Single-entrypoint nginx that dispatches incoming requests to the five
backend services by URL path. Packaged as
`evoapicloud/evo-crm-gateway` and meant to sit behind a TLS-terminating
reverse proxy (Traefik, Caddy, an ALB, etc.).

## Routing

Targets are declared as nginx variables at the top of the rendered config:

| Variable                  | Receives requests for                                |
|---------------------------|------------------------------------------------------|
| `$auth_service`           | `/oauth`, `/.well-known`, `/setup/*`, `/api/v1/auth`, `/api/v1/users`, `/api/v1/accounts`, `/platform/*`, `/api/v1/super_admin` (most) |
| `$crm_service`            | `/cable`, `/webhooks/*`, `/rails/active_storage`, `/api/v1/accounts/:id/webhooks`, `/api/v1/super_admin/{whitelabel,app_configs,upload,agent_bots,installation_configs,account_users}`, catch-all for unmatched `/api/v1/*` and `/` |
| `$evoai_service`          | `/api/v1/{agents,folders,mcp-servers,custom-mcp-servers,custom-tools}` |
| `$processor_service`      | `/api/v1/{chat,a2a,sessions,tools,clients}`, `/api/v1/agents/:id/integrations`, `/api/v1/integrations/:provider/callback`, `/api/v1/custom-mcp-servers/discover-tools`, `/health`, `/ready` |
| `$bot_runtime_service`    | `/api/v1/bot-runtime`                                |

Full path matrix is in [`default.conf.template`](./default.conf.template).

## Configurable upstreams

Each of the five variables above is rendered at container start from an
environment variable. The defaults below (`evo_auth`, `evo_crm`, …) match the
underscore service names used by **`docker-compose.prod-test.yaml`**, which is
the only stack that runs this gateway against the default hostnames.

Two stacks do **not** match these defaults:

- **`docker-compose.yml` (dev)** uses *hyphenated* service names (`evo-auth`,
  `evo-crm`, …) and ships **no gateway** at all — the browser hits each service
  on its published host port directly, so these upstreams are never used there.
- **`docker-compose.swarm.yaml`** uses `evocrm_`-prefixed names
  (`evocrm_auth`, …) and therefore overrides every `*_UPSTREAM` explicitly on
  the gateway service (see below).

| Env var                 | Default                 | Points to |
|-------------------------|-------------------------|-----------|
| `AUTH_UPSTREAM`         | `evo_auth:3001`         | `evo-auth-service-community`     |
| `CRM_UPSTREAM`          | `evo_crm:3000`          | `evo-ai-crm-community`           |
| `CORE_UPSTREAM`         | `evo_core:5555`         | `evo-ai-core-service-community`  |
| `PROCESSOR_UPSTREAM`    | `evo_processor:8000`    | `evo-ai-processor-community`     |
| `BOT_RUNTIME_UPSTREAM`  | `evo_bot_runtime:8080`  | `evo-bot-runtime`                |

Format is always `host:port`, no scheme. The gateway concatenates `http://`
at the front when rendering.

### When you need to override

If your deployment renames any of the backend services (e.g. applying a
`evocrm_` prefix, or shortening to `auth`/`crm`/…) the gateway cannot
resolve the default hostnames and every proxied request returns **502 Bad
Gateway**. Set the matching `*_UPSTREAM` env vars on the gateway service
to the service names you actually used.

### Example — prefixed service names

Stack uses `evocrm_auth`, `evocrm_crm`, `evocrm_core`, `evocrm_processor`,
`evocrm_bot_runtime`:

```yaml
services:
  evocrm_gateway:
    image: evoapicloud/evo-crm-gateway:latest
    environment:
      AUTH_UPSTREAM: evocrm_auth:3001
      CRM_UPSTREAM: evocrm_crm:3000
      CORE_UPSTREAM: evocrm_core:5555
      PROCESSOR_UPSTREAM: evocrm_processor:8000
      BOT_RUNTIME_UPSTREAM: evocrm_bot_runtime:8080
```

### Example — non-standard ports

If you expose the auth service on `4001` instead of `3001`:

```yaml
environment:
  AUTH_UPSTREAM: evo_auth:4001
```

## Verifying the rendered config

To confirm the variables were substituted correctly, inspect the rendered
file inside a running container:

```bash
docker exec <gateway-container> \
  grep -E "set \$(auth|crm|evoai|processor|bot_runtime)_service" \
  /etc/nginx/conf.d/default.conf
```

You should see the expected hostnames. If any line still contains
`${VARNAME}` literally, the env var was not set and envsubst skipped it.

## Build

```bash
docker build -t evo-crm-gateway:local nginx/
```

The image uses the stock `nginx:alpine` base and the image's built-in
template rendering — templates in `/etc/nginx/templates/*.template` are
processed by envsubst at container start. `NGINX_ENVSUBST_FILTER` is
restricted to the five `*_UPSTREAM` vars so the substitution pass does
not touch nginx's own runtime variables (`$host`, `$request_uri`, etc.).
