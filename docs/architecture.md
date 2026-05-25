# Evo CRM Community — Arquitetura

**Data de geração:** 2026-05-22  
**Tipo:** Monorepo multi-serviço (6 partes de aplicação)

---

## Visão geral

```
Browser
  └─► evo-ai-frontend-community (React/Vite :5173)
           │ REST/WebSocket
           ├─► evo-ai-crm-community (Rails API :3000)
           │        │ JWT service-to-service
           │        ├─► evo-auth-service-community (Rails :3001)
           │        ├─► evo-ai-core-service-community (Go/Gin :5555)
           │        └─► evo-ai-processor-community (FastAPI :8000)
           │
           └─► evo-ai-core-service-community (Go/Gin :5555)

evo-ai-crm-community ──► evo-bot-runtime (Go :8080)
evo-bot-runtime ──────► evolution-api | evolution-go (WhatsApp)
```

---

## Partes e responsabilidades

### evo-auth-service-community (Ruby 3.4.4 / Rails 7.1)
- **Papel**: Autoridade de identidade centralizada
- **Responsabilidades**: autenticação (Devise), emissão de tokens JWT, OAuth2 (Doorkeeper), MFA (TOTP), gestão de usuários e RBAC (`account_owner`, `agent`)
- **Banco**: PostgreSQL compartilhado (schema `public`, tabelas de auth)
- **Background jobs**: Sidekiq + Redis
- **Config de conta**: `RuntimeConfig.account` armazenado no Redis, semeado com `name: 'Evolution Community'`, `support_email: 'support@evolution.com'`

### evo-ai-crm-community (Ruby 3.4.4 / Rails 7.1 API-only)
- **Papel**: Backend principal do CRM
- **Responsabilidades**: contatos, conversas, inboxes, automações, campanhas, webhooks, integrações (Slack, FB, Twilio, etc.), pipelines, macros
- **Módulo Ruby**: `Evolution::Application` (herdado do Chatwoot/Evolution)
- **Banco**: PostgreSQL compartilhado (schema `public`, tabelas do CRM)
- **Background jobs**: Sidekiq + Redis
- **Padrão pub/sub**: gem `wisper` para event-driven internamente
- **Config**: `config/app.yml` com `version: 4.2.0`
- **Extension points**: `config/initializers/evo_extension_points.rb`, `evo_flow_listeners.rb`

### evo-ai-frontend-community (React 19 / TypeScript / Vite 6)
- **Papel**: SPA do CRM
- **Responsabilidades**: toda UI do CRM (chat, contacts, settings, pipelines, AI agents, etc.)
- **Design system**: `@evoapi/design-system` v0.0.6
- **State management**: Zustand v5
- **Roteamento**: React Router v7
- **Internacionalização**: i18next + react-i18next (locales: en, es, fr, it, pt)
- **Canais de comunicação real-time**: `@rails/actioncable`
- **Build-time branding**: `VITE_*` env vars baked no bundle em build

### evo-ai-core-service-community (Go 1.24 / Gin / GORM)
- **Papel**: Serviço de IA e agentes
- **Responsabilidades**: execução de agentes IA, integrações com LLMs, MCP servers, ferramentas customizadas
- **Módulo Go**: `evo-ai-core-service`
- **Banco**: PostgreSQL via GORM (schema próprio, migrações em `migrations/`)
- **Segurança**: Fernet para criptografia de API keys

### evo-ai-processor-community (Python / FastAPI)
- **Papel**: Processador de IA assíncrono
- **Responsabilidades**: processamento de mensagens, pipeline de IA, embedding, RAG

### evo-bot-runtime (Go / Gin)
- **Papel**: Runtime de bots
- **Responsabilidades**: execução de fluxos de bot, integração com WhatsApp via evolution-api/evolution-go

---

## Decisões arquiteturais

| Decisão | Valor |
|---|---|
| Multi-tenancy | Não — single-tenant |
| Super-admin | Não — config via seed + env vars |
| Resolução de conta | Via token JWT (sem header account-id) |
| Roles | Apenas `account_owner` e `agent` |
| Banco de dados | PostgreSQL 16 + pgvector (compartilhado entre Rails; Go usa schema próprio) |
| Módulo Rails do CRM | `Evolution::Application` (fork do Chatwoot) |
| Comunicação inter-serviço | HTTP/REST com JWT |
| Background jobs | Sidekiq (Ruby) + Redis |

---

## Fluxo de autenticação

```
1. Usuário faz login no frontend
2. Frontend → POST evo-auth:3001/auth/sign_in
3. evo-auth retorna JWT token
4. Frontend inclui JWT em todas as requisições para evo-crm:3000
5. evo-crm valida JWT contra chave compartilhada (JWT_SECRET)
6. evo-crm consulta evo-auth se necessário (service-to-service com AUTH_SECRET)
```

---

## Variáveis de ambiente críticas

| Variável | Onde é usada | Descrição |
|---|---|---|
| `JWT_SECRET` | evo-auth, evo-crm, evo-core | Segredo compartilhado JWT — deve ser idêntico |
| `AUTH_SECRET` | evo-auth, evo-crm, evo-processor | Auth service-to-service |
| `API_KEY_ENCRYPTION_SECRET` | evo-core, evo-processor | Criptografia de API keys (Fernet) |
| `BACKEND_URL` | evo-crm | URL pública do backend — recusa boot em produção se apontar para localhost |
| `FRONTEND_URL` | evo-crm, evo-auth | URL pública do frontend (redirects OAuth, webhooks) |
| `VITE_API_URL` | evo-frontend (build-time) | URL do CRM backend acessível pelo browser |
| `VITE_AUTH_API_URL` | evo-frontend (build-time) | URL do Auth service acessível pelo browser |
| `VITE_EVOAI_API_URL` | evo-frontend (build-time) | URL do Core service |
| `VITE_AGENT_PROCESSOR_URL` | evo-frontend (build-time) | URL do Processor |

---

## Tecnologias por camada

| Camada | Tecnologia | Versão |
|---|---|---|
| Frontend SPA | React | 19.0 |
| Frontend build | Vite | 6.3 |
| Frontend styling | Tailwind CSS | 4.1 |
| Frontend state | Zustand | 5.0 |
| Backend CRM | Ruby on Rails (API-only) | 7.1 |
| Backend Auth | Ruby on Rails | 7.1 |
| Backend IA | Go / Gin | 1.24 |
| Backend Bot | Go / Gin | — |
| Backend Processor | Python / FastAPI | 3.10 |
| Banco de dados | PostgreSQL + pgvector | 16 |
| Cache/Jobs | Redis + Sidekiq | Alpine |
| Containerização | Docker Compose / Swarm | — |
| Deploy prod | Portainer Swarm (VPS Oracle Cloud aarch64) | — |
| Imagens Docker | `lc1868/*` no Docker Hub (multi-arch amd64+arm64) | — |
