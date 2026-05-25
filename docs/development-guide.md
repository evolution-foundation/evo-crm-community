# Evo CRM Community — Guia de Desenvolvimento

**Data de geração:** 2026-05-22

---

## Pré-requisitos

- Docker + Docker Compose v2
- Git com suporte a submodules
- PowerShell ou bash (make targets usam bash syntax)
- (Opcional) `docker buildx` para build multi-arch

---

## Setup inicial

```bash
# 1. Clonar com submodules
git clone --recurse-submodules https://github.com/Luizcc87/evo-crm-community.git
cd evo-crm-community

# 2. Setup completo (copia .env, build, inicia, semeia)
make setup

# Acesso inicial
# http://localhost:5173/setup → criar usuário admin
```

### O que `make setup` faz
1. Copia `.env.example` → `.env` (se não existir)
2. Inicializa todos os submodules recursivamente
3. `docker compose build`
4. Inicia apenas infraestrutura: `postgres`, `redis`, `mailhog`
5. Aguarda PostgreSQL estar pronto
6. Executa `make seed` (CRM schema + auth seed)
7. Inicia todos os serviços

---

## Comandos cotidianos

```bash
make start          # docker compose up -d
make stop           # docker compose down
make restart        # down + up
make build          # rebuild todas as imagens --no-cache
make status         # docker compose ps
make logs           # logs de todos; make logs SERVICE=evo-crm para filtrar
make clean          # down -v (DESTRÓI todos os dados!)
```

---

## Database e seeds

```bash
# Ordem correta obrigatória:
make seed           # seed-crm depois seed-auth

# Separados:
make seed-crm       # db:create + schema:load + marca migrations auth + seed CRM
make seed-auth      # seed auth (cria usuário padrão)
```

**Por que essa ordem importa:** `evo-crm` é dono do schema PostgreSQL master. O `seed-crm` carrega o schema completo primeiro e marca as migrations do auth como aplicadas. Só então o `seed-auth` pode rodar sem conflito.

**Conta padrão semeada pelo auth:**
```ruby
RuntimeConfig.set('account', {
  name: 'Evolution Community',          # ← BRANDING HARDCODED no seed
  support_email: 'support@evolution.com', # ← HARDCODED
  locale: 'en'
})
```

---

## Acesso aos shells dos containers

```bash
make shell-auth          # bash no evo-auth
make shell-crm           # bash no evo-crm
make shell-core          # sh no evo-core (Alpine)
make shell-processor     # bash no evo-processor
make shell-bot-runtime   # sh no evo-bot-runtime (Alpine)
```

---

## Atualizar submodules

```bash
# Inicializar (primeira vez)
git submodule update --init --recursive

# Puxar últimas versões dos submodules companheiros
git submodule update --remote

# Submodules de serviço (auth, crm, frontend, etc.) estão pinados
# Ver docs/SYNC.md para sync com upstream oficial
```

---

## Workflow com submodules modificados

Os submodules `evo-ai-crm-community`, `evo-auth-service-community` e `evo-ai-frontend-community` têm forks próprios. Para trabalhar neles:

```bash
# Entrar no submodule
cd evo-ai-frontend-community

# Ver remotes configurados
git remote -v
# origin  → evolution-foundation/... (upstream, leitura)
# fork    → Luizcc87/...            (seu fork, escrita)

# Customizações sempre em branch develop ou custom/*
# NUNCA em main

# Após modificar, registrar em docs/CHANGES-LOCAL.md
# Prefixo 'custom:' em commits de customização
```

---

## Build multi-arch para Docker Hub

```bash
# Publicar imagens lc1868/* (amd64 + arm64)
./scripts/docker-publish.sh
```

---

## Portas de acesso local

| Serviço | URL |
|---|---|
| Frontend | http://localhost:5173 |
| Setup wizard | http://localhost:5173/setup |
| CRM API | http://localhost:3000 |
| Auth API | http://localhost:3001 |
| Core API | http://localhost:5555 |
| Bot Runtime | http://localhost:8080 |
| Mailhog (emails) | http://localhost:8025 |
| PostgreSQL | localhost:5432 |
| Redis | localhost:6379 |

---

## Configuração de ambiente

Copiar `.env.example` → `.env`. Os defaults funcionam para dev local sem alterações.

**Variáveis que DEVEM ser sobrescritas em produção:**
- `BACKEND_URL` — URL pública do CRM (recusa boot se apontar para localhost em produção)
- `FRONTEND_URL` — URL pública do frontend
- `JWT_SECRET` — segredo JWT (deve ser idêntico em auth, crm, core)
- `AUTH_SECRET` — auth service-to-service
- `API_KEY_ENCRYPTION_SECRET` — Fernet key para criptografia
- `REDIS_PASSWORD` — senha Redis
- `POSTGRES_PASSWORD` — senha PostgreSQL
