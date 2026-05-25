# Evo CRM Community — Arquitetura de Integração

**Data de geração:** 2026-05-22

---

## Mapa de comunicação entre serviços

```
┌─────────────────────────────────────────────────────────────────┐
│                        Browser / Client                         │
└──────────────┬──────────────────────────────┬───────────────────┘
               │ HTTP/REST + WebSocket         │ HTTP/REST
               ▼                              ▼
    ┌──────────────────┐           ┌─────────────────────┐
    │ evo-ai-frontend  │           │ evo-ai-core-service  │
    │  :5173 (Vite)    │           │    :5555 (Go/Gin)    │
    └────────┬─────────┘           └──────────┬──────────┘
             │ REST + ActionCable              │ Fernet-encrypted API keys
             ▼                                │
    ┌──────────────────┐                      │
    │ evo-ai-crm       │◄─────────────────────┘
    │  :3000 (Rails)   │  EVO_AI_CORE_SERVICE_URL
    └────────┬─────────┘
             │
             ├─── EVO_AUTH_SERVICE_URL ──────► evo-auth-service :3001
             │
             ├─── AI_PROCESSOR_URL ──────────► evo-ai-processor :8000
             │
             └─── BOT_RUNTIME_URL ────────────► evo-bot-runtime :8080
                                                       │
                                         ┌─────────────┴──────────────┐
                                         ▼                            ▼
                                  evolution-api              evolution-go
                                  (WhatsApp Node)           (WhatsApp Go)
```

---

## Pontos de integração detalhados

### Frontend → CRM Backend
- **Protocolo**: HTTP/REST + WebSocket (ActionCable)
- **Auth**: JWT Bearer token no header `Authorization`
- **Base URL**: `VITE_API_URL` (baked em build)
- **Real-time**: ActionCable via WebSocket para conversas ao vivo

### Frontend → Core Service
- **Protocolo**: HTTP/REST
- **Auth**: JWT Bearer token
- **Base URL**: `VITE_EVOAI_API_URL` (baked em build)
- **Uso**: Configuração de agentes IA, MCP servers, ferramentas

### CRM Backend → Auth Service
- **Protocolo**: HTTP/REST
- **Auth**: `AUTH_SECRET` (service-to-service)
- **Env var**: `EVO_AUTH_SERVICE_URL=http://evo-auth:3001`
- **Uso**: Validação de tokens, sync de usuários

### CRM Backend → Core Service
- **Protocolo**: HTTP/REST
- **Auth**: JWT compartilhado
- **Env var**: `EVO_AI_CORE_SERVICE_URL=http://evo-core:5555`
- **Uso**: Execução de agentes IA, delegação de processamento

### CRM Backend → Processor
- **Protocolo**: HTTP/REST
- **Auth**: API key criptografada (Fernet)
- **Env var**: `AI_PROCESSOR_URL`
- **Uso**: Processamento assíncrono de IA, embedding, RAG

### CRM Backend → Bot Runtime
- **Protocolo**: HTTP/REST
- **Auth**: `BOT_RUNTIME_SECRET`
- **Env vars**: `BOT_RUNTIME_URL`, `BOT_RUNTIME_POSTBACK_BASE_URL`
- **Uso**: Envio de mensagens via WhatsApp, callback de postbacks

### Bot Runtime → Evolution API / Evolution Go
- **Protocolo**: HTTP/REST
- **Auth**: API Key da instância Evolution
- **Env var**: `EVOLUTION_BASE_URL`
- **Uso**: Envio e recebimento de mensagens WhatsApp

---

## Variáveis de integração inter-serviços

```bash
# CRM → Auth
EVO_AUTH_SERVICE_URL=http://evo-auth:3001
AUTH_SECRET=<segredo_compartilhado>

# CRM → Core
EVO_AI_CORE_SERVICE_URL=http://evo-core:5555

# CRM → Processor
AI_PROCESSOR_URL=http://evo-processor:8000
API_KEY_ENCRYPTION_SECRET=<fernet_key>

# CRM → Bot Runtime
BOT_RUNTIME_URL=http://evo-bot-runtime:8080
BOT_RUNTIME_SECRET=<segredo>
BOT_RUNTIME_POSTBACK_BASE_URL=http://evo-crm:3000

# Bot Runtime → WhatsApp
EVOLUTION_BASE_URL=http://evolution-api:8080

# Frontend (build-time — baked no bundle)
VITE_API_URL=http://localhost:3000
VITE_AUTH_API_URL=http://localhost:3001
VITE_EVOAI_API_URL=http://localhost:5555
VITE_AGENT_PROCESSOR_URL=http://localhost:8000
```

---

## Banco de dados compartilhado

```
PostgreSQL (postgres:5432)
  ├── Database: evo_community
  │     ├── Schema public → evo-ai-crm-community (tabelas Rails CRM)
  │     ├── Schema public → evo-auth-service-community (tabelas auth compartilhadas)
  │     └── Schema próprio → evo-ai-core-service-community (migrações Go)
  └── Extensão: pgvector (para embeddings IA)

Redis (redis:6379)
  ├── DB 0 → evo-crm (cache, ActionCable, Sidekiq)
  └── DB 1 → evo-auth (cache, Sidekiq, sessions)
```

---

## Ordem de dependências no startup

1. `postgres` + `redis` + `mailhog` (infraestrutura)
2. `evo-auth` + `evo-auth-sidekiq` (depende de postgres + redis)
3. `evo-crm` + `evo-crm-sidekiq` (depende de postgres + redis + evo-auth)
4. `evo-core` (depende de postgres)
5. `evo-processor` (depende de evo-core)
6. `evo-bot-runtime` (depende de evo-crm)
7. `evo-frontend` (depende de evo-crm + evo-auth + evo-core)
