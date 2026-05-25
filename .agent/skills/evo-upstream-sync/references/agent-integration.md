# Agent Integration — evo-upstream-sync

Documenta como os agentes do ciclo de desenvolvimento (_evo/bmm) devem interagir com
a skill `evo-upstream-sync` para manter submodules atualizados sem perder customizações.

> **Princípio**: Os agentes `_evo` são do framework BMAD e não devem ser modificados.
> Este arquivo serve como referência para o agente ativo saber QUANDO invocar o sync.

---

## Mapa de Relacionamentos

```
evo-master
  └── [menu "Sync Upstream"] → evo-upstream-sync (direto)

evo-sm (Scrum Master)
  ├── Sprint Planning → verificar se há nova release antes de fechar sprint
  └── Sprint Review  → incluir sync como tarefa se release nova detectada

evo-dev (Developer)
  ├── Antes de implementar feature que toca submodule → verificar se pinned está atualizado
  └── Após merge de PR → verificar se customizações sobreviveram

evo-dev-story
  └── Se story envolve arquivo de alto risco (nginx.conf, docker-entrypoint.sh,
      db/migrate, config/routes.rb) → avisar: "verificar risk-registry antes de implementar"

evo-retrospective
  └── Incluir pergunta: "houve sync upstream neste ciclo? conflitos encontrados?"

evo-document-project
  └── Após sync: re-escanear submodules e atualizar docs/upstream-sync-analysis.md
```

---

## Quando Invocar evo-upstream-sync

### Obrigatório
- Notificação de nova release nos repositórios `evolution-foundation/*`
- Antes de iniciar sprint que envolve alteração em submodule core (crm, frontend, auth)
- Antes de build de imagem de produção

### Recomendado
- Semanalmente (verificação rápida via `check-releases.ps1`)
- Após qualquer PR mergeado no upstream que resolva bug crítico

### Nunca
- Durante implementação ativa de uma story (sync no meio de feature cria conflitos duplos)
- Sem criar safety tags primeiro (`custom/pre-sync-<date>`)

---

## Checklist para evo-dev antes de implementar em submodule

Antes de criar qualquer commit em `evo-ai-crm-community`, `evo-ai-frontend-community`
ou `evo-auth-service-community`, verificar:

```powershell
# Estamos na versão mais recente do upstream?
.\.agent\skills\evo-upstream-sync\scripts\check-releases.ps1 -SkipFetch

# O arquivo que vou modificar está no risk-registry?
# Ver: .agent/skills/evo-upstream-sync/references/risk-registry.md

# Meu commit vai usar prefixo "custom:" para rastreabilidade?
# git commit -m "custom: <descrição>"
```

Se `check-releases.ps1` reportar `🆕 YES` para qualquer submodule relevante:
→ **Pausar implementação** → executar `evo-upstream-sync` → retomar story

---

## Checklist para evo-sm no Sprint Planning

```
[ ] Rodar check-releases.ps1 antes de fechar sprint backlog
[ ] Se nova release detectada:
    [ ] Adicionar tarefa "sync upstream vX.Y.Z" ao sprint
    [ ] Estimar: 2-4h para releases menores, 1 dia para releases com schema migration
    [ ] Verificar release notes: há migration que exige janela de manutenção?
[ ] Documentar versão pinned atual no sprint goal
```

---

## Checklist para evo-retrospective

Adicionar ao template de retrospectiva:

```
UPSTREAM SYNC
- Houve nova release upstream neste ciclo? Qual?
- O sync foi executado? Quando?
- Conflitos encontrados: quais arquivos, qual resolução?
- Customizações locais sobreviveram ao sync?
- Alguma customização deve ser proposta como PR ao upstream?
- O risk-registry está atualizado com novos arquivos customizados?
```

---

## Convenção de Commits para Rastreabilidade

Commits de customização local devem usar prefixo `custom:` para fácil identificação
no próximo sync:

```
custom: <descrição da customização>

Exemplos:
  custom: proxy health/config endpoint for evolution_go instances
  custom: white-label runtime branding injection
  custom: CSP align with rc4 — remove cloudflareinsights.com
```

Isso permite filtrar via:
```bash
git log --oneline --grep="^custom:" v1.0.0-rc4..HEAD
```

---

## Arquivos que NUNCA devem ser modificados sem registrar no risk-registry

| Submodule | Arquivo | Motivo |
|---|---|---|
| frontend | `docker-entrypoint.sh` | Linha do branding deve sobreviver a todo sync |
| frontend | `nginx.conf` | CSP decisions devem ser explícitas |
| frontend | `src/components/AppLogo.tsx` | Upstream toca frequentemente |
| frontend | `src/components/layout/components/Sidebar.tsx` | Upstream toca frequentemente |
| crm | `config/routes.rb` | Upstream adiciona rotas em todo RC |
| auth | `db/seeds.rb` | Requires de seeds customizados devem sobreviver |

Ao modificar qualquer um desses: **atualizar `references/risk-registry.md` na mesma sessão**.

---

## Relação com docs/upstream-sync-analysis.md

O arquivo `docs/upstream-sync-analysis.md` é o "estado atual" — atualizar após cada sync:
- Coluna "Upstream tag": nova tag absorvida
- Coluna "Commits locais": contagem atual de `git log <tag>..HEAD`
- Coluna "Última atualização": data do sync

O `risk-registry.md` é o "conhecimento permanente" — atualizar quando:
- Nova customização é adicionada a qualquer submodule
- Customização é removida (absorvida pelo upstream)
- Nova decisão de resolução de conflito é tomada
