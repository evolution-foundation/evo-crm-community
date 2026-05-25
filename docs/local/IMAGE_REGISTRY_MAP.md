# Source of Truth: Registry de Imagens (Fork vs Upstream)

Define qual registry usar por serviço. Consultar antes de alterar qualquer `image:` no compose ou stack Swarm.

**Última atualização**: 2026-05-25 (rc4 sync — CRM passou a ter customização local)

---

## Mapa de Imagens

| Serviço | Registry | Imagem | Tag rc4 | Motivo |
|:---|:---|:---|:---|:---|
| **Auth** | `lc1868` | `lc1868/evo-auth-service-community` | `v1.0.0-rc4` | Seeds white-label + dev_admin |
| **CRM** | `lc1868` | `lc1868/evo-ai-crm-community` | `v1.0.0-rc4` | Proxy health controller + routes.rb customizado |
| **Frontend** | `lc1868` | `lc1868/evo-ai-frontend-community` | `v1.0.0-rc4` | White-label branding + ProxyPanel + CSP nginx |
| **Processor** (Python) | `lc1868` | `lc1868/evo-ai-processor-community` | `v1.0.0-rc4` | Sem customização atual — rebuild por precaução |
| **Core** (Go) | `lc1868` | `lc1868/evo-ai-core-service-community` | `v1.0.0-rc4` | Sem customização atual — rebuild por precaução |
| **Bot Runtime** | `lc1868` | `lc1868/evo-bot-runtime` | `v1.0.0-rc4` | Sem customização atual — rebuild por precaução |
| **Evolution GO** | `lc1868` | `lc1868/evolution-go` | `v0.7.1` | Proxy health monitor + API endpoint |
| **Gateway** (nginx) | `lc1868` | `lc1868/evo-crm-gateway` | `1.0.0` | Config customizada |
| **evo-flow** | build local | — | — | Build via `docker-compose.evo-flow.yml` — **nunca publicar no Docker Hub** |
| Redis | upstream | `redis:7-alpine` | — | Sem customização |
| PostgreSQL | upstream | `postgres:15-alpine` | — | Sem customização |
| ClickHouse | upstream | `clickhouse/clickhouse-server:latest` | — | Sem customização |
| Kafka | upstream | `confluentinc/cp-kafka:7.4.0` | — | Sem customização |
| Temporal | upstream | `temporalio/auto-setup:latest` | — | Sem customização |

---

## Script de build e push

```bash
# Dry-run — ver o que seria executado
./scripts/docker-publish.sh --dry-run --version 1.0.0-rc4

# Todos os serviços
./scripts/docker-publish.sh --version 1.0.0-rc4

# Serviço específico
./scripts/docker-publish.sh --image evo-ai-crm-community --version 1.0.0-rc4

# evo-flow (build local, não publica)
docker compose -f docker-compose.evo-flow.yml build evo-flow
```

Log gerado automaticamente em: `logs/docker-publish-<timestamp>.log`

---

## Regras de operação

1. **Qualquer serviço com customização local → obrigatório usar `lc1868/*`**. Nunca apontar para `evoapicloud` ou `evolution-foundation` se houver código local modificado.

2. **Antes de buildar**: rodar `evo-commit-submodules` para garantir que todos os commits locais estão no fork. Build de código não commitado é build de código que pode se perder.

3. **Convenção de tags**:
   - Sync puro sem extra: `v1.0.0-rc4`
   - Sync + customização adicional: `v1.0.0-rc4-custom`
   - Feature nova sem sync: `v1.0.0-rc4-<slug>`
   - Hotfix: `v1.0.0-rc4-hotfix-<data>`

4. **evo-flow nunca vai para Docker Hub** — depende de configs locais (Kafka, ClickHouse, Temporal) e é sempre buildado on-demand via compose.

5. **Após push**: atualizar tags em `docs/local/stack-swarm-vps.yaml` e rodar `docker service update` no Swarm.

6. **Atualizar este arquivo** sempre que:
   - Um serviço sem customização receber customização local → mover para `lc1868`
   - Uma customização for absorvida pelo upstream → pode voltar para upstream se não houver mais diff local
   - Uma nova tag for publicada

---

## Quando um serviço volta para upstream

Se um serviço `lc1868/*` não tem mais nenhuma customização local (absorvida pelo upstream):

1. Verificar: `git diff HEAD..<new-tag> --name-only` no submodule — deve ser vazio ou só docs
2. Atualizar a linha deste arquivo para o registry upstream
3. Atualizar `docker-compose.yml` e `stack-swarm-vps.yaml`
4. Registrar em `docs/CHANGES-LOCAL.md`

> Ver skill: `.agent/skills/evo-upstream-sync/SKILL.md`
