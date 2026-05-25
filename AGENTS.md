# AGENTS.md

Guia operacional para agentes de IA (Claude Code, Cursor, Copilot, Windsurf, etc.)
trabalhando neste fork do Evo CRM Community.

---

## Contexto do repositório

Este é um **fork orquestrador** de `evolution-foundation/evo-crm-community`.
Contém 6 submodules de serviço + 3 companion submodules, cada um com seu próprio fork em `Luizcc87/*`.

- `origin` → `https://github.com/Luizcc87/evo-crm-community.git` (seu fork — escrita)
- `upstream` → `https://github.com/evolution-foundation/evo-crm-community.git` (origem — só leitura)

Submodules de serviço têm forks próprios em `Luizcc87/<nome>` com remote `fork` para escrita.
Ver `.agent/skills/evo-upstream-sync/SKILL.md` para procedimento completo de sync com upstream.

---

## Antes de qualquer edição

1. Rode `git status` no orquestrador e no submodule afetado.
2. **Se o submodule afetado for `evo-ai-crm-community`, `evo-ai-frontend-community` ou `evo-auth-service-community`**, verifique se há nova release upstream antes de editar:
   ```powershell
   .\.agent\skills\evo-upstream-sync\scripts\check-releases.ps1 -SkipFetch
   ```
   Se qualquer submodule mostrar `🆕 YES` → **pausar** → rodar sync → retomar edição.
3. Identifique a qual das três categorias a mudança pertence:
   - **Orquestrador** — arquivos na raiz ou em `docs/`, `scripts/`, `deploy/`, `nginx/`
   - **Submodule** — arquivos dentro de `evo-*/`, `evolution-*/`, `evo-nexus/`
   - **Local/deploy** — arquivos em `docs/local/` e `deploy/local/` (nunca sobem para upstream)
4. Nunca edite `main` de um submodule diretamente — use branch `develop` ou `custom/`.
5. Não misture commits de scopes diferentes no mesmo commit.
6. Se o arquivo que vai editar está no `risk-registry.md` → registrar a mudança em `docs/CHANGES-LOCAL.md` na mesma sessão.

---

## Regras de submodules

- Customizações ficam em branch `develop` ou `custom/production-fixes` no fork do submodule.
- `main` do fork é reservado para sync com upstream — não commitar customizações lá.
- Prefixo `custom:` nos commits de customização:
  ```
  custom: fix CRLF in bin/ scripts on Windows checkout
  custom: add runtime VITE_WS_URL fallback in entrypoint
  ```
- Isso permite listar todas as customizações com `git log --grep="^custom:"`.
- Ao fazer sync upstream → merge `upstream/main` em `main` do fork → cherry-pick ou merge da branch `custom/` sobre o novo `main`.

---

## Regras de arquivos locais

- `docs/local/` — documentação de deploy e operação local. Nunca vai para upstream.
- `deploy/local/` — overlays de docker-compose para desenvolvimento local.
- `docs/CHANGES-LOCAL.md` — **registrar toda customização feita em submodules**. Atualizar a cada sessão.
- Arquivos que são cópia de referência do upstream: sufixo `.upstream.yaml` / `.upstream.conf`.
- Arquivos customizados para produção: sufixo `.local.yaml` / `.local.conf` quando necessário.

---

## Regras de imagens Docker

- Toda imagem publicada deve sair em `linux/amd64` e `linux/arm64`.
- Usar builder `evo-multiarch` via `docker buildx`.
- Registry: `lc1868/<nome-do-servico>:<versão>` + tag `latest`.
- Script: `scripts/docker-publish.sh --version <tag> [--image <nome>]`
- Nunca publicar imagem sem antes testar o build localmente com `--dry-run`.
- Tag de versão segue o upstream: `1.0.0-rc3`, `1.0.0-rc4`, etc.

---

## Regras de deploy (Swarm / Portainer)

- Stack de produção: `docs/local/stack-swarm-vps.yaml`
- Não alterar nomes de services no stack — Traefik e Portainer dependem deles.
- Imagens Alpine não têm `bash` — usar `sh` em `command:`.
- WebSocket requer `wss://` (não `https://`) no `VITE_WS_URL`.
- Após rebuild de imagem: forçar pull no Swarm:
  ```bash
  docker service update --force --image lc1868/<serviço>:latest evo-crm_<serviço>
  ```
- Verificar logs do container após redeploy para confirmar substituição de variáveis runtime.

---

## Regras de line endings (Windows)

- Todos os repositórios têm `.gitattributes` com `* text=auto eol=lf`.
- Dockerfiles de serviços Ruby incluem `RUN find bin/ -type f | xargs sed -i 's/\r//' 2>/dev/null || true` para strip CRLF em runtime.
- Se aparecer `__di__` em vez de `__dir__` nos logs do Rails → CRLF em `bin/rails`. Fix: rebuild da imagem.
- Não commitar arquivos com CRLF — configurar `git config core.autocrlf input` localmente.

---

## Fluxo de trabalho recomendado

```
1. Verificar git status (orquestrador + submodule afetado)
2. Criar/usar branch adequada (develop ou custom/)
3. Editar apenas o escopo necessário
4. Commitar com prefixo correto (fix:, custom:, chore:, docs:)
5. Atualizar docs/CHANGES-LOCAL.md se arquivo de submodule foi modificado
6. Rebuild + push da imagem se Dockerfile ou entrypoint foram alterados
7. Redeploy do serviço no Swarm
8. Verificar logs do container
```

---

## Referências rápidas

| Documento | Propósito |
|---|---|
| `CLAUDE.md` | Comandos, arquitetura, variáveis críticas — leitura obrigatória para contexto inicial |
| `CONTEXT.md` | Remotes, convenção de arquivos, topologia de deploy |
| `.agent/skills/evo-upstream-sync/SKILL.md` | Procedimento completo de sync com upstream (releases, análise, merge, validação) |
| `.agent/skills/evo-upstream-sync/scripts/check-releases.ps1` | Verifica se há nova release em todos os submodules |
| `.agent/skills/evo-upstream-sync/references/risk-registry.md` | Arquivos customizados por submodule — risco de conflito por arquivo |
| `.agent/skills/evo-upstream-sync/references/agent-integration.md` | Quando cada agente evo-* deve invocar o sync |
| `.agent/skills/evo-commit-submodules/SKILL.md` | Mapeia mudanças por repositório e commita/pusha para cada fork |
| `.agent/skills/evo-commit-submodules/scripts/scan-changes.ps1` | Lista arquivos modificados/untracked em todos os submodules |
| `docs/CHANGES-LOCAL.md` | Registro de todas as customizações locais em submodules |
| `docs/local/stack-swarm-vps.yaml` | Stack de produção atual (Portainer Swarm) |
| `docs/local/IMAGE_REGISTRY_MAP.md` | Mapeamento de imagens originais → `lc1868/*` |
