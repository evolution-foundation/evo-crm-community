# CONTEXT.md

Este repositório é um fork de `EvolutionAPI/evo-crm-community`.

## Remotes

- `origin`: `https://github.com/Luizcc87/evo-crm-community.git`
- `upstream`: `https://github.com/EvolutionAPI/evo-crm-community.git`

## Submodules

Cada submodule de serviço tem fork próprio em `Luizcc87/<nome>` com dois remotes:
- `origin` → `EvolutionAPI/<nome>` (upstream, só leitura)
- `fork` → `Luizcc87/<nome>` (seu fork, escrita)

Customizações ficam em branch `develop` ou `custom/` nos forks — nunca em `main`.

## Convenção de arquivos

- `*.upstream.*` — cópia de referência da origem oficial (não editar).
- `*.local.*` — customizações e overlays locais.
- `docs/local/` e `deploy/local/` — documentação e configurações de deploy local (não sobem para upstream).
- `docs/CHANGES-LOCAL.md` — registro obrigatório de toda customização em submodules.

## Topologia de deploy

- Stack de produção: `docs/local/stack-swarm-vps.yaml` (Portainer Swarm, VPS Oracle Cloud aarch64).
- Imagens publicadas em `lc1868/*` no Docker Hub, multi-arch (amd64 + arm64).
- Build via `scripts/docker-publish.sh`.
- Mapeamento de imagens: `docs/local/IMAGE_REGISTRY_MAP.md`.

## Regras de trabalho

- Não misture mudanças locais com espelhos do upstream.
- Não altere submodulos sem necessidade explícita.
- Prefixo `custom:` em commits de customização de submodules.
- Atualizar `docs/CHANGES-LOCAL.md` após modificar arquivos de submodules.
- Ver `AGENTS.md` para regras completas de operação com agentes de IA.
- Ver `docs/SYNC.md` para procedimento de sync com upstream.
