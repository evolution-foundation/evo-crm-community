# Evo CRM Community — Análise de Upstream Sync

**Data de geração:** 2026-05-22  
**Objetivo:** Mapear o que foi modificado vs upstream, riscos de conflito e estratégia de rastreamento de customizações

---

## Visão geral da topologia de forks

```
EvolutionAPI/evo-crm-community (upstream oficial)
    └── Luizcc87/evo-crm-community (fork orquestrador — este repo)
            origin=Luizcc87, upstream=EvolutionAPI

evolution-foundation/<serviço> (upstream de cada serviço)
    └── Luizcc87/<serviço> (fork de cada serviço)
            origin=evolution-foundation (leitura)
            fork=Luizcc87 (escrita)
```

**Convenção:** Customizações ficam em branch `develop` ou `custom/*` nos forks. Nunca em `main`.

---

## Status atual de cada submodule

| Submodule | Upstream tag | Commits locais | Arquivos modificados conhecidos |
|---|---|---|---|
| evo-ai-crm-community | v1.0.0-rc2 | **110 commits à frente** | Inúmeros — ver git log |
| evo-ai-frontend-community | v1.0.0-rc2 | **130 commits à frente** | `docker-entrypoint.sh`, `nginx.conf` confirmados |
| evo-auth-service-community | v1.0.0-rc2 | **58 commits à frente** | Fixes de migration, healthcheck, licenciamento |
| evolution-go | v0.7.1 | 2 commits à frente | A investigar |
| evo-ai-core-service-community | v1.0.0-rc3 | 0 | ✅ puro |
| evo-ai-processor-community | v1.0.0-rc3 | 0 | ✅ puro |
| evo-bot-runtime | v1.0.0-rc3 | 0 | ✅ puro |
| evolution-api | 2.4.0-rc2 | 0 | ✅ puro |
| evo-nexus | v0.33.0 | 0 | ✅ puro |

---

## Arquivos com modificações locais confirmadas (docs/CHANGES-LOCAL.md)

### evo-ai-frontend-community

| Arquivo | Modificação | Risco de conflito |
|---|---|---|
| `docker-entrypoint.sh` | Fallback `VITE_WS_URL` derivado de `VITE_API_URL`; substitution em `.js`, `.css`, `.html`; logs de runtime; warning de placeholders não substituídos | **Médio** — arquivo modificado que existe no upstream |
| `nginx.conf` | CSP: adicionado `static.cloudflareinsights.com` ao `script-src` e `cloudflareinsights.com` ao `connect-src` | **Médio** — CSP pode ser atualizado pelo upstream |

### Orquestrador (evo-crm-community raiz)

| Arquivo | Modificação | Risco |
|---|---|---|
| `scripts/docker-publish.sh` | Novo — build/push multi-arch amd64+arm64 para `lc1868/*` | **Baixo** — arquivo novo |
| `docs/SYNC.md` | Novo — procedimento de sync com upstream | **Nenhum** — arquivo novo |
| `.github/dependabot.yml` | Novo — monitoramento de submodules e imagens | **Baixo** — upstream não tem |
| `docs/local/stack-swarm-vps.yaml` | Novo — stack Portainer Swarm VPS Oracle Cloud | **Nenhum** — arquivo local |
| `docker-compose.yml` | Modificado — imagens, portas, env vars, serviços adicionais | **Alto** — upstream atualiza frequentemente |
| `.env.example` | Modificado — variáveis de produção adicionais | **Médio** |

---

## Riscos de conflito ao sincronizar com upstream

### Alto risco

| Item | Por quê é alto risco |
|---|---|
| `docker-compose.yml` | Upstream adiciona/remove serviços, altera configurações regularmente. Conflito quase certo em merges. |
| `evo-ai-crm-community` (110 commits) | Volume alto de mudanças. Upstream continua evoluindo. Cada sync pode ter dezenas de conflitos. |
| `evo-ai-frontend-community` (130 commits) | Idem. Maior volume de todos os submodules. |

### Médio risco

| Item | Por quê é médio risco |
|---|---|
| `evo-auth-service-community` (58 commits) | Menos ativo que crm/frontend, mas modificado. |
| `nginx.conf` do frontend | CSP é sensível — upstream pode adicionar novos scripts que quebram. |
| `docker-entrypoint.sh` do frontend | Lógica de substituição de env vars pode entrar em conflito com mudanças upstream no script. |
| `.env.example` | Novas variáveis upstream precisam ser integradas manualmente. |

### Baixo risco

| Item | Por quê é baixo |
|---|---|
| `evolution-go` (2 commits) | Poucos commits, componente companheiro menos crítico. |
| Arquivos `docs/local/*` | Não sobem para upstream — sem conflito. |
| `scripts/docker-publish.sh` | Arquivo novo — upstream não tem. |

---

## Estratégia recomendada para rastrear customizações

### O que já existe (bom)

1. **`docs/CHANGES-LOCAL.md`**: Registro manual de customizações. Estrutura definida mas ainda pouco preenchida.
2. **`CONTEXT.md`**: Documenta remotes, convenções de branches e regras de trabalho.
3. **`docs/SYNC.md`**: Procedimento de sync com upstream documentado.
4. **Convenção de branches**: `develop` e `custom/*` separados de `main`.
5. **Prefixo `custom:` em commits**: Facilita identificação de mudanças locais no `git log`.

### O que falta (recomendações)

#### Recomendação 1 — Preencher `docs/CHANGES-LOCAL.md` sistematicamente

Hoje está quase vazio (só 2 entradas). Para cada arquivo modificado nos submodules, registrar:

```markdown
## [2026-05-22] Descrição curta
- Arquivo: `caminho/relativo`
- Motivo: por que foi necessário
- Conflito esperado no sync: sim/não + detalhes
- Branch no fork: nome da branch
- Como reaplicar: diff inline ou link para o commit
```

#### Recomendação 2 — Usar `git format-patch` para patches atômicos

Para cada customização em submodules, gerar um patch atômico versionado:

```bash
# Gerar patch da modificação
git -C evo-ai-frontend-community format-patch v1.0.0-rc2..HEAD \
  -- docker-entrypoint.sh nginx.conf \
  -o docs/patches/evo-frontend/

# Após sync com upstream, reaplicar
git -C evo-ai-frontend-community am docs/patches/evo-frontend/*.patch
```

#### Recomendação 3 — Tag local antes de cada sync

Antes de sincronizar com upstream, criar tag local nos submodules modificados:

```bash
git -C evo-ai-crm-community tag custom/pre-sync-$(date +%Y%m%d)
git -C evo-ai-frontend-community tag custom/pre-sync-$(date +%Y%m%d)
git -C evo-auth-service-community tag custom/pre-sync-$(date +%Y%m%d)
```

Isso cria ponto de restauração se o merge der errado.

#### Recomendação 4 — Pasta `docs/patches/` para patches de submodules

```
docs/
  patches/
    evo-frontend/
      0001-docker-entrypoint-ws-fallback.patch
      0002-nginx-csp-cloudflare.patch
    evo-auth/
      0001-seeds-env-vars.patch    ← (quando white-label for implementado)
    evo-crm/
      (patches pendentes de documentar)
```

#### Recomendação 5 — `git log` filtrado por `custom:` para auditoria rápida

```bash
# Ver só commits de customização em um submodule
git -C evo-ai-frontend-community log --oneline --grep="^custom:"

# Ver todos os commits locais além do upstream
git -C evo-ai-frontend-community log --oneline v1.0.0-rc2..HEAD
```

---

## Procedimento de sync resumido (do docs/SYNC.md)

```bash
# 1. Sync do orquestrador
git fetch upstream
git log main..upstream/main --oneline
git diff main upstream/main -- .gitmodules docker-compose.yml .env.example
git checkout main
git merge upstream/main --no-ff -m "sync(upstream): merge upstream vX.Y.Z"
git push origin main

# 2. Abrir PR main → develop para revisão de conflitos
gh pr create --base develop --head main \
  --title "sync(upstream): merge vX.Y.Z"

# 3. Para submodules modificados: cherry-pick ou rebase dos commits locais
# (ver docs/SYNC.md para procedimento completo)
```

---

## Checklist de sync (executar a cada atualização upstream)

- [ ] Verificar `docker-compose.yml` — novos serviços ou ports?
- [ ] Verificar `.env.example` — novas variáveis obrigatórias?
- [ ] Submodule `evo-ai-crm-community`: revisar diff linha a linha para conflitos
- [ ] Submodule `evo-ai-frontend-community`: `docker-entrypoint.sh` e `nginx.conf`
- [ ] Submodule `evo-auth-service-community`: migrations novas são idempotentes?
- [ ] Atualizar `docs/CHANGES-LOCAL.md` após resolver conflitos
- [ ] Rodar `make setup` (fresh) para smoke test
- [ ] Verificar http://localhost:5173/setup funciona
