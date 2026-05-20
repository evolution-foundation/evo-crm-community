# Changelog

All notable changes to **evo-crm-community** (umbrella) will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Este repositório é o guarda-chuva da família CRM Community: orquestra os 7 submódulos via Docker Compose. Para detalhes por serviço, ver `CHANGELOG.md` dentro de cada submódulo.

## [Unreleased]

### Added

- N/A

### Changed

- N/A

### Fixed

- N/A

## [v1.0.0-rc3] - 2026-05-17

Release de estabilização posterior ao `v1.0.0-rc2` (2026-05-05). Janela de ~12 dias com ~16 commits no super-repo e ~165 commits/PRs entre os submódulos. Foco predominante em **correções de bugs** de produção identificados após o rc2 — mensageria Evolution Go, mídia outbound, hardening de endpoints públicos, 2FA, RBAC, escopo IDOR, filtragem de secrets em logs — combinadas com a fundação técnica do open-core (Extension Points em todos os serviços + Plugin Host Runtime no frontend) e duas features cross-stack: products catalog e template bundles export/import.

### Highlights

- 🐛 **Massive bug fix release** — 6 frentes principais de hardening: paridade de payload Evolution Go (botões/listas EVO-1115), entrega de mídia outbound (EVO-1151), Notificame verify hardening (EVO-986), bulk actions com escopo IDOR (EVO-1084), filtragem de secrets em logs Rails (EVO-1111), 2FA backup codes hash+500 (EVO-991).
- 🧩 **Open-core foundation completa**: todos os 5 submódulos agora declaram `EXTENSION_POINTS.md` + módulos no-op. O frontend ganhou um **Plugin Host Runtime** (EVO-1379) que carrega plugins externos sem fork. O auth-service ganhou `LoginGate` e `TokenClaims` como pontos de extensão estritos. O CRM ganhou CI guard-rail (EVO-1287) que impede alteração silenciosa do contrato.
- 📦 **Products catalog** — modelo de products com variantes, attach a agentes, integração com pipeline para vendas. Tools nativas no processor (`link_product_to_pipeline_item`) e injeção do catálogo no contexto do agente.
- 📤 **Template bundles export/import (EVO-1116)** — empacotamento de configuração (inboxes, agentes, automation rules, canned responses, templates) em ZIP portável entre instalações. Permissão dedicada no RBAC (`template_bundles.manage`), wizard de export no frontend, i18n pt/es/fr/it.
- 🛡️ **Roles & Permissions UI completa (EVO-1061)** — tela de administração de papéis customizados com CRUD pleno, escopo `account_owner`, e guard contra privilege escalation via delegation de permissão não detida.
- 🔌 **Knowledge Nexus integration** — agentes podem buscar em spaces do Nexus diretamente do prompt (`knowledge_nexus_search` tool no processor + space picker no Agent Builder do frontend + endpoint proxy no core-service).
- 🤖 **Automation rules — consolidação**: operador `attribute_changed` em labels (EVO-1058), listeners `conversation_resolved` / `conversation_status_changed` (EVO-1057), `move_to_pipeline` cross-pipeline action, dedup em janela de 5s, painel de logs no frontend.

### Added

- **Plugin Host Runtime no frontend (EVO-1379)** — carrega plugins externos em runtime; base para a Enterprise edition injetar features sem fork.
- **`EXTENSION_POINTS.md` em todos os 5 submódulos** — contrato público versionado de pontos de extensão. Auth: `LoginGate` + `TokenClaims`. CRM: 4 hooks + `lib/evo_extension_points/` no-op + CI guard-rail (EVO-1287). Frontend: 4 categorias declaradas (EVO-1284/1378) com Plugin Host Runtime na v2.1.0 (EVO-1387). Core-service: `pkg/evoextensions` com 3 interfaces no-op (EVO-1285). Processor: documento de hooks (EVO-1376).
- **Products catalog (CRM + frontend + processor)** — modelo com variantes, attach a agentes, panel de vendas no pipeline, injeção no contexto do agente, tool `link_product_to_pipeline_item`, permissões `products.*` no RBAC.
- **Template bundles export/import (EVO-1116)** — feature cross-stack (CRM + frontend + auth RBAC) para empacotar configuração de instalação em ZIP. Recurso `template_bundles` declarado no auth, endpoint no CRM, wizard de export no frontend com i18n.
- **Roles & Permissions admin UI (EVO-1061)** — tela completa de gestão de papéis no frontend + CRUD API no auth-service + guards de boundary `account_owner`/`super_admin` + spec de regressão.
- **Knowledge Nexus integration** — `knowledge_nexus_search` tool nativa no processor, space picker no Agent Builder, endpoint proxy no core-service.
- **Tools nativas no processor LLM agent** — `knowledge_nexus_search`, `manage_conversation_labels`, `link_product_to_pipeline_item`.
- **Automation rules** — operador `attribute_changed` com pickers From/To (EVO-1058), listeners `conversation_resolved` e `conversation_status_changed` (EVO-1057), action `move_to_pipeline` (cross-pipeline), painel de logs no frontend, action service com `send_canned_response` e `send_template`.
- **Bulk actions** — resolve em massa de conversas via checkbox (EVO-1011), response com `success_ids` / `failed_ids` por item.
- **Pipelines — `move_to_pipeline` action** — automation move conversa entre pipelines preservando id, com dedup em janela de 5s.
- **EVO-1051** — `DELETE` endpoint para limpar admin config por tipo (CRM) + botão "Clear Configuration" no Admin Settings (frontend).
- **EVO-1189** — Delete contact action no frontend.
- **EVO-990** — Pipeline actions disponíveis no menu 3 pontos e context menu (right-click).
- **EVO-988** — Telefone do contato visível na lista de conversas e header do chat.
- **EVO-1146 — i18n** — múltiplas chaves missing adicionadas em 6 locales no frontend; locales pt/es/fr/it adicionados para template bundles.
- **Specs de regressão** — `pipeline_item` auto-assign-and-move (EVO-1080), Notificame verify (EVO-986), contato com attachments (EVO-973), webhooks de macro (EVO-1041), boundary `account_owner`/`super_admin` (EVO-1060), permission set do role `agent` (EVO-1060).

### Changed

- **EVO-1049 — SMTP/BMS/Resend aplicados em runtime no auth-service** — operador pode trocar essas configs via UI sem restart do container. Frontend retirou o banner de workaround (rc2) que pedia restart.
- **EVO-1113 — Consolidação de resolução de credenciais Evolution no CRM** — single concern (`EvolutionConcern`) centraliza fallback per-field para `api_url`/`admin_token`. Reduz superfície de bug entre Evolution API e Evolution Go.
- **EVO-1147 — Polling de provider config no frontend** — Page Visibility API integrada, sem polling em aba background; `provider_config` removido das deps.
- **EVO-1085 — Reconexão de WebSocket** — reconexão ativa com toast de sucesso + backoff em background.
- **EVO-1131 — Upload de arquivos grandes** — skip de fetch+blob, limite elevado para 100MB.
- **EVO-1044 — Per-field GlobalConfig fallback detection** — banner do Connection Settings agora detecta campo a campo.
- **EVO-976 — Avatar storage** (#80, umbrella) — volumes compartilhados, `AUTH_SERVICE_URL` documentado, storage docs atualizadas.
- **`EVOLUTION_OPERATOR_EMAIL`** documentado no `.env.example` (licensing).
- **Docs / branding** — toda a stack padronizada para Evolution Foundation 2026 (README, LICENSE, NOTICE, TRADEMARKS); URLs GitHub migradas de `EvolutionAPI` para `evolution-foundation`.
- **Docker tag convention** — corrigido no `release.yml` e README do umbrella (sem prefixo `v` nas tags Docker).
- **CI** — workflows passam a rodar em PRs contra `develop` (não só `main`); pacotes Linear/CRM com PR link buscado dos comentários do Linear no skill `code-review`.

### Fixed

#### Mensageria — Evolution Go / Evolution API
- **EVO-1115** — payload de buttons/lists corrigido para formato Evolution Go (paridade com Evolution API). Mensagens interativas chegavam malformadas.
- **EVO-1151** — falha de entrega de mídia outbound em ambos os providers (Evolution API e Evolution Go).
- **Mensagens duplicadas no incoming handler do Evolution Go** — dedup no entry point.
- **Fallback de `api_url` / `admin_token`** — cai para `GlobalConfig` quando inbox config está vazia.

#### Estabilidade / API REST
- **2FA backup codes** (EVO-991, auth) — 500 NoMethodError + hash plaintext no banco. Corrigido com BCrypt + handling de campo nulo.
- **EVO-1063 — Password validation 422 estruturada** (auth + frontend) — resposta com códigos machine-readable consumida por checklist inline no formulário de criação de usuário.
- **EVO-1046 — `setupRequired=false` default** quando `/setup/status` erra (frontend) — antes 5xx no setup status bloqueava o app inteiro.
- **EVO-1107 — Configuration tab blank/slow load** — skeleton + polling corrigido.
- **EVO-1048 — Sidebar colapsada** — submenu flyout e tooltip aparecem quando sidebar está collapsed.
- **EVO-1145 — Conversation match em reducers** — agora casa por `id || uuid`.
- **EVO-1078 / 1054 / 1062 / 1056** — bugs múltiplos de chat e auth resolvidos em batch.

#### Webhooks / Notificame
- **EVO-986 — Notificame verify endpoint hardening** — auth obrigatório, validação de payload, sem error leakage; spec de regressão.
- **EVO-1041 — Macro webhook delivery failures** — falhas agora são surfaceadas; re-raise restrito a `:macro_webhook` para evitar retry storm.
- **EVO-1130 — Attachment fallback_title** — prefere `content[:fileName]`.

#### Automation / Pipeline
- **`labels` condition** — `EXISTS` subquery (independente, NULL-safe), resolve UUIDs para titles, casa label em conversation OU contact.
- **`message_type` filter** — aceita valores numéricos.
- **`apply_label` action** — resolve UUIDs para titles antes de tagear; abre label picker no frontend.
- **`pipeline_stage_updated`** — dedup em janela de 5s por `(rule, pipeline_item, stage)`.
- **Cross-pipeline stage movement** — bypass correto da validação `same-pipeline`.
- **Build break** — `MessageTemplateVariable` definido localmente.
- **Menu** — item de automation duplicado removido.
- **EVO-1018 — Group contacts** — distingue contatos de grupo WhatsApp de contatos reais (CRM + frontend).
- **EVO-998** — arquivos órfãos de contact events e dead i18n removidos.

#### RBAC
- **EVO-1060 — `agent` role** — `pipelines.read` backfilled, `pipelines.update` removido (teria desbloqueado endpoints destrutivos).

#### Mídia (EVO-999)
- **HIGH review findings** aplicadas: video file_type fallback, attachment fallback_title, force-download via fetch+blob coberto em todos os caminhos.

#### Outros
- **DB asyncpg** (processor) — `sslmode` traduzido para `ssl` (parâmetro nativo do driver).
- **Docker bundler** (CRM) — versão fixada na install.

### Security

- **EVO-1111 — Filtragem de secrets em logs Rails** (CRM) — campos sensíveis (password, token, api_key) filtrados antes do log.
- **EVO-1084 — IDOR scope no `BulkActionsJob`** (CRM) — escopo de account aplicado; antes era possível manipular recursos cross-tenant com um ID válido.
- **EVO-1061 — Privilege escalation via delegation** (auth) — `account_owner` não consegue mais delegar permissões que ele próprio não detém.
- **EVO-986 — Notificame verify** (CRM) — auth obrigatório + sem error leakage.
- **2FA backup codes** (auth) — codes hashed com BCrypt; antes ficavam em plaintext no banco.

### Notas para upgrade de PROD existente

- ✅ **Mudanças em RBAC do role `agent`** ativam automaticamente via `db:migrate` (EVO-1060) — não requer reseed.
- ✅ **SMTP/BMS/Resend runtime** (EVO-1049) — aplicado automaticamente após upgrade do auth-service. Operador pode trocar configs sem restart.
- ✅ **Filtragem de secrets nos logs** — ativa automaticamente após upgrade do CRM. Logs antigos não são afetados (apenas as novas entradas).
- ⚠️ **Backup codes 2FA** — a partir do rc3 os codes são armazenados com BCrypt. Codes gerados antes do rc3 ficaram em plaintext no banco; se o histórico do banco esteve acessível a alguém fora do operador da instalação, recomenda-se regenerar via UI.
- 📝 **`EXTENSION_POINTS.md`** — apenas contrato público; não há ação de migração. Reativa para Enterprise edition que injeta as implementações.
- 📝 **CHANGELOG por submódulo** tem o detalhamento técnico completo — esta seção é o resumo guarda-chuva.

## [v1.0.0-rc2] - 2026-05-05

Release de estabilização posterior ao `v1.0.0-rc1` (2026-04-24). Janela de ~3 semanas concentrando ~40 commits de orquestração no super-repo e ~70 PRs entre os submódulos. Foco em quatro frentes:

1. **Docker / setup determinístico** — `make setup` em fresh install funciona sem race condition entre serviços
2. **Mídia Cloud / WhatsApp** — buckets S3 privados, gravação de áudio PTT-compatible, render inline de vídeo
3. **RBAC `super_admin`** — operador da instalação separado do `account_owner`, com upgrade automático em PROD existente
4. **Estabilidade de API** — eliminação de `500 Internal Server Error` em endpoints REST, fluxo Evolution Go corrigido ponta a ponta

### Highlights

- 🎙️ **Áudio WhatsApp Cloud finalmente funciona em produção**: depois de 4 tentativas com FFmpeg WASM (todas bloqueadas por requisitos de SharedArrayBuffer / COOP+COEP / worker corrompido no npm), pivotamos para `opus-recorder@8.0.5` — gravação direta em OGG/Opus PTT-compatible no browser, sem reencode, sem latência server-side.
- 🎬 **Vídeo no chat aparece como player**, não mais como anexo "Baixar arquivo".
- 🗄️ **Mídia em bucket privado funciona**: signed URLs aplicadas tanto no provider Evolution API quanto no Evolution Go.
- 🔐 **Novo role `super_admin`**: operador da instalação tem acesso exclusivo ao painel `/settings/admin` (SMTP, Storage, Auth Providers, OpenAI, Channels, Inbound Email). Migration automática promove o usuário bootstrap em instalações existentes e revoga seus tokens ativos para forçar relogin com o novo role.
- 🧪 **E2E Playwright** validando o pipeline de gravação de áudio com microfone fake — ciclo de feedback caiu de 10min de deploy para 5s local.
- 🛠️ **`make setup` determinístico**: idempotência total nas migrations dos serviços Rails resolve a race condition com o `evo-bot-runtime` Go core na criação da tabela `users`.

### Added

- **Role `super_admin`** no `evo-auth-service-community` — installation-level operator. Detém todas as permissões do `account_owner` mais `installation_configs.manage` (acesso ao painel `/settings/admin`). Atribuído automaticamente ao usuário do setup wizard. PROD existente recebe via `db:migrate` (promove `User.order(:created_at).first`).
- **`Role::ADMIN_ROLE_KEYS` constant** no CRM — centraliza `%w[account_owner super_admin]`, adotada por mailers de admin e finders. Antes a lista estava hardcoded em quatro lugares e excluía `super_admin`, causando comportamento inconsistente em bypasses de admin.
- **Tabela `user_tours`** no auth-service — persistência do estado de onboarding tour por usuário.
- **Suite E2E de gravação de áudio** no frontend — Playwright + Chromium com fake media stream. `e2e/audio-recording.spec.ts` valida que `recordPttOgg` produz blob `audio/ogg` com magic bytes `OggS` em ambiente real de browser.
- **Componente `MessageVideo`** no frontend — render inline com `<video controls preload="metadata" playsInline>`, fallback para tile de download quando codec não suportado.
- **Aba "Automation" no Edit Stage Modal** (EVO-989, frontend) + **`Pipelines::StageAutomationService`** (EVO-989, CRM) — regras `trigger → action` por estágio do pipeline.

### Changed

- **WhatsApp Cloud — gravação de áudio: FFmpeg WASM → `opus-recorder`**. Saga completa documentada em `evo-ai-frontend-community/CHANGELOG.md`. Resumo: a Cloud API exige OGG/Opus PTT; a primeira solução tentou converter webm → ogg no browser via FFmpeg WASM, mas as 4 versões testadas falharam por motivos arquiteturais distintos (SharedArrayBuffer, worker 0-byte no npm, fetch incondicional de worker no wrapper). Substituído por `opus-recorder@8.0.5`, que captura PCM cru e codifica direto em OGG/Opus via `libopusenc` — sem reencode, sem requisitos de cross-origin isolation, sem viagem ao servidor.
- **Mídia em bucket S3 privado** (CRM): `generate_direct_s3_url` substituído por `presigned_url` em `whatsapp/providers/evolution_go_service.rb` e `whatsapp/providers/evolution_service.rb`. Antes a URL pública direta retornava 404 quando o bucket era privado (Cloudflare R2, S3 com ACL privada).
- **Conversation list — preload de `pipeline_items`**: `ConversationFinder#build_conversations_query` mantinha preload mínimo, então o chip de pipeline na listagem só aparecia depois de tagear manualmente. Adicionado `pipeline_items: [:pipeline, :pipeline_stage]` ao preload.
- **Admin Settings UX no frontend**: "Social Login" renomeado para "Authentication Providers" (refletindo OAuth genérico, não só redes sociais), aba Twitter escondida (provider deprecado), banners de aviso "configuração via env" em SMTP/Storage para deixar claro que mudanças na UI não persistem em PROD.
- **CI**: workflow `validate-compose` e `lint-dockerfiles` agora rodam em PRs contra `develop` (não só `main`). (#59)
- **Submódulos**: bumps coordenados ao longo da janela do rc2:
  - `evo-ai-crm-community`: 19 PRs/commits (automation rules EVO-989, navigation EVO-1007, idempotent migrations, EvoGo fixes ponta a ponta, contact import, super_admin RBAC, signed URLs S3, etc.)
  - `evo-ai-frontend-community`: 11+ PRs/commits (opus-recorder, vídeo inline, automation UI, role select, team members, brand colors, admin settings UX, e2e Playwright, etc.)
  - `evo-auth-service-community`: super_admin role + migration de upgrade automático com revocation de tokens, fix de password forwarding na criação de user, idempotência total no init_schema, tabela user_tours
  - `evo-ai-processor-community`: `python -m` para alembic/uvicorn + idempotência
  - Demais submódulos: ajustes de CI

### Fixed

#### Setup / Docker / Orquestração
- **`Makefile` — sequência de setup do banco**: `make setup` agora cria o DB no CRM, faz `db:schema:load` (carrega o schema mestre, incluindo todas as tabelas que o auth-service usa), marca migrations do auth como aplicadas via `rails runner` com `.sort` determinístico e `rescue ActiveRecord::RecordNotUnique` específico, e só então faz `db:seed` no CRM seguido do auth. Sem isso, `make setup` em fresh install falhava com `PG::UndefinedTable: roles`. (cherry-pick do PR #69 — autoria de @andersonlemesc preservada)
- **`init_schema` do auth-service totalmente idempotente** — race condition entre o setup do auth-service e o `evo-bot-runtime` Go core (que cria uma tabela `users` mínima ao subir) fazia `init_schema` falhar com `PG::DuplicateTable` quando o Go vencia a corrida. Reescrito com `if_not_exists: true` em todos `create_table`/`add_index` e helper `add_fk_if_missing` para foreign keys.
- **Docker — `auth_storage`**: substituído volume nomeado por bind mount, corrigindo `permission denied` ao gravar arquivos no serviço de autenticação. Bind mount estendido também para o `sidekiq` com `mkdir` defensivo no entrypoint. (#65, #72)
- **Docker — Alpine compat**: trocado `bash -c` por `sh -c` em scripts internos para compatibilidade com imagens Alpine. (#31)
- **Docker — healthcheck**: corrigido path do healthcheck do `evo-core`. (#26)
- **Env validation (EVO-985)**: bloqueio de `BACKEND_URL` / `FRONTEND_URL` apontando para `localhost` em produção — falha rápida no boot ao invés de servir URLs inválidas para clientes externos. (#75)
- **Submodules**: retargeting de SHAs órfãos para branches públicas (`develop` / `main`). Eliminado erro de checkout no CI causado por SHAs perdidos.

#### Mídia / Chat
- **Áudio WhatsApp Cloud não chegava ao destinatário** — a Meta rejeita `audio/webm` como mensagem de voz. Resolvido pela migração para `opus-recorder` (ver Changed acima).
- **Vídeo aparecia como anexo "Baixar arquivo"** — `MessageBubble` caía no fallback genérico. Novo `MessageVideo` com player nativo.
- **Mídia em bucket privado retornava 404** — signed URLs aplicadas em ambos os providers (ver Changed).

#### RBAC
- **`super_admin` ignorado por bypasses do CRM** — listas hardcoded de roles administrativas filtravam só `account_owner`. `User#administrator?` e `Role::ADMIN_ROLE_KEYS` consolidaram o reconhecimento; sem isso, super_admin via lista de conversas vazia, mailers de admin não chegavam, etc.

#### Estabilidade de API (CRM, do ciclo `develop`)
- **`PATCH /api/v1/pipelines/:id/pipeline_items/:id/update_custom_fields`** estourava `NoMethodError` (before_action ignorando a action). (#32)
- **`POST /api/v1/contacts/:id/companies`** estourava `NoMethodError` em `must_belong_to_same_account`. (#34)
- **`POST/DELETE /api/v1/contacts/:id/companies`** retornava 500 em violação de regra de negócio (kwargs incompatíveis no `error_response`). (#35)
- **`/api/v1/agents/*`** retornava 500/Unauthorized (request.headers não encaminhado, current_user usado como argumento posicional errado). (#33)
- **`GET /api/v1/oauth/applications`** retornava array em vez de envelope padrão, quebrando a tela de OAuth Apps. (#36)
- **EVO-1000** — `POST /api/v1/team_members` retornava 401 para todo UUID válido (`map(&:to_i)` em PK UUID). (#24)

#### Evolution Go (EvoGo) — fluxo WhatsApp ponta a ponta (#22)
- Conversation routing por LID (sem mais conversas duplicadas a cada envio outgoing)
- Sender type correto, contact lookup via inbox joins, reabertura de pendentes
- Mídia salva sem arquivo (3 problemas: ActiveStorage commit em Sidekiq, `mediaUrl` aninhado, base64 inline para EvoGo sem S3)
- Áudio sem waveform (definições duplicadas de `configure_audio_metadata`)
- ActionCable broadcast em token vazio

#### Auth-service
- **`POST /api/v1/users` retornava 500 sem `role`** — fallback para `agent` em vez de `Role.find_by!(key: nil)`. (#9)
- **Login sempre 401 para usuários criados pela UI** — `password` não era encaminhado para `AgentBuilder.new`, então cada agente nascia com hash Argon2 aleatório que ninguém conhecia. (commit `917c366`)
- **Migration `add_message_template_permissions_to_account_owner`** falhava em fresh install com `PG::UndefinedTable: roles` por ordem de timestamp. Adicionado guard `table_exists?(:roles)`.
- **EVO-971**: gate de `/setup/status` agora considera bootstrap, não só licensing. (#8)
- **EVO-967**: agentes convidados são auto-confirmados; lookup de role tolera role inexistente sem 500. (#3)

### Notas para upgrade de PROD existente

- ⚠️ **`db:migrate` do `evo-auth-service-community` revoga tokens ativos do operador bootstrap** ao promovê-lo para `super_admin`. O operador será forçado a fazer logout/login uma vez na primeira requisição após o upgrade. Isso é esperado e necessário para o JWT refletir o novo role.
- ⚠️ **Outros usuários `account_owner` perdem acesso ao painel `/settings/admin`** — comportamento intencional (panel reservado a operação de instalação, não a gestão de conta). Se você criou múltiplos `account_owner` na rc1 e quer que mais de um deles tenha acesso ao admin, terá de promovê-los manualmente ao novo role via console (`User.find(...).user_roles.create!(role: Role.find_by!(key: 'super_admin'))`).
- ✅ **Mídia em bucket S3 privado**: o fix de signed URL é puramente backend e ativa automaticamente após o upgrade do CRM. Não há ação de migração necessária.
- ✅ **Áudio WhatsApp Cloud**: ativo automaticamente após o upgrade do frontend. Hard refresh do browser é necessário para invalidar o bundle antigo.
- 📝 **CHANGELOG por submódulo** tem o detalhamento técnico completo de cada item — esta seção é o resumo guarda-chuva.

## [v1.0.0-rc1] - 2026-04-24

### Added

- Primeiro release candidate público do **CRM Community**.
- Composição inicial de 7 submódulos via Docker Compose:
  - `evo-ai-crm-community`
  - `evo-ai-frontend-community`
  - `evo-ai-core-service-community`
  - `evo-ai-processor-community`
  - `evo-auth-service-community`
  - `evo-bot-runtime`
  - `evolution-api`, `evolution-go` (provedores WhatsApp)
- `Makefile` com targets de setup, seed, dashboard.
- Scripts de bootstrap (`setup.sh`) e exemplos de `docker-compose` (dev, prod-test, swarm).
- Templates de `.env` e licença `Apache 2.0`.

---

[Unreleased]: https://github.com/evolution-foundation/evo-crm-community/compare/v1.0.0-rc3...HEAD
[v1.0.0-rc3]: https://github.com/evolution-foundation/evo-crm-community/compare/v1.0.0-rc2...v1.0.0-rc3
[v1.0.0-rc2]: https://github.com/evolution-foundation/evo-crm-community/compare/v1.0.0-rc1...v1.0.0-rc2
[v1.0.0-rc1]: https://github.com/evolution-foundation/evo-crm-community/releases/tag/v1.0.0-rc1
