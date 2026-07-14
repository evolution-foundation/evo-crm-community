# Review environment (internal team tooling)

**Not** part of the self-host quick start — self-hosters use the root
`docker-compose.yml` (`make setup`). This stack exists to **test a card's PRs
running**: it pulls the published Docker Hub images and lets you pin one (or
several) services to a PR image while the rest run `:develop`.

## Image tags

| env var         | service                        | default   |
|-----------------|--------------------------------|-----------|
| `CRM_TAG`       | evo-ai-crm-community           | `develop` |
| `AUTH_TAG`      | evo-auth-service-community     | `develop` |
| `CORE_TAG`      | evo-ai-core-service-community  | `develop` |
| `PROCESSOR_TAG` | evo-ai-processor-community     | `develop` |
| `BOT_TAG`       | evo-bot-runtime                | `develop` |
| `FRONTEND_TAG`  | evo-ai-frontend-community      | `develop` |

PR images (`:pr-<N>`) are published by each service's CI on `pull_request`
(see the service repo's `.github/workflows/docker-publish.yml`).

## Quick use — `review.sh`

Pass one or more PR URLs; each pins its service to `:pr-<N>`, all other services
run `:develop`, then the stack comes up:

```sh
# one PR:
./internal/review/review.sh https://github.com/evolution-foundation/evo-ai-crm-community/pull/140
# a card with several PRs — just pass all the links:
./internal/review/review.sh <crm-pr-url> <auth-pr-url>
# dry-run (prints what it would do, boots nothing):
./internal/review/review.sh -n <pr-url>
# baseline (no args → every service on :develop):
./internal/review/review.sh
```

`review.sh` is the intended entry point. The raw `docker compose` commands below
are the plumbing it drives.

## Usage (plumbing)

Run from the repo root:

```sh
# whole develop line (baseline):
BACKEND_URL=http://host.docker.internal:3030 \
FRONTEND_URL=http://host.docker.internal:5173 \
  docker compose -f internal/review/docker-compose.yml up -d

# review CRM PR #140 against the rest of develop:
CRM_TAG=pr-140 \
BACKEND_URL=http://host.docker.internal:3030 \
FRONTEND_URL=http://host.docker.internal:5173 \
  docker compose -f internal/review/docker-compose.yml up -d

# tear down (and wipe volumes):
docker compose -f internal/review/docker-compose.yml down -v
```

`BACKEND_URL`/`FRONTEND_URL` must be **non-localhost** (the CRM refuses to boot
in production mode with localhost). On Mac/Windows `host.docker.internal` works;
on Linux use the host LAN IP or add an `extra_hosts` mapping.

> The card→PRs resolution (which PR maps to which `<SVC>_TAG`) is done by Claude
> via the Linear MCP — see the `review-card` / `evo-code-review` skills. This
> compose only consumes the tags. Tracking: **EVO-1998**.
