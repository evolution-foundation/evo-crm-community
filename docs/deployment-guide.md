# Evo CRM Community — Guia de Deployment

**Data de geração:** 2026-05-22

---

## Ambientes disponíveis

| Ambiente | Arquivo | Destino |
|---|---|---|
| Desenvolvimento local | `docker-compose.yml` | Máquina local |
| Produção (Swarm) | `docker-compose.swarm.yaml` + `docs/local/stack-swarm-vps.yaml` | VPS Oracle Cloud aarch64 |
| Prod-test | `docker-compose.prod-test.yaml` | Teste de produção local |

---

## Deploy local (desenvolvimento)

```bash
make setup    # primeira vez
make start    # subsequente
make stop     # parar
make clean    # destruir tudo (irreversível)
```

---

## Deploy em produção (Portainer Swarm)

### Infraestrutura
- **VPS**: Oracle Cloud aarch64 (ARM64)
- **Orquestração**: Docker Swarm gerenciado via Portainer
- **Stack**: `docs/local/stack-swarm-vps.yaml`
- **Imagens**: `lc1868/*` no Docker Hub (multi-arch amd64+arm64)

### Publicar imagens

```bash
./scripts/docker-publish.sh
```

Publica todas as 9 imagens sob `lc1868/*` com tags `latest` e `<version>`. Usa `docker buildx` com builder `evo-multiarch` para multi-arch.

**Mapeamento de imagens** — ver [docs/local/IMAGE_REGISTRY_MAP.md](./local/IMAGE_REGISTRY_MAP.md)

### Evolution GO (WhatsApp) — imagem no Docker Hub

Quando você usa um fork do `evolution-go` com mudanças locais (ex.: logs de proxy health), o recomendado é publicar uma imagem própria no Docker Hub para consumir em stacks do Portainer/Swarm.

Exemplo (multi-arch amd64+arm64):

```bash
docker login

docker buildx create --name evo-multiarch --use
docker buildx inspect --bootstrap

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg VERSION=0.7.1-proxyhealth \
  -t lc1868/evolution-go:0.7.1-proxyhealth \
  -t lc1868/evolution-go:latest \
  --push \
  ./evolution-go
```

Uso no Portainer/Swarm (rede `network_swarm_public`):

```yaml
services:
  evolution_go:
    image: lc1868/evolution-go:0.7.1-proxyhealth
    networks:
      - network_swarm_public
    environment:
      PROXY_HEALTH_ENABLED: "true"
      PROXY_HEALTH_INTERVAL_S: "60"
      PROXY_HEALTH_TIMEOUT_MS: "3000"
      PROXY_HEALTH_MAX_LAT_MS: "1500"
      PROXY_HEALTH_HTTP_URL: "http://clients3.google.com/generate_204"
```

### Deploy da stack no Portainer

1. Acessar Portainer na VPS
2. Ir em Stacks → evo-crm-community
3. Atualizar `docs/local/stack-swarm-vps.yaml` com novas imagens/configs
4. Fazer deploy da stack

### Configurações críticas para produção

```bash
# Estas variáveis DEVEM ser definidas (não podem ser localhost)
BACKEND_URL=https://crm.seudominio.com
FRONTEND_URL=https://app.seudominio.com

# Secrets — devem ser idênticos entre serviços
JWT_SECRET=<gere com: openssl rand -hex 64>
AUTH_SECRET=<gere com: openssl rand -hex 32>
API_KEY_ENCRYPTION_SECRET=<chave Fernet: python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())">

# WebSocket (produção usa wss://)
VITE_WS_URL=wss://crm.seudominio.com

# CORS
CORS_ORIGINS=https://app.seudominio.com,https://crm.seudominio.com
```

---

## Nginx (evo-frontend)

O frontend usa nginx para servir o bundle Vite. O arquivo `nginx.conf` foi modificado localmente para:
- CSP com `static.cloudflareinsights.com` (analytics Cloudflare)
- Permissão de `cloudflareinsights.com` no `connect-src`

O `docker-entrypoint.sh` substitui `VITE_*_PLACEHOLDER` por valores reais em runtime (necessário para Docker — as variáveis VITE são baked no bundle em build, mas o entrypoint permite override em `.js`, `.css` e `.html`).

---

## CI/CD

Configurado via `.github/`:
- **Dependabot**: monitora atualizações em submodules e imagens Docker (`.github/dependabot.yml`)
- **Release workflow**: ver `.github/workflows/` — publica para `evolution-foundation` registry

---

## Migrações de banco

```bash
# Rails (CRM e Auth) — executado automaticamente no startup via:
bundle exec rails db:prepare

# Go services (Core, Bot Runtime) — golang-migrate
# Executado via Makefile interno de cada serviço
# Arquivos: migrations/000001_*.up.sql
```

**Importante**: O schema master é gerenciado pelo `evo-crm`. O `evo-auth` usa o mesmo banco mas não gerencia o schema — suas migrations são marcadas como aplicadas pelo `seed-crm`.
