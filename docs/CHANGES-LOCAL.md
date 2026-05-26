# CHANGES-LOCAL.md

Registro de customizações locais aplicadas aos submodules e ao orquestrador.
Atualizar a cada sessão de desenvolvimento que modifique arquivos fora do upstream puro.

Formato de entrada:
```
## [data] Descrição curta
- Arquivo: `caminho/relativo`
- Motivo: por que foi necessário
- Conflito esperado no sync: sim/não + detalhes
- Branch no fork: nome da branch
```

---

## [2026-05-25] Evolution Go proxy no Configurar Canal

### Submodule `evo-ai-frontend-community` → fork `Luizcc87/evo-ai-frontend-community`

- **Arquivos**: `src/components/channels/settings/ConfigurationForm.tsx`, `src/components/channels/forms/whatsapp/EvolutionGoForm.tsx`, `src/hooks/channels/useChannelForm.ts`, `src/hooks/channels/useChannelSubmission.ts`, `src/hooks/channels/useChannelValidation.ts`, `src/services/channels/evolutionGoService.ts`, `src/types/channels/inbox.ts` `[PATCH]`
  - Motivo: Exibir o painel de status/configuração de proxy em canais Evolution Go já criados e enviar proxy durante a criação da instância.
  - Conflito no sync: médio — áreas de formulário/criação de canais WhatsApp Evolution Go.
  - Branch: `develop`

### Submodule `evo-ai-crm-community` → fork `Luizcc87/evo-ai-crm-community`

- **Arquivo**: `app/controllers/api/v1/evolution_go/authorizations_controller.rb` `[PATCH]`
  - Motivo: Aplicar proxy na Evolution Go logo após criar a instância quando `proxy_settings.enabled` vier do painel.
  - Conflito no sync: médio — fluxo de criação de instância Evolution Go.
  - Branch: `develop`

### Imagens Docker publicadas

- `lc1868/evo-ai-crm-community:v1.0.0-rc4-proxyconfig` e `latest`
  - Plataformas: `linux/amd64`, `linux/arm64`
  - Digest: `sha256:651d56b4057c811373b6a1a220679de11b53535f58e58eedb5c6d4dd3b73d722`
- `lc1868/evo-ai-frontend-community:v1.0.0-rc4-proxyconfig` e `latest`
  - Plataformas: `linux/amd64`, `linux/arm64`
  - Digest: `sha256:afed6f0a18a98ad91f18fa6803da73572aa6884a9f95670ed65eedc5a7ed7de9`
- `lc1868/evo-ai-frontend-community:v1.0.0-rc4-proxyconfig2` e `latest`
  - Motivo: exibir status `configured` como `Configurado` no painel de proxy.
  - Plataformas: `linux/amd64`, `linux/arm64`
  - Digest: `sha256:345faa7cf97ad8300493665deb10965d06b86fe989b16442609f3a6cd664cbf6`
- `docs/local/stack-swarm-vps.yaml` atualizado para usar as tags versionadas acima nos services `evo_crm`, `evo_crm_sidekiq` e `evo_frontend`.

---

## [2026-05-26] Status configurado para proxy Evolution Go

### Submodule `evolution-go` → fork `Luizcc87/evolution-go`

- **Arquivo**: `pkg/instance/service/instance_service.go` `[PATCH]`
  - Motivo: Quando uma instância tem `proxyAddress`, mas ainda não recebeu o primeiro health check, retornar `status: configured` em vez de `inactive`.
  - Conflito no sync: baixo — lógica localizada no status/configuração de proxy.
  - Branch: `release/lc1868-proxy-health`

### Submodule `evo-ai-frontend-community` → fork `Luizcc87/evo-ai-frontend-community`

- **Arquivo**: `src/components/channels/forms/whatsapp/ProxyPanel.tsx` `[PATCH]`
  - Motivo: Exibir `configured` como `Configurado` no painel de proxy.
  - Conflito no sync: baixo — enum/rótulo do painel de proxy.
  - Branch: `develop`

### Imagens Docker publicadas

- `lc1868/evolution-go:v0.7.1-proxy-status` e `latest`
  - Plataformas: `linux/amd64`, `linux/arm64`
  - Digest: `sha256:dab3b4b46f34d2d0cc00129ced80b7a5fdba3dd119003e42e28a973b21d29ba0`
- `lc1868/evo-ai-frontend-community:v1.0.0-rc4-proxyconfig2` e `latest`
  - Plataformas: `linux/amd64`, `linux/arm64`
  - Digest: `sha256:345faa7cf97ad8300493665deb10965d06b86fe989b16442609f3a6cd664cbf6`

---

## [2026-05-21] Infraestrutura inicial do fork orquestrador

### Orquestrador (`Luizcc87/evo-crm-community`)

- **Arquivo**: `scripts/docker-publish.sh`
  - Motivo: Script para build e push multi-arch (amd64+arm64) das 9 imagens sob `lc1868/*` no Docker Hub. Usa `docker buildx` com builder `evo-multiarch`.
  - Conflito no sync: não — arquivo novo, não existe no upstream.
  - Branch: `develop`

- **Arquivo**: `docs/SYNC.md`
  - Motivo: Procedimento documentado para sync periódico com `EvolutionAPI/evo-crm-community` upstream, incluindo checklist de conflitos e smoke tests.
  - Conflito no sync: não — arquivo novo.
  - Branch: `develop`

- **Arquivo**: `.github/dependabot.yml`
  - Motivo: Monitoramento automático de atualizações em gitsubmodules e imagens Docker.
  - Conflito no sync: baixo — upstream não tem dependabot configurado para submodules.
  - Branch: `develop`

- **Arquivo**: `docs/local/stack-swarm-vps.yaml`
  - Motivo: Stack de produção completa para Portainer Swarm (VPS Oracle Cloud aarch64). Corrigido: imagens `lc1868/*`, comando `sh` em vez de `bash` (alpine), `wss://` para WebSocket, todas as env vars de produção.
  - Conflito no sync: não — arquivo local, não existe no upstream.
  - Branch: `develop` (local)

---

## [2026-05-21] Fix CRLF — evo-auth-service-community

### Submodule `evo-auth-service-community` → fork `Luizcc87/evo-auth-service-community`

- **Arquivo**: `Dockerfile`
  - Motivo: Windows checkouts introduzem CRLF em `bin/rails`, fazendo `__dir__` virar `__di__\r` e quebrando o boot do Rails. Adicionado `RUN find bin/ -type f | xargs sed -i 's/\r//' 2>/dev/null || true` após o `COPY . .`.
  - Conflito no sync: médio — linha nova na área de COPY. Resolver manualmente no merge.
  - Branch: `develop`

- **Arquivo**: `.gitattributes`
  - Motivo: Forçar LF em todos os arquivos e especialmente em `bin/*` para evitar corrupção CRLF em checkouts Windows futuros.
  - Conflito no sync: baixo — arquivo existia mas sem `* text=auto eol=lf`. Revisar no merge se upstream adicionar entradas conflitantes.
  - Branch: `develop`

---

## [2026-05-21] Fix CRLF + .gitattributes — evo-ai-crm-community

### Submodule `evo-ai-crm-community` → fork `Luizcc87/evo-ai-crm-community`

- **Arquivo**: `.gitattributes`
  - Motivo: Adicionar `* text=auto eol=lf` e `bin/* text eol=lf` para consistência com auth. CRM já tinha `dos2unix` no Dockerfile (stage final), mas o `.gitattributes` não tinha a regra global.
  - Conflito no sync: baixo.
  - Branch: `fix/crlf-gitattributes` (não mergeada em develop ainda)

---

## [2026-05-22] Fix WebSocket + CSP — evo-ai-frontend-community

### Submodule `evo-ai-frontend-community` → fork `Luizcc87/evo-ai-frontend-community`

- **Arquivo**: `docker-entrypoint.sh`
  - Motivo: Entrypoint original não logava os valores substituídos e silenciava falha de substituição. Melhorias: (1) fallback automático de `VITE_WS_URL` derivado de `VITE_API_URL` quando não definido; (2) substituição em `.js`, `.css` e `.html` (antes só `.js`); (3) logs runtime de todos os valores; (4) warning explícito se ainda sobrar `VITE_*_PLACEHOLDER` após substituição.
  - Conflito no sync: médio — arquivo modificado que existe no upstream. Revisar diff linha a linha no merge.
  - Branch: `develop`

- **Arquivo**: `nginx.conf`
  - Motivo: CSP bloqueava `static.cloudflareinsights.com` (analytics Cloudflare embutido no app). Adicionado `https://static.cloudflareinsights.com` ao `script-src` e `https://cloudflareinsights.com` ao `connect-src`.
  - Conflito no sync: médio — arquivo modificado que existe no upstream. CSP pode ser atualizado pelo upstream independentemente.
  - Branch: `develop`

---

## [2026-05-22] White-label runtime injection — evo-ai-frontend-community

### Submodule `evo-ai-frontend-community` → fork `Luizcc87/evo-ai-frontend-community`

- **Arquivo**: `src/branding/config.ts`
  - Motivo: Novo ponto único para identidade white-label no React, com placeholders runtime e fallbacks Evolution.
  - Conflito no sync: baixo — arquivo novo em diretório dedicado.
  - Branch: `develop`

- **Arquivo**: `docker-entrypoint.d/branding-entrypoint.sh`
  - Motivo: Novo script POSIX para substituir placeholders white-label em `.html` e `.js` no boot do container.
  - Conflito no sync: baixo — arquivo novo em diretório dedicado.
  - Branch: `develop`

- **Arquivo**: `docker-entrypoint.sh`
  - Motivo: Patch mínimo para chamar `branding-entrypoint.sh` ao final do entrypoint existente.
  - Conflito no sync: médio — arquivo upstream já modificado localmente; revisar no merge.
  - Branch: `develop`

- **Arquivo**: `Dockerfile`
  - Motivo: Copiar `docker-entrypoint.d/` para a imagem e aplicar permissão de execução nos scripts.
  - Conflito no sync: médio — arquivo upstream modificado na etapa de imagem final.
  - Branch: `develop`

- **Arquivo**: `index.html`
  - Motivo: Substituir `<title>` por `__APP_TITLE_PLACEHOLDER__` para runtime injection.
  - Conflito no sync: baixo — patch mínimo de uma linha.
  - Branch: `develop`

- **Arquivo**: `src/components/AppLogo.tsx`
  - Motivo: Consumir `brandingConfig.logoUrl` para logo customizada, preservando os SVGs claro/escuro como fallback padrão.
  - Conflito no sync: médio — componente existente do upstream.
  - Branch: `develop`

- **Arquivo**: `src/components/layout/components/Sidebar.tsx`
  - Motivo: Exibir `brandingConfig.appName` no rodapé da sidebar em vez de brand fixo de i18n.
  - Conflito no sync: médio — componente existente do upstream.
  - Branch: `develop`

- **Arquivo**: `src/pages/Setup/OnboardingPage.tsx`
  - Motivo: Remover alt hardcoded do logo para usar o default white-label do `AppLogo`.
  - Conflito no sync: baixo — patch mínimo.
  - Branch: `develop`

---

## [2026-05-22] White-label logo/favicon por URL — evo-ai-frontend-community

### Submodule `evo-ai-frontend-community` → fork `Luizcc87/evo-ai-frontend-community`

- **Arquivo**: `docker-entrypoint.d/branding-entrypoint.sh`
  - Motivo: Resolver precedência de branding em runtime: URL externa, depois `/branding/logo.svg` quando o volume local existir, e por fim `/logo.svg`.
  - Conflito no sync: baixo — arquivo local novo já introduzido pelo white-label.
  - Branch: `develop`

---

## [2026-05-20] Proxy health + logs no container — evolution-go

### Submodule `evolution-go` → fork `Luizcc87/evolution-go`

- **Arquivos**: `pkg/instance/service/instance_service.go`, `pkg/routes/routes.go`, `pkg/instance/handler/instance_handler.go`, `pkg/config/*`, `pkg/instance/model/instance_model.go`
  - Motivo: Adicionar monitor periódico de conectividade do proxy por instância, registrando logs no stdout do container (prefixo `[proxy-health]`) e expondo status via API.
  - Conflito no sync: médio — mudanças em core/service/handler e novos endpoints. Revisar ao atualizar para versões futuras do upstream.
  - Branch: `feat/proxy-health` (código) / `release/lc1868-proxy-health` (stack/documentação para deploy)

- **Arquivo**: `src/branding/config.ts`
  - Motivo: Centralizar `logoUrl` e `faviconUrl` e aplicar sincronização de favicon com fallback para `/favicon.svg`.
  - Conflito no sync: baixo — arquivo local novo em diretório dedicado.
  - Branch: `develop`

- **Arquivo**: `src/components/AppLogo.tsx`
  - Motivo: Manter `<img src>` para logo externa e fallback client-side para `/logo.svg` quando a URL configurada falhar.
  - Conflito no sync: médio — componente upstream já customizado localmente.
  - Branch: `develop`

### Orquestrador (`Luizcc87/evo-crm-community`)

- **Arquivo**: `docker-compose.yml`
  - Motivo: Montar `${BRANDING_ASSETS_PATH:-/dev/null}` em `/usr/share/nginx/html/branding` para assets locais opcionais.
  - Conflito no sync: médio — arquivo de infraestrutura do orquestrador com patch pequeno no serviço `evo-frontend`.
  - Branch: `develop`

- **Arquivo**: `.gitignore`
  - Motivo: Ignorar `branding/` para evitar commit de assets locais de clientes.
  - Conflito no sync: baixo — entrada simples no ignore do orquestrador.
  - Branch: `develop`

---

## [2026-05-22] Evo CRM White Label — rastreabilidade de patches upstream

### Legenda

- `[PATCH]` = arquivo upstream existente que recebeu modificação mínima e precisa de reaplicação procedural após sync.
- `[NOVO]` = arquivo novo isolado da camada white-label; upstream não depende de sobrescrita desse caminho.
- `[MONITOR]` = arquivo upstream/local já tocado no fork que deve ser revisado em sync, mas cuja reaplicação nesta feature não depende de patch dedicado.

### [PATCH] Frontend (`evo-ai-frontend-community`)

- `[PATCH]` **Arquivo**: `docker-entrypoint.sh`
  - Escopo: submodule `evo-ai-frontend-community`
  - Localização aproximada: final do arquivo, imediatamente antes de `exec "$@"`
  - Modificação: 1 linha para chamar `sh /docker-entrypoint.d/branding-entrypoint.sh`
  - Motivo: manter a lógica white-label isolada em arquivo novo e reduzir conflito com upstream ao menor patch possível.
  - Data: `2026-05-22`
  - Patch relacionado: `docs/patches/evo-frontend/0001-branding-entrypoint-call.patch`
  - Reaplicação esperada: `git -C evo-ai-frontend-community am ../docs/patches/evo-frontend/0001-branding-entrypoint-call.patch`

- `[PATCH]` **Arquivo**: `index.html`
  - Escopo: submodule `evo-ai-frontend-community`
  - Localização aproximada: `<head>`, linhas do `<link rel="icon">` e `<title>`
  - Modificação: troca de favicon fixo e título fixo por placeholders `__APP_FAVICON_URL_PLACEHOLDER__` e `__APP_TITLE_PLACEHOLDER__`
  - Motivo: permitir runtime injection de identidade sem rebuild da imagem.
  - Data: `2026-05-22`
  - Patch relacionado: `docs/patches/evo-frontend/0002-runtime-branding-placeholders.patch`
  - Reaplicação esperada: `git -C evo-ai-frontend-community am ../docs/patches/evo-frontend/0002-runtime-branding-placeholders.patch`

### [PATCH] Auth (`evo-auth-service-community`)

- `[PATCH]` **Arquivo**: `db/seeds.rb`
  - Escopo: submodule `evo-auth-service-community`
  - Localização aproximada: final do arquivo, após a mensagem sobre `/setup`
  - Modificação: adição de `require_relative 'seeds/white_label'`
  - Motivo: manter toda a lógica white-label do seed em arquivo novo e preservar o entrypoint upstream com patch mínimo.
  - Data: `2026-05-22`
  - Patch relacionado: `docs/patches/evo-auth/0001-seeds-white-label-require.patch`
  - Reaplicação esperada: `git -C evo-auth-service-community am ../docs/patches/evo-auth/0001-seeds-white-label-require.patch`

### [NOVO] White-label isolado

- `[NOVO]` **Arquivo**: `evo-ai-frontend-community/docker-entrypoint.d/branding-entrypoint.sh`
  - Finalidade: runtime injection de `APP_NAME`, `APP_TITLE`, `APP_LOGO_URL` e `APP_FAVICON_URL`
  - Motivo de baixo risco upstream: diretório novo e dedicado, sem sobrescrever arquivo upstream.

- `[NOVO]` **Arquivo**: `evo-ai-frontend-community/src/branding/config.ts`
  - Finalidade: centralizar `brandingConfig`, placeholders runtime e sincronização de favicon
  - Motivo de baixo risco upstream: diretório novo e dedicado à feature.

- `[NOVO]` **Arquivo**: `evo-auth-service-community/db/seeds/white_label.rb`
  - Finalidade: seed isolado para `ACCOUNT_NAME`, `SUPPORT_EMAIL`, `APP_DOMAIN` e `ACCOUNT_LOCALE`
  - Motivo de baixo risco upstream: arquivo novo fora do seed principal upstream.

- `[NOVO]` **Arquivo**: `docs/patches/evo-frontend/`
  - Finalidade: armazenar patch series reaplicáveis do frontend via `git am`
  - Motivo de baixo risco upstream: artefato do fork/orquestrador, não do submodule.

- `[NOVO]` **Arquivo**: `docs/patches/evo-auth/`
  - Finalidade: armazenar patch series reaplicáveis do auth via `git am`
  - Motivo de baixo risco upstream: artefato do fork/orquestrador, não do submodule.

### [MONITOR] Sync futuro

- `[MONITOR]` **Arquivo**: `evo-ai-frontend-community/Dockerfile`
  - Motivo: recebeu suporte ao diretório `docker-entrypoint.d/`; revisar no próximo sync se upstream alterar a etapa final da imagem.

- `[MONITOR]` **Arquivo**: `evo-ai-frontend-community/src/components/AppLogo.tsx`
  - Motivo: componente upstream adaptado para consumir branding runtime; revisar conflitos se upstream alterar o header/sidebar.

- `[MONITOR]` **Arquivo**: `evo-ai-frontend-community/src/components/layout/components/Sidebar.tsx`
  - Motivo: exibe `brandingConfig.appName`; alteração funcional pequena, mas em componente frequentemente tocado por upstream.

- `[MONITOR]` **Arquivo**: `docker-compose.yml`
  - Motivo: inclui env vars e mount opcional de branding; revisar bloco do serviço `evo-frontend` após sync do orquestrador.

- `[MONITOR]` **Arquivo**: `.env.example`
  - Motivo: contém a seção `WHITE LABEL`; revisar quando upstream adicionar ou renomear variáveis globais.

- `[MONITOR]` **Arquivo**: `.gitignore`
  - Motivo: entrada `branding/` é simples, mas deve ser preservada caso upstream reordene regras do arquivo.

---

## [2026-05-24] Fix CSP local dev + seed de admin de desenvolvimento

### Submodule `evo-ai-frontend-community` → fork `Luizcc87/evo-ai-frontend-community`

- **Arquivo**: `nginx.conf` `[MONITOR]`
  - Motivo: CSP bloqueava `http://localhost:*` em desenvolvimento local. `connect-src` só permitia `https:`, causando `ERR_NETWORK` em todas as chamadas para serviços locais no browser.
  - Fix: adicionado `http://localhost:3000 http://localhost:3001 http://localhost:5555 http://localhost:8000` ao `connect-src`.
  - Conflito no sync: médio — arquivo já com patch anterior de CSP do Cloudflare.
  - Branch: `develop`

### Submodule `evo-auth-service-community` → fork `Luizcc87/evo-auth-service-community`

- **Arquivo**: `db/seeds/dev_admin.rb` `[NOVO]`
  - Motivo: após seed do CRM o setup wizard fica bloqueado. Usuário admin de dev precisa ser criado via seed do auth com role `Account Owner` no banco compartilhado (tabela `user_roles`).
  - Variáveis: `DEV_ADMIN_EMAIL` (default: `admin@evocrm.local`), `DEV_ADMIN_PASSWORD` (default: `Admin@12345`), `DEV_ADMIN_NAME`.
  - Skippado automaticamente em `Rails.env.production?`.
  - Conflito no sync: não — arquivo novo.
  - Branch: `develop`

- **Arquivo**: `db/seeds.rb` `[PATCH]`
  - Motivo: require do `dev_admin` seed ao final.
  - Conflito no sync: baixo — +1 linha ao final do arquivo.
  - Branch: `develop`

---

## [2026-05-25] Sync upstream v1.0.0-rc4

### Todos os submodules core atualizados para v1.0.0-rc4

**evo-ai-crm-community** `v1.0.0-rc2 → v1.0.0-rc4`
- Reset para rc4 (sem customizações exclusivas — sync_whatsapp_subscription já absorvido upstream)
- `[NOVO]` `app/controllers/api/v1/evolution_go/proxy_controller.rb`: endpoint GET/POST/DELETE para proxy health e configuração da instância evolution_go. Rota adicionada em `config/routes.rb` dentro do bloco `evolution_go`.

**evo-ai-frontend-community** `v1.0.0-rc2 → v1.0.0-rc4`
- Cherry-pick do commit `feat(white-label)` sobre o rc4 (sem conflito direto)
- `nginx.conf` `[RESOLVE]`: removido `cloudflareinsights.com` e `http://localhost:*` do CSP (decisão: seguir rc4 — não usamos Cloudflare Analytics)
- `docker-entrypoint.sh`: linha de execução do `branding-entrypoint.sh` preservada após cherry-pick
- `[NOVO]` `src/components/channels/forms/whatsapp/ProxyPanel.tsx`: UI para visualização e configuração de proxy evolution_go

**evo-auth-service-community** `v1.0.0-rc2 → v1.0.0-rc4`
- Rebase limpo — commit white-label (`feat(white-label): configurable identity seed`) reaplicado sobre rc4 sem conflito
- ⚠️ Migração `20260518140000_invalidate_plaintext_backup_codes`: usuários com MFA ativo antes do rc4 precisarão re-configurar TOTP. Rodar `db:migrate` no próximo deploy.

**evo-ai-core-service-community** `v1.0.0-rc3 → v1.0.0-rc4`
- Reset direto para rc4 (sem customizações locais — commit extra era do upstream EvolutionAPI já contido no rc4)

**evo-ai-processor-community** `v1.0.0-rc3 → v1.0.0-rc4`
- Reset direto para rc4 (todos os fixes locais — stage_name, link_product, knowledge_nexus — já absorvidos upstream)

**evo-bot-runtime**: mantido em `v1.0.0-rc3` (upstream não emitiu rc4 para este serviço)

### Conflitos resolvidos
| Arquivo | Resolução |
|---|---|
| `evo-ai-frontend-community/nginx.conf` | keep-upstream (sem cloudflare, sem localhost) |
| `evo-ai-frontend-community/docker-entrypoint.sh` | keep-local (linha branding-entrypoint preservada via cherry-pick) |

## Pendências

- [ ] Rodar `db:migrate` nos containers auth + crm no próximo deploy (novas migrations rc4)
- [ ] Testar MFA re-setup após migration `invalidate_plaintext_backup_codes`
- [ ] Merge de `fix/crlf-gitattributes` em `develop` do fork `evo-ai-crm-community`
- [ ] Abrir PRs dos forks para o upstream quando as correções forem genéricas (CRLF fix é candidato)
- [ ] Revisar `docs/local/stack-swarm-vps.yaml` e commitar versão atualizada no orquestrador

---

## [2026-05-24] Documentação e Stack do evo-flow (Orquestrador de Jornadas)

### Orquestrador (`Luizcc87/evo-crm-community`)

- **Arquivo**: `docker-compose.evo-flow.yml` `[NOVO]`
  - Motivo: Isolar os serviços de campanha (`evo-flow`, `temporal`, `clickhouse`, `kafka`, `zookeeper`) do compose principal, permitindo rodá-los apenas quando necessário no ambiente local.
  - Conflito no sync: não — arquivo novo e local.
  - Branch: `develop`

- **Arquivo**: `docs/local/EVO_FLOW_SETUP.md` `[NOVO]`
  - Motivo: Documentação de como inicializar os serviços do `evo-flow` localmente e instruções para deploy via Swarm/Portainer.
  - Conflito no sync: não — diretório `docs/local/` é exclusivo do fork local.
  - Branch: `develop`
