---
name: evo-docker-publish
description: Use when user asks to "publicar imagens", "build docker", "push para docker hub", "atualizar imagens", "build e push", "rebuild image", "publish image". Orchestrates pre-flight checks, multi-arch build, push to lc1868/* on Docker Hub, and post-publish validation for all Evo CRM Community services.
---

# Evo Docker Publish

Orquestra build multi-arch (amd64 + arm64) e push para `lc1868/*` no Docker Hub.
Source of truth para quais imagens buildar: `docs/local/IMAGE_REGISTRY_MAP.md`.

---

## Registry map — resumo rápido

| Serviço | Imagem | Tag padrão | Build? |
|---|---|---|---|
| Auth | `lc1868/evo-auth-service-community` | `v1.0.0-rc4` | ✓ buildx |
| CRM | `lc1868/evo-ai-crm-community` | `v1.0.0-rc4` | ✓ buildx |
| Frontend | `lc1868/evo-ai-frontend-community` | `v1.0.0-rc4` | ✓ buildx |
| Processor | `lc1868/evo-ai-processor-community` | `v1.0.0-rc4` | ✓ buildx |
| Core (Go) | `lc1868/evo-ai-core-service-community` | `v1.0.0-rc4` | ✓ buildx |
| Bot Runtime | `lc1868/evo-bot-runtime` | `v1.0.0-rc4` | ✓ buildx |
| Evolution GO | `lc1868/evolution-go` | `v0.7.1` | ✓ buildx |
| Gateway (nginx) | `lc1868/evo-crm-gateway` | `1.0.0` | ✓ buildx |
| evo-flow | build local apenas | — | compose build |
| clickhouse / kafka / temporal | upstream oficial | — | ✗ não buildar |

> Regra: qualquer serviço com customização local **deve** usar `lc1868/*`.
> Consultar `docs/local/IMAGE_REGISTRY_MAP.md` antes de mudar qualquer `image:` no compose.

---

## Step 1 — Pre-flight

```powershell
.\.agent\skills\evo-docker-publish\scripts\preflight.ps1
```

Verifica:
- [ ] `docker buildx inspect evo-multiarch` — builder ativo e com suporte amd64+arm64
- [ ] `docker login` — sessão ativa para `lc1868`
- [ ] Submodules populados (não vazios) para cada serviço a buildar
- [ ] Git working tree limpa nos submodules alvo (sem modified não commitado)

Se qualquer check falhar → **parar** → corrigir antes de prosseguir.

### Criar builder se necessário

```bash
docker buildx create --name evo-multiarch --driver docker-container --bootstrap
docker buildx use evo-multiarch
```

### Login se necessário

```bash
docker login -u lc1868
```

---

## Step 2 — Escolher o que buildar

**Todos os serviços com customização local:**
```bash
./scripts/docker-publish.sh --version 1.0.0-rc4
```

**Serviço específico:**
```bash
./scripts/docker-publish.sh --image evo-ai-crm-community --version 1.0.0-rc4
```

**Dry-run primeiro (sempre recomendado):**
```bash
./scripts/docker-publish.sh --dry-run --version 1.0.0-rc4
```

**evo-flow (build local, não vai para Docker Hub):**
```bash
docker compose -f docker-compose.evo-flow.yml build evo-flow
```

### Convenção de tags

| Situação | Tag |
|---|---|
| Sync upstream + sem customização extra | `v1.0.0-rc4` (igual ao upstream) |
| Sync upstream + customização local | `v1.0.0-rc4-custom` |
| Feature nova sem upstream novo | `v1.0.0-rc4-proxyhealth` (slug da feature) |
| Hotfix urgente | `v1.0.0-rc4-hotfix-<data>` |

Sempre publicar também `:latest` (o script faz isso automaticamente).

---

## Step 3 — Validar após push

```bash
# Confirmar que as tags chegaram no Docker Hub
docker buildx imagetools inspect lc1868/evo-ai-crm-community:1.0.0-rc4

# Deve mostrar: linux/amd64 + linux/arm64
```

Pull de teste local (opcional):
```bash
docker pull lc1868/evo-ai-crm-community:1.0.0-rc4
docker image inspect lc1868/evo-ai-crm-community:1.0.0-rc4 | grep Architecture
```

---

## Step 4 — Atualizar stack de produção

Após confirmar push, atualizar `docs/local/stack-swarm-vps.yaml` com a nova tag:

```yaml
# Antes
image: lc1868/evo-ai-crm-community:v1.0.0-rc3-custom

# Depois
image: lc1868/evo-ai-crm-community:v1.0.0-rc4
```

Redeploy no Swarm:
```bash
docker service update --force --image lc1868/<serviço>:<tag> evo-crm_<serviço>
```

Verificar substituição de variáveis runtime:
```bash
docker service logs evo-crm_<serviço> --tail 20
```

---

## Step 5 — Registrar em CHANGES-LOCAL.md

Após build bem-sucedido, adicionar entrada:

```markdown
## [<data>] Docker publish — <serviço> <old-tag> → <new-tag>

- **Imagem**: `lc1868/<serviço>:<tag>`
- **Plataformas**: linux/amd64 + linux/arm64
- **Motivo**: sync rc4 + customizações (proxy health, white-label, etc.)
- **Stack atualizado**: docs/local/stack-swarm-vps.yaml
```

---

## Quando NÃO buildar

- Se só `docs/` ou `.agent/` mudaram — não precisa rebuild
- Se a mudança é só no orquestrador (`docker-compose.yml`, `.env.example`) — não precisa rebuild
- Se o submodule não tem customização local e upstream não lançou nova tag — usar imagem existente
- `evo-flow` — nunca publicar no Docker Hub; só build local via compose

---

## Agent Integration

| Agent | Quando invocar evo-docker-publish |
|---|---|
| **evo-master** | Menu "Publicar imagens Docker" |
| **evo-dev** | Após commitar mudança em Dockerfile ou entrypoint de submodule |
| **evo-upstream-sync** | Após sync de tag com mudança em Dockerfile — rebuild obrigatório |
| **evo-commit-submodules** | Não invoca diretamente — usuário decide se rebuild é necessário |

**Pré-requisito**: rodar `evo-commit-submodules` antes de `evo-docker-publish` para garantir que todos os commits locais estão no fork antes do build.
