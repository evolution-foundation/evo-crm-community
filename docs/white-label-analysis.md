# Evo CRM Community — Análise White-Label

**Data de geração:** 2026-05-22  
**Objetivo:** Identificar o que precisa mudar para tornar o produto minimamente white-label (rebrandável por tenant/instalação)

---

## Resumo executivo

O produto está **parcialmente preparado** para white-label. A internacionalização (i18n) cobre a maior parte dos textos visíveis. No entanto, há **branding hardcoded** em múltiplas camadas que precisam ser endereçadas. A estratégia mínima viável é: (1) parametrizar os pontos críticos via env vars + seed configurável, (2) substituir assets estáticos por variáveis de build, (3) expor config de branding via `RuntimeConfig` no auth.

---

## Inventário de branding hardcoded

### 🔴 CRÍTICO — Visível ao usuário final

| Arquivo | O quê | Linha / Contexto |
|---|---|---|
| `evo-ai-frontend-community/index.html` | `<title>Evo CRM</title>` | Título da aba/janela do browser |
| `evo-ai-frontend-community/src/i18n/locales/en/setup.json` | `"footer": "...your EVO CRM instance."` | Rodapé do wizard de setup |
| `evo-auth-service-community/db/seeds.rb` | `name: 'Evolution Community'` | Nome da conta/tenant semeado |
| `evo-auth-service-community/db/seeds.rb` | `support_email: 'support@evolution.com'` | Email de suporte da conta |
| `evo-ai-frontend-community/src/assets/EVO_CRM.svg` | Logo principal (dark mode) | Aparece em toda a UI |
| `evo-ai-frontend-community/src/assets/EVO_CRM_light.svg` | Logo principal (light mode) | Aparece em toda a UI |
| `evo-ai-frontend-community/public/logo.svg` | Logo pública | Página de login, meta tags |
| `evo-ai-frontend-community/public/favicon.svg` | Favicon | Aba do browser |
| `evo-ai-frontend-community/public/hover-evolution.png` | Hover branding "Evolution" | Interações de hover na UI |

### 🟡 MÉDIO — Visível em emails e comunicações

| Arquivo | O quê | Contexto |
|---|---|---|
| `evo-ai-crm-community/config/initializers/mailer.rb` | From address / app name | Emails enviados pelo sistema |
| `evo-ai-crm-community/config/app.yml` | `version: 4.2.0` | Exposto em API e UI |
| `evo-ai-crm-community/db/seeds.rb` | `website_url: 'https://acme.inc'`, `name: 'Acme Support'` | Seed dev — não crítico em prod |

### 🟡 MÉDIO — Branding no código Ruby (module name)

| Arquivo | O quê | Impacto |
|---|---|---|
| `evo-ai-crm-community/config/application.rb` | `module Evolution` | Nome interno do módulo Rails — não visível ao usuário, mas está no stack trace e logs |
| `evo-ai-crm-community/config/initializers/bms.rb` | Configuração BMS | A investigar |
| `evo-ai-crm-community/lib/evolution_app.rb` | Nome do módulo | Interno |

### 🟢 BAIXO — Infraestrutura / não visível ao usuário

| Arquivo | O quê | Contexto |
|---|---|---|
| `docker-compose.yml` | Nomes dos serviços (`evo-auth`, `evo-crm`) | Internos ao Docker |
| `.env.example` | `POSTGRES_DB: evo_community` | Banco de dados |
| `Makefile` | `Evo AI Community` nos echo | Output de terminal |
| `evo-ai-crm-community/config/initializers/validate_backend_url.rb` | Mensagem de erro | Visível em logs de boot |

---

## Pontos de customização existentes

### Já funcionam (mecanismos disponíveis)

| Mecanismo | Como funciona | O que customiza |
|---|---|---|
| `RuntimeConfig` (auth) | Chave Redis configurável via seed | Nome da conta, domínio, email de suporte, locale |
| `VITE_*` env vars | Build-time via `.env` | URLs dos backends (baked no JS bundle) |
| i18n (50 arquivos JSON por locale) | Arquivos de tradução por idioma | Todos os textos da UI (exceto os hardcoded listados acima) |
| `BACKEND_URL` / `FRONTEND_URL` | Env vars | URLs públicas de redirect OAuth e webhooks |
| `docker-entrypoint.sh` (frontend modificado) | Runtime substitution de `VITE_*_PLACEHOLDER` | URLs após build (necessário para Docker) |

### Não existem / precisam ser criados

| O que falta | Solução mínima recomendada |
|---|---|
| Nome do produto configurável | Env var `APP_NAME` + i18n com interpolação |
| Logo configurável em runtime | Env var `APP_LOGO_URL` ou servir de S3 |
| Favicon configurável | Env var `APP_FAVICON_URL` |
| Email/nome de suporte configurável | Já existe via `RuntimeConfig` — expor no setup wizard |
| Título do browser configurável | Env var `VITE_APP_TITLE` + `index.html` dinâmico |

---

## Esforço estimado por item (mínimo viável)

| Item | Esforço | Serviço |
|---|---|---|
| `<title>` configurável via `VITE_APP_TITLE` | Baixo (1h) | evo-frontend |
| Logo/favicon via env var de URL | Baixo (2h) | evo-frontend |
| Seed `RuntimeConfig` com env vars | Baixo (1h) | evo-auth |
| Texto `"your EVO CRM instance"` no i18n | Trivial (30min) | evo-frontend |
| Expor `APP_NAME` no setup wizard | Médio (4h) | evo-auth + evo-frontend |
| Logo SVG substituível sem rebuild | Médio (4h) | evo-frontend (nginx serve dinâmico) |
| Tema de cores configurável | Alto (2-3 dias) | evo-frontend (CSS vars + Tailwind) |

---

## Plano de ação mínimo white-label (ordenado por impacto)

### Fase 1 — Quick wins (sem quebrar upstream)

1. **`evo-auth/db/seeds.rb`**: Ler `ENV['ACCOUNT_NAME']`, `ENV['ACCOUNT_DOMAIN']`, `ENV['SUPPORT_EMAIL']` com fallback para os valores atuais. Registrar em `CHANGES-LOCAL.md`.

2. **`evo-frontend/index.html`**: Mudar `<title>Evo CRM</title>` para `<title>{{APP_TITLE}}</title>` com substituição via `docker-entrypoint.sh` (já temos o mecanismo).

3. **`evo-frontend/src/i18n/locales/*/setup.json`**: Trocar `"EVO CRM instance"` por `"{{appName}} instance"` com variável i18n.

4. **`.env.example`**: Adicionar `APP_TITLE=Evo CRM`, `APP_LOGO_URL=`, `ACCOUNT_NAME=Evolution Community`.

### Fase 2 — Assets (requer deploy)

5. **Logo e favicon**: Servir `logo.svg` e `favicon.svg` de um path configurável via nginx ou variável de ambiente `APP_LOGO_URL`. Fallback para os arquivos locais.

6. **`hover-evolution.png`**: Substituir por variável ou remover se for puramente decorativo.

### Fase 3 — Completar white-label real

7. **Tema de cores**: CSS custom properties configuráveis via env/API. Tailwind v4 já usa CSS vars nativamente — favorável.

8. **Emails transacionais**: Configurar `from_name` e `from_email` via `RuntimeConfig` ou env vars no mailer initializer.

---

## URLs e identidade por tenant

O produto é **single-tenant**. Não há conceito de sub-domínio por tenant. Toda identidade é por instalação:

- `BACKEND_URL` — URL pública desta instalação
- `FRONTEND_URL` — URL pública do frontend
- `RuntimeConfig.account` — metadados da conta (nome, domínio, email)
- `VITE_*` — URLs baked no bundle (requer rebuild para mudar)

Para suporte a múltiplos tenants no futuro, a arquitetura precisaria de revisão significativa (não está no escopo deste documento).
