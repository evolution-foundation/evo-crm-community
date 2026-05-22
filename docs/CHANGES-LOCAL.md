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

## Pendências

- [ ] Merge de `fix/crlf-gitattributes` em `develop` do fork `evo-ai-crm-community`
- [ ] Abrir PRs dos forks para o upstream quando as correções forem genéricas (CRLF fix é candidato)
- [ ] Revisar `docs/local/stack-swarm-vps.yaml` e commitar versão atualizada no orquestrador
