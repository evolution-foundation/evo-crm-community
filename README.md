<p align="center">
  <a href="https://evolutionfoundation.com.br">
    <img src="./public/hover-evolution.png" alt="Evolution Foundation" />
  </a>
</p>

<h1 align="center">Evo CRM Community</h1>

<p align="center">
  Open-source, single-tenant AI-powered customer support platform — by Evolution Foundation.
</p>

<p align="center">
  <a href="https://github.com/evolution-foundation/evo-crm-community/releases/latest"><img src="https://img.shields.io/github/v/release/evolution-foundation/evo-crm-community?include_prereleases&label=version&color=00ffa7" alt="Latest version" /></a>
  <a href="https://opensource.org/licenses/Apache-2.0"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache 2.0" /></a>
  <a href="https://docs.evolutionfoundation.com.br"><img src="https://img.shields.io/badge/Docs-evolutionfoundation.com.br-00ffa7" alt="Documentation" /></a>
  <a href="https://evolutionfoundation.com.br/community"><img src="https://img.shields.io/badge/Community-Join%20us-white" alt="Community" /></a>
</p>

<p align="center">
  <a href="https://evolutionfoundation.com.br">Website</a> &middot;
  <a href="https://docs.evolutionfoundation.com.br">Documentation</a> &middot;
  <a href="https://evolutionfoundation.com.br/community">Community</a> &middot;
  <a href="mailto:suporte@evofoundation.com.br">Support</a>
</p>

---

## About

**Evo CRM Community** is the open-source edition of the Evo CRM platform — a complete suite for AI-assisted customer support. It brings together authentication, CRM, AI agents, agent processing, bot pipelines and a modern frontend into a unified, self-hostable stack.

This repository is the **monorepo entrypoint**: it aggregates all community services as Git submodules, giving you a single place to clone, update and orchestrate the entire platform.

For operational deployment and fork maintenance, see [README-OPERACOES.md](./README-OPERACOES.md).
Local customizations and notes follow the convention documented in [docs/local/README.md](./docs/local/README.md) and [deploy/local/README.md](./deploy/local/README.md).
Repository context lives in [CONTEXT.md](./CONTEXT.md) and agent guardrails live in [AGENTS.md](./AGENTS.md).

---

## Current Version

**`v1.0.0-rc2`** (latest) — see the [release notes](https://github.com/evolution-foundation/evo-crm-community/releases/tag/v1.0.0-rc2) for highlights, security advisories and known issues. Previous: [`v1.0.0-rc1`](https://github.com/evolution-foundation/evo-crm-community/releases/tag/v1.0.0-rc1).

The umbrella tag pins each Community submodule at its corresponding `v1.0.0-rc2` tag. Cloning with `--recurse-submodules` at this tag reproduces the full stack as released:

| Service | Git tag | Docker image | Release notes |
|---|---|---|---|
| [`evo-auth-service-community`](https://github.com/evolution-foundation/evo-auth-service-community) | `v1.0.0-rc2` | `evoapicloud/evo-auth-service-community:1.0.0-rc2` | [link](https://github.com/evolution-foundation/evo-auth-service-community/releases/tag/v1.0.0-rc2) |
| [`evo-ai-crm-community`](https://github.com/evolution-foundation/evo-ai-crm-community) | `v1.0.0-rc2` | `evoapicloud/evo-ai-crm-community:1.0.0-rc2` | [link](https://github.com/evolution-foundation/evo-ai-crm-community/releases/tag/v1.0.0-rc2) |
| [`evo-ai-frontend-community`](https://github.com/evolution-foundation/evo-ai-frontend-community) | `v1.0.0-rc2` | `evoapicloud/evo-ai-frontend-community:1.0.0-rc2` | [link](https://github.com/evolution-foundation/evo-ai-frontend-community/releases/tag/v1.0.0-rc2) |
| [`evo-ai-processor-community`](https://github.com/evolution-foundation/evo-ai-processor-community) | `v1.0.0-rc2` | `evoapicloud/evo-ai-processor-community:1.0.0-rc2` | [link](https://github.com/evolution-foundation/evo-ai-processor-community/releases/tag/v1.0.0-rc2) |
| [`evo-ai-core-service-community`](https://github.com/evolution-foundation/evo-ai-core-service-community) | `v1.0.0-rc2` | `evoapicloud/evo-ai-core-service-community:1.0.0-rc2` | [link](https://github.com/evolution-foundation/evo-ai-core-service-community/releases/tag/v1.0.0-rc2) |
| [`evo-bot-runtime`](https://github.com/evolution-foundation/evo-bot-runtime) | `v1.0.0-rc2` | `evoapicloud/evo-bot-runtime:1.0.0-rc2` | [link](https://github.com/evolution-foundation/evo-bot-runtime/releases/tag/v1.0.0-rc2) |
| `evo-crm-gateway` (built from this repo) | `v1.0.0-rc2` | `evoapicloud/evo-crm-gateway:1.0.0-rc2` | (see umbrella release) |

The following projects are **part of the broader Evolution Foundation ecosystem** but follow independent versioning:

| Service | Repository | Notes |
|---|---|---|
| [`evolution-api`](https://github.com/evolution-foundation/evolution-api) | WhatsApp messaging API (Node.js) | Independent versioning |
| [`evolution-go`](https://github.com/evolution-foundation/evolution-go) | WhatsApp messaging API (Go) | Independent versioning |
| [`evo-nexus`](https://github.com/evolution-foundation/evo-nexus) | Multi-agent operating layer | Independent versioning |

> **Note on tag naming**: the **git tag** has the `v` prefix (`v1.0.0-rc2`) following standard Git convention. The **Docker tag** drops the `v` (`1.0.0-rc2`) following SemVer / Docker Hub convention. `latest` on Docker Hub always tracks the most recent published tag.

```bash
# Source clone (pinned to the release):
git clone --recurse-submodules --branch v1.0.0-rc2 git@github.com:evolution-foundation/evo-crm-community.git

# Or pull pre-built images (compose files use :latest by default):
docker pull evoapicloud/evo-ai-crm-community:1.0.0-rc2
```

---

## Architecture

The Evo CRM Community platform is composed of 6 independent services:

| Service | Role | Stack | Default Port |
|---|---|---|---|
| [`evo-auth-service-community`](./evo-auth-service-community) | Authentication, RBAC, OAuth 2.0, token issuance | Ruby 3.4 / Rails 7.1 | `3001` |
| [`evo-ai-crm-community`](./evo-ai-crm-community) | Conversations, contacts, inboxes, messaging | Ruby 3.4 / Rails 7.1 | `3000` |
| [`evo-ai-frontend-community`](./evo-ai-frontend-community) | Web interface | React / TypeScript / Vite | `5173` |
| [`evo-ai-processor-community`](./evo-ai-processor-community) | AI agent execution, sessions, tools, MCP | Python 3.10 / FastAPI | `8000` |
| [`evo-ai-core-service-community`](./evo-ai-core-service-community) | Agent management, API keys, folders | Go / Gin | `5555` |
| [`evo-bot-runtime`](./evo-bot-runtime) | Bot pipeline execution, debouncing, dispatch | Go / Gin | `8080` |

### Design principles (Community Edition)

- **Single-tenant** — one account, no multi-tenancy overhead
- **No super-admin** — all configuration via seed data and environment variables
- **No billing / plans** — all limits removed, features unlocked by default
- **Role hierarchy**: `account_owner` and `agent` — no intermediate roles
- **Account resolution** via token — no `account-id` header required between services

### Companion services (independent versioning)

The following services are part of the Evolution Foundation ecosystem but are not pinned to the Evo CRM release tag:

| Service | Role |
|---|---|
| [`evolution-api`](./evolution-api) | WhatsApp messaging engine (Node.js) — used as a channel provider |
| [`evolution-go`](./evolution-go) | WhatsApp messaging engine (Go) — alternative high-performance provider |
| [`evo-nexus`](./evo-nexus) | Multi-agent operating layer — used internally by Evolution Foundation to coordinate development and operations |

---

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Git with submodule support

### 1. Clone with submodules

```bash
git clone --recurse-submodules git@github.com:evolution-foundation/evo-crm-community.git
cd evo-crm-community
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

### 2. Update all submodules to latest

```bash
git submodule update --remote --merge
```

### 3. Setup each service

Refer to each service's own README for environment configuration, setup and seed instructions:

- [evo-auth-service-community](https://github.com/evolution-foundation/evo-auth-service-community#readme)
- [evo-ai-crm-community](https://github.com/evolution-foundation/evo-ai-crm-community#readme)
- [evo-ai-frontend-community](https://github.com/evolution-foundation/evo-ai-frontend-community#readme)
- [evo-ai-processor-community](https://github.com/evolution-foundation/evo-ai-processor-community#readme)
- [evo-ai-core-service-community](https://github.com/evolution-foundation/evo-ai-core-service-community#readme)
- [evo-bot-runtime](https://github.com/evolution-foundation/evo-bot-runtime#readme)

> **Note:** `evo-auth-service-community` must be seeded before `evo-ai-crm-community` — the CRM depends on the user created by the auth seed.

> **Production deployment — required environment overrides**
>
> Before promoting any environment to production, the following variables in `.env.example` must be replaced with public URLs (the bundled `http://localhost:*` defaults exist for local development only):
>
> - **`BACKEND_URL`** — public URL of the CRM backend (e.g. `https://crm.example.com`). The CRM refuses to boot in production if this is missing or points at localhost.
> - **`FRONTEND_URL`** — public URL of the frontend (e.g. `https://app.example.com`). Used for OAuth redirects and channel webhook fallbacks.
>
> Leaving the localhost defaults in production results in webhook callbacks pointing at the container, broken OAuth redirects and silently failed external integrations.

For detailed setup instructions, visit the [full documentation](https://docs.evolutionfoundation.com.br).

---

## Service Dependencies

```
evo-ai-frontend-community
    └── evo-auth-service-community  (authentication)
    └── evo-ai-crm-community        (conversations, contacts)
    └── evo-ai-core-service-community (agents, tools, API keys)
    └── evo-ai-processor-community  (agent execution, sessions)
        └── evo-bot-runtime         (bot pipeline execution)
```

All inter-service communication uses Bearer token authentication. The token issued by `evo-auth-service-community` is forwarded between services — no additional headers required.

---

## Submodules Reference

### Evo CRM Community core (pinned to `v1.0.0-rc2`)

| Submodule | Repository |
|---|---|
| `evo-auth-service-community` | [evolution-foundation/evo-auth-service-community](https://github.com/evolution-foundation/evo-auth-service-community) |
| `evo-ai-crm-community` | [evolution-foundation/evo-ai-crm-community](https://github.com/evolution-foundation/evo-ai-crm-community) |
| `evo-ai-frontend-community` | [evolution-foundation/evo-ai-frontend-community](https://github.com/evolution-foundation/evo-ai-frontend-community) |
| `evo-ai-processor-community` | [evolution-foundation/evo-ai-processor-community](https://github.com/evolution-foundation/evo-ai-processor-community) |
| `evo-ai-core-service-community` | [evolution-foundation/evo-ai-core-service-community](https://github.com/evolution-foundation/evo-ai-core-service-community) |
| `evo-bot-runtime` | [evolution-foundation/evo-bot-runtime](https://github.com/evolution-foundation/evo-bot-runtime) |

### Companion projects (independent versioning)

| Submodule | Repository |
|---|---|
| `evolution-api` | [evolution-foundation/evolution-api](https://github.com/evolution-foundation/evolution-api) |
| `evolution-go` | [evolution-foundation/evolution-go](https://github.com/evolution-foundation/evolution-go) |
| `evo-nexus` | [evolution-foundation/evo-nexus](https://github.com/evolution-foundation/evo-nexus) |

---

## Documentation

| Resource | Link |
|---|---|
| Website | [evolutionfoundation.com.br](https://evolutionfoundation.com.br) |
| Documentation | [docs.evolutionfoundation.com.br](https://docs.evolutionfoundation.com.br) |
| Community | [evolutionfoundation.com.br/community](https://evolutionfoundation.com.br/community) |
| Changelog | [CHANGELOG.md](./CHANGELOG.md) |
| Contributing | [CONTRIBUTING.md](./CONTRIBUTING.md) |
| Security | [SECURITY.md](./SECURITY.md) |

---

## Hosting

Deploy Evo CRM Community with optimized infrastructure through our HostGator partnership:

[**Evo CRM VPS — HostGator**](https://evolution-api.com/vps-evo-crm)

---

## Contributing

Contributions are welcome! Please open an issue or pull request in the relevant submodule repository. See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

Join our [community](https://evolutionfoundation.com.br/community) to discuss ideas, ask questions and collaborate.

---

## Security

For security issues, **do not open a public issue**. Email **suporte@evofoundation.com.br** or use GitHub's private vulnerability reporting. See [SECURITY.md](./SECURITY.md) for details.

---

## License

Evo CRM Community is licensed under the Apache License 2.0, with additional brand-protection conditions (LOGO/copyright preservation and Usage Notification requirement). See [LICENSE](./LICENSE) for full details.

For licensing inquiries, contact **suporte@evofoundation.com.br**.

## Trademarks

"Evolution Foundation", "Evolution" and "Evo CRM" are trademarks of Evolution Foundation. See [TRADEMARKS.md](./TRADEMARKS.md) for the brand assets policy.

Third-party attributions are documented in [NOTICE](./NOTICE).

---

<p align="center">
  Made by <a href="https://evolutionfoundation.com.br">Evolution Foundation</a> · © 2026
</p>
