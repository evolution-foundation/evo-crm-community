# Evo CRM Community — Source Tree

**Data de geração:** 2026-05-22

---

## Raiz do monorepo (overlay layer)

```
evo-crm-community/                    ← Orquestrador (fork de EvolutionAPI/evo-crm-community)
├── evo-auth-service-community/        ← [SUBMODULE] Auth Rails — fork Luizcc87, 58 commits à frente
├── evo-ai-crm-community/              ← [SUBMODULE] CRM Rails — fork Luizcc87, 110 commits à frente
├── evo-ai-frontend-community/         ← [SUBMODULE] Frontend React — fork Luizcc87, 130 commits à frente
├── evo-ai-processor-community/        ← [SUBMODULE] Processor Python — puro upstream (rc3)
├── evo-ai-core-service-community/     ← [SUBMODULE] Core Go — puro upstream (rc3)
├── evo-bot-runtime/                   ← [SUBMODULE] Bot Go — puro upstream (rc3)
├── evolution-api/                     ← [SUBMODULE] WhatsApp Node.js — puro upstream (2.4.0-rc2)
├── evolution-go/                      ← [SUBMODULE] WhatsApp Go — 2 commits locais
├── evo-nexus/                         ← [SUBMODULE] Multi-agent layer — puro (v0.33.0)
├── evo-flow/                          ← [SUBMODULE] Flow engine — tracking main
│
├── _evo/                              ← [OVERLAY] Sistema BMM / agentes IA / workflows (local)
├── _evo-output/                       ← [OVERLAY] Artefatos gerados pelos agentes
├── .agent/                            ← [OVERLAY] Config agente local
├── .agents/                           ← [OVERLAY] Agentes adicionais
├── .claude/                           ← [OVERLAY] Config Claude Code
├── .vscode/                           ← [OVERLAY] Config VS Code
├── .github/                           ← [OVERLAY] CI/CD, dependabot
├── docs/                              ← [OVERLAY] Documentação local (este diretório)
│   ├── local/                         ← Infra/deploy local — nunca sobe para upstream
│   │   ├── stack-swarm-vps.yaml       ← Stack Portainer Swarm VPS Oracle Cloud
│   │   ├── IMAGE_REGISTRY_MAP.md      ← Mapeamento lc1868/* → serviços
│   │   ├── DEPLOY_SWARM_LOG.md
│   │   └── padroes-local.md
│   ├── CHANGES-LOCAL.md               ← Registro obrigatório de customizações
│   └── SYNC.md                        ← Procedimento de sync com upstream
├── deploy/                            ← [OVERLAY] Configs de deploy
├── nginx/                             ← [OVERLAY] Config nginx
├── scripts/                           ← [OVERLAY] Scripts operacionais
│   └── docker-publish.sh             ← Build e push multi-arch para Docker Hub
├── public/                            ← Assets públicos do orquestrador
│
├── docker-compose.yml                 ← Orquestração local dev
├── docker-compose.swarm.yaml          ← Orquestração Swarm produção
├── docker-compose.prod-test.yaml      ← Orquestração prod-test
├── .env.example                       ← Template de configuração
├── .env.swarm.example                 ← Template Swarm
├── Makefile                           ← Comandos de desenvolvimento
├── CLAUDE.md                          ← Instruções para Claude Code
├── CONTEXT.md                         ← Contexto de fork/overlay
├── AGENTS.md                          ← Regras para agentes IA
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── NOTICE
├── SECURITY.md
└── TRADEMARKS.md
```

---

## evo-auth-service-community (Rails — Auth)

```
evo-auth-service-community/
├── app/
│   ├── controllers/           ← API controllers (Devise Token Auth, Doorkeeper)
│   ├── models/                ← User, Role, Permission, RuntimeConfig
│   ├── jobs/                  ← Sidekiq jobs
│   └── policies/              ← Pundit authorization policies
├── config/
│   ├── application.rb         ← Rails app config
│   ├── initializers/          ← Redis, CORS, JWT, etc.
│   └── routes.rb
├── db/
│   ├── migrate/               ← Migrations numeradas
│   └── seeds.rb               ← Semeia RuntimeConfig com 'Evolution Community'
├── Dockerfile
└── Gemfile
```

---

## evo-ai-crm-community (Rails — CRM Backend)

```
evo-ai-crm-community/
├── app/
│   ├── controllers/           ← API v1 controllers
│   ├── models/                ← Contact, Conversation, Inbox, Channel::*, etc.
│   ├── services/              ← Business logic
│   ├── jobs/                  ← Sidekiq jobs
│   ├── listeners/             ← EvoFlow event listeners
│   ├── middleware/            ← Rack middleware customizado
│   └── policies/              ← Pundit
├── config/
│   ├── application.rb         ← module Evolution::Application
│   ├── app.yml                ← version: 4.2.0
│   ├── initializers/          ← ~40 initializers (evo_extension_points, bms, etc.)
│   └── environments/
├── db/
│   ├── schema.rb              ← Schema mestre (usado por seed-crm)
│   ├── migrate/
│   └── seeds.rb               ← Seeds dev com 'Acme Support', acme.inc
├── lib/
│   ├── evolution_app.rb       ← Módulo principal
│   └── events/
│       └── evo_flow_event_names.rb
└── docker/Dockerfile
```

---

## evo-ai-frontend-community (React — Frontend)

```
evo-ai-frontend-community/
├── src/
│   ├── assets/
│   │   ├── EVO_CRM.svg            ← Logo principal (dark)
│   │   ├── EVO_CRM_light.svg      ← Logo principal (light)
│   │   └── channels/              ← Logos de canais (evolution-api.png, etc.)
│   ├── components/                ← Componentes React reutilizáveis
│   ├── config/                    ← Configurações de features
│   ├── constants/                 ← Constantes da aplicação
│   ├── contexts/                  ← React contexts
│   ├── guards/                    ← Route guards (auth)
│   ├── hooks/                     ← Custom React hooks
│   ├── i18n/
│   │   └── locales/
│   │       ├── en/                ← ~50 arquivos JSON de tradução (inglês)
│   │       ├── es/                ← Espanhol
│   │       ├── fr/                ← Francês
│   │       ├── it/                ← Italiano
│   │       └── pt/                ← Português
│   ├── pages/                     ← Pages/views por rota
│   ├── plugin-host/               ← Sistema de plugins
│   ├── routes/                    ← Definição de rotas
│   ├── services/                  ← API client layer
│   ├── store/                     ← Zustand stores
│   ├── styles/                    ← CSS global
│   ├── tours/                     ← React Joyride onboarding tours
│   ├── types/                     ← TypeScript type definitions
│   ├── utils/                     ← Utilities
│   ├── App.tsx                    ← Root component
│   └── main.tsx                   ← Entry point
├── public/
│   ├── favicon.svg                ← Favicon (SVG)
│   ├── logo.svg                   ← Logo pública
│   ├── hover-evolution.png        ← Imagem de hover branding
│   ├── integrations/              ← Logos de integrações (openai, slack, etc.)
│   └── widget-sdk/
│       └── sdk.min.js             ← Web Widget SDK
├── index.html                     ← <title>Evo CRM</title>
├── vite.config.ts                 ← Build config + ffmpeg plugin
├── docker-entrypoint.sh           ← [MODIFICADO] Runtime env substitution + CSP fix
└── nginx.conf                     ← [MODIFICADO] CSP com Cloudflare analytics
```

---

## evo-ai-core-service-community (Go — Core IA)

```
evo-ai-core-service-community/
├── cmd/                       ← Entry points
├── internal/                  ← Lógica interna
│   ├── handlers/              ← Gin HTTP handlers
│   ├── models/                ← GORM models
│   ├── services/              ← Business logic
│   └── middleware/            ← Gin middleware
├── migrations/                ← SQL migrations (golang-migrate)
│   └── 000001_*.up.sql
└── go.mod                     ← module evo-ai-core-service
```

---

## Arquivos overlay vs upstream

| Arquivo/Pasta | Origem | Modificado? |
|---|---|---|
| `docker-compose.yml` | Overlay (orquestrador) | Sim — portas, env vars, serviços |
| `.env.example` | Overlay | Sim — variáveis de produção |
| `Makefile` | Overlay | Sim — targets customizados |
| `scripts/docker-publish.sh` | Overlay (novo) | N/A — arquivo local |
| `docs/local/` | Overlay (novo) | N/A — arquivo local |
| `docs/SYNC.md` | Overlay (novo) | N/A — arquivo local |
| `evo-ai-frontend-community/docker-entrypoint.sh` | Submodule fork | **SIM — conflito médio** |
| `evo-ai-frontend-community/nginx.conf` | Submodule fork | **SIM — conflito médio** |
| `evo-ai-crm-community/*` | Submodule fork | **SIM — 110 commits** |
| `evo-auth-service-community/*` | Submodule fork | **SIM — 58 commits** |
| `evolution-go/*` | Submodule fork | **SIM — 2 commits** |
