# GitHub Copilot Instructions — Evo CRM Community Fork

## Estrutura do repositório

Monorepo com 9 submodules. Cada submodule tem fork próprio em `Luizcc87/*` no GitHub.

Remotes dentro de cada submodule:
- `origin` / `upstream` → `evolution-foundation/<repo>` (somente leitura)
- `fork` → `Luizcc87/<repo>` (destino de todo push local)

## Regras de commit

1. Usar prefixo `custom:` em qualquer commit de customização local em submodule.
2. Nunca commitar `.env` — apenas `.env.example`.
3. Nunca fazer push para `origin` ou `upstream` dentro de um submodule.
4. Se submodule estiver em detached HEAD → `git checkout main` antes de commitar.

## Gate rule — antes de implementar em submodule core

Verificar releases upstream antes de qualquer edição em `evo-ai-crm-community`, `evo-ai-frontend-community` ou `evo-auth-service-community`:

```powershell
.\.agent\skills\evo-upstream-sync\scripts\check-releases.ps1 -SkipFetch
```

Se `🆕 YES` aparecer → pausar → executar sync upstream → retomar.

## Arquivos de alto risco

Ao sugerir edições nos arquivos abaixo, sempre avisar que precisam ser registrados em `docs/CHANGES-LOCAL.md`:

- `evo-ai-frontend-community/docker-entrypoint.sh`
- `evo-ai-frontend-community/nginx.conf`
- `evo-ai-crm-community/config/routes.rb`
- `evo-auth-service-community/db/seeds.rb`
- `docker-compose.yml` (root)
- `.env.example` (root)

Lista completa: `.agent/skills/evo-upstream-sync/references/risk-registry.md`

## Sync upstream

Procedimento completo em `.agent/skills/evo-upstream-sync/SKILL.md`.
Script de verificação: `.agent/skills/evo-upstream-sync/scripts/check-releases.ps1`.

## Commit e push por repositório

Procedimento em `.agent/skills/evo-commit-submodules/SKILL.md`.
Script de scan: `.agent/skills/evo-commit-submodules/scripts/scan-changes.ps1`.

## Referências

- `CLAUDE.md` — comandos make, arquitetura, portas dos serviços
- `AGENTS.md` — regras operacionais completas para agentes de IA
- `CONTEXT.md` — topologia de remotes e convenções de arquivo
