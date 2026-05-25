# Evo CRM Community — Índice de Documentação

**Gerado em:** 2026-05-22 | **Scan:** Deep | **Modo:** initial_scan

---

## Visão do Projeto

- **Tipo:** Monorepo com 6 partes de aplicação + 4 submodules companheiros
- **Linguagem principal:** Ruby 3.4 / Rails 7.1 (backend), React 19 / TypeScript (frontend), Go 1.24 (serviços IA/Bot)
- **Arquitetura:** Multi-serviço single-tenant, fork/overlay do EvolutionAPI/evo-crm-community
- **Deploy:** Portainer Swarm (VPS Oracle Cloud aarch64), imagens `lc1868/*` no Docker Hub

---

## Quick Reference

### Partes da aplicação

| Parte | Stack | Porta | Status upstream |
|---|---|---|---|
| evo-ai-frontend-community | React 19 / Vite 6 | 5173 | ⚠️ 130 commits à frente |
| evo-ai-crm-community | Ruby 3.4 / Rails 7.1 | 3000 | ⚠️ 110 commits à frente |
| evo-auth-service-community | Ruby 3.4 / Rails 7.1 | 3001 | ⚠️ 58 commits à frente |
| evo-ai-core-service-community | Go 1.24 / Gin | 5555 | ✅ puro (rc3) |
| evo-ai-processor-community | Python / FastAPI | 8000 | ✅ puro (rc3) |
| evo-bot-runtime | Go / Gin | 8080 | ✅ puro (rc3) |

### Submodules companheiros

| Submodule | Versão | Status |
|---|---|---|
| evolution-api | 2.4.0-rc2 | ✅ puro |
| evolution-go | 0.7.1 | ⚠️ 2 commits locais |
| evo-nexus | v0.33.0 | ✅ puro |
| evo-flow | heads/main | ⚡ tracking main |

---

## Documentação Gerada

### Arquitetura e estrutura
- [Visão Geral do Projeto](./project-overview.md)
- [Arquitetura do Sistema](./architecture.md)
- [Source Tree Anotado](./source-tree-analysis.md)
- [Arquitetura de Integração entre Serviços](./integration-architecture.md)

### Desenvolvimento e operações
- [Guia de Desenvolvimento](./development-guide.md)
- [Guia de Deployment](./deployment-guide.md)

### White-label e upstream sync ⭐
- [Análise White-Label](./white-label-analysis.md) — branding hardcoded, pontos de customização, plano de ação
- [Análise de Upstream Sync](./upstream-sync-analysis.md) — o que foi modificado, riscos, estratégia de rastreamento

---

## Documentação Existente (no repo)

- [CONTEXT.md](../CONTEXT.md) — Topologia de forks, remotes, convenções
- [CLAUDE.md](../CLAUDE.md) — Instruções para Claude Code
- [AGENTS.md](../AGENTS.md) — Regras para agentes IA
- [CHANGELOG.md](../CHANGELOG.md) — Histórico de versões
- [CONTRIBUTING.md](../CONTRIBUTING.md) — Guia de contribuição
- [SECURITY.md](../SECURITY.md) — Política de segurança
- [docs/SYNC.md](./SYNC.md) — Procedimento de sync com upstream
- [docs/CHANGES-LOCAL.md](./CHANGES-LOCAL.md) — Registro de customizações locais
- [docs/local/stack-swarm-vps.yaml](./local/stack-swarm-vps.yaml) — Stack Portainer Swarm
- [docs/local/IMAGE_REGISTRY_MAP.md](./local/IMAGE_REGISTRY_MAP.md) — Mapeamento de imagens Docker

---

## Começar

```bash
# Clone com submodules
git clone --recurse-submodules https://github.com/Luizcc87/evo-crm-community.git

# Setup completo
make setup

# Primeiro acesso: http://localhost:5173/setup
```

---

## Próximos passos recomendados

1. **White-label imediato**: Implementar Fase 1 de [white-label-analysis.md](./white-label-analysis.md) — quick wins (1-2 dias)
2. **Upstream sync**: Antes de qualquer sync, ler [upstream-sync-analysis.md](./upstream-sync-analysis.md) e preencher [CHANGES-LOCAL.md](./CHANGES-LOCAL.md) com todos os patches faltantes
3. **Deep-dive**: Para documentar APIs ou data models detalhados, rodar o workflow `DP` em modo "Deep-dive into specific area"

---

## Estado do scan

```
project-scan-report.json — completo
Arquivos gerados: 10
Itens incompletos: nenhum
```
