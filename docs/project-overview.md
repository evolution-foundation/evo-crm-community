# Evo CRM Community — Visão Geral do Projeto

**Data de geração:** 2026-05-22  
**Modo de scan:** Deep Scan  
**Gerado por:** document-project workflow (Mary, Analyst Agent)

---

## O que é este projeto

Monorepo-orquestrador do **Evo CRM Community** — CRM de tenant único, open-source, com capacidades de agentes de IA e integração nativa com WhatsApp (via Evolution API). Gerencia 6 subserviços de aplicação + 4 submodules companheiros via `docker-compose.yml` e `Makefile`.

O projeto é um **fork/overlay** do repositório oficial `EvolutionAPI/evo-crm-community`. Os submodules de serviço têm forks próprios em `Luizcc87/<nome>` e são modificados separadamente do upstream.

---

## Repositórios e remotes

| Papel | Upstream oficial | Fork do Luiz |
|---|---|---|
| Orquestrador (este repo) | `EvolutionAPI/evo-crm-community` | `Luizcc87/evo-crm-community` |
| evo-auth | `evolution-foundation/evo-auth-service-community` | `Luizcc87/evo-auth-service-community` |
| evo-crm (backend) | `evolution-foundation/evo-ai-crm-community` | `Luizcc87/evo-ai-crm-community` |
| evo-frontend | `evolution-foundation/evo-ai-frontend-community` | `Luizcc87/evo-ai-frontend-community` |
| evo-processor | `evolution-foundation/evo-ai-processor-community` | `Luizcc87/evo-ai-processor-community` |
| evo-core | `evolution-foundation/evo-ai-core-service-community` | `Luizcc87/evo-ai-core-service-community` |
| evo-bot-runtime | `evolution-foundation/evo-bot-runtime` | `Luizcc87/evo-bot-runtime` |

---

## Serviços e portas

| Submodule | Stack | Porta |
|---|---|---|
| `evo-auth-service-community` | Ruby 3.4.4 / Rails 7.1 / Devise / Doorkeeper | 3001 |
| `evo-ai-crm-community` | Ruby 3.4.4 / Rails 7.1 (API-only) | 3000 |
| `evo-ai-frontend-community` | React 19 / TypeScript / Vite 6 / Tailwind v4 | 5173 |
| `evo-ai-processor-community` | Python 3.10 / FastAPI | 8000 |
| `evo-ai-core-service-community` | Go 1.24 / Gin / GORM | 5555 |
| `evo-bot-runtime` | Go / Gin | 8080 |

**Infraestrutura:** PostgreSQL 16 + pgvector (porta 5432), Redis Alpine (6379), Mailhog (8025)

**Submodules companheiros** (versionamento independente):
- `evolution-api` — Motor WhatsApp (Node.js) — `2.4.0-rc2`
- `evolution-go` — Motor WhatsApp (Go, alta performance) — `0.7.1+2 commits locais`
- `evo-nexus` — Camada multi-agente — `v0.33.0`
- `evo-flow` — Engine de fluxos — `heads/main`

---

## Status dos submodules vs upstream

| Submodule | Tag pinada | Commits locais | Status |
|---|---|---|---|
| evo-ai-core-service-community | v1.0.0-rc3 | 0 | ✅ puro |
| evo-ai-crm-community | v1.0.0-rc2 | 110 commits à frente | ⚠️ modificado |
| evo-ai-frontend-community | v1.0.0-rc2 | 130 commits à frente | ⚠️ modificado |
| evo-ai-processor-community | v1.0.0-rc3 | 0 | ✅ puro |
| evo-auth-service-community | v1.0.0-rc2 | 58 commits à frente | ⚠️ modificado |
| evo-bot-runtime | v1.0.0-rc3 | 0 | ✅ puro |
| evolution-go | 0.7.1 | 2 commits à frente | ⚠️ modificado |
| evo-nexus | v0.33.0 | 0 | ✅ puro |
| evolution-api | 2.4.0-rc2 | 0 | ✅ puro |
| evo-flow | heads/main | tracking main | ⚡ tracking |

---

## Arquitetura resumida

- **Single-tenant**: uma conta por instalação, sem multi-tenancy
- **Banco compartilhado**: PostgreSQL com pgvector usado pelos dois serviços Rails; Go usa schemas/migrações próprias
- **Auth centralizado**: `evo-auth` (Devise + Doorkeeper) é a fonte de verdade de usuários; `evo-crm` referencia via JWT
- **Resolução de conta via token**: sem header `account-id` entre serviços
- **Hierarquia de roles**: apenas `account_owner` e `agent`
- **Design system próprio**: `@evoapi/design-system` v0.0.6 (pacote npm interno)

---

## Links para documentação gerada

- [Arquitetura](./architecture.md)
- [Source Tree](./source-tree-analysis.md)
- [Integração entre serviços](./integration-architecture.md)
- [Guia de desenvolvimento](./development-guide.md)
- [Guia de deployment](./deployment-guide.md)
- [Análise White-Label](./white-label-analysis.md)
- [Análise Upstream Sync](./upstream-sync-analysis.md)
- [API Contracts](./api-contracts.md)
- [Data Models](./data-models.md)
- [Index master](./index.md)

---

## Primeiros passos

```bash
# Clonar com todos os submodules
git clone --recurse-submodules https://github.com/Luizcc87/evo-crm-community.git

# Setup completo (copia .env, build, inicia, semeia)
make setup

# Primeiro acesso
# http://localhost:5173/setup  → criar usuário admin
```
