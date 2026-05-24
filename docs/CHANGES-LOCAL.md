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

## Pendências

- [ ] Merge de `fix/crlf-gitattributes` em `develop` do fork `evo-ai-crm-community`
- [ ] Abrir PRs dos forks para o upstream quando as correções forem genéricas (CRLF fix é candidato)
- [ ] Revisar `docs/local/stack-swarm-vps.yaml` e commitar versão atualizada no orquestrador
