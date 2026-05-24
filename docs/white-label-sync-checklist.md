# White-Label Sync Checklist

Checklist procedural para sincronizar upstream sem perder customizações white-label do `evo-crm-white-label`.

Use este documento junto com:
- `docs/SYNC.md` para o fluxo geral de sync
- `docs/CHANGES-LOCAL.md` para rastreabilidade dos arquivos `[PATCH]`, `[NOVO]` e `[MONITOR]`
- `docs/patches/evo-frontend/*.patch` e `docs/patches/evo-auth/*.patch` para reaplicação mínima via `git am`

## Quando usar

Use este checklist quando:
- chegar nova tag/release candidate do upstream
- houver merge de hotfix relevante em frontend ou auth
- for necessário rebase/sync dos submodules com `evolution-foundation/*`

Não use este documento para criar customizações novas. Ele serve para revalidar e reaplicar a camada white-label existente.

## Regras operacionais

- Não customizar `main` dos submodules.
- Customizações locais permanecem em `develop` ou `custom/production-fixes`.
- `origin` do orquestrador é o fork com escrita.
- `upstream` do orquestrador é somente leitura.
- Nos submodules com fork próprio:
  - `origin` = upstream oficial
  - `fork` = fork `Luizcc87/*` com escrita

## Inventário white-label

### Arquivos `[PATCH]`

Frontend:
- `evo-ai-frontend-community/docker-entrypoint.sh`
- `evo-ai-frontend-community/index.html`

Auth:
- `evo-auth-service-community/db/seeds.rb`

### Arquivos `[MONITOR]`

Frontend:
- `evo-ai-frontend-community/nginx.conf`
- `evo-ai-frontend-community/Dockerfile`
- `evo-ai-frontend-community/src/components/AppLogo.tsx`
- `evo-ai-frontend-community/src/components/layout/components/Sidebar.tsx`

Orquestrador:
- `docker-compose.yml`
- `.env.example`
- `.gitignore`

CRM/Auth config relacionados a identidade e suporte:
- pontos de mailer/email no auth quando `SUPPORT_EMAIL` ou remetente entrarem em conflito com comportamento upstream
- qualquer ajuste futuro de branding servido por nginx/CSP ou por config de runtime

## Fase 1 — Preparação

1. Confirmar árvore de trabalho antes do sync:

```bash
git status
git -C evo-ai-frontend-community status
git -C evo-auth-service-community status
```

2. Conferir a rastreabilidade existente:

```bash
code docs/CHANGES-LOCAL.md
code docs/patches/evo-frontend/
code docs/patches/evo-auth/
```

3. Registrar a base do sync:
- data
- operador
- tag/commit upstream alvo
- submodules que entrarão no sync

## Fase 2 — Atualização upstream

Seguir `docs/SYNC.md` para o procedimento geral do orquestrador e dos submodules.

Comandos mínimos de pull upstream (detalhamento em `docs/SYNC.md`):

```bash
# orquestrador
git fetch upstream && git merge upstream/main

# submodules (executar em cada submodule com fork)
git -C evo-ai-frontend-community fetch origin && git -C evo-ai-frontend-community merge origin/main
git -C evo-auth-service-community fetch origin && git -C evo-auth-service-community merge origin/main
```

Pontos obrigatórios antes de seguir:
- merge upstream concluído no branch correto
- nenhum patch WL reaplicado ainda
- diff dos arquivos `[MONITOR]` revisado

## Fase 3 — Revisão dos arquivos `[MONITOR]`

Antes de reaplicar patches, verificar manualmente o que o upstream trouxe.
Use `ORIG_HEAD` (disponível imediatamente após `git merge`) para comparar contra o estado pré-merge:

```bash
git -C evo-ai-frontend-community diff ORIG_HEAD..HEAD -- nginx.conf Dockerfile src/components/AppLogo.tsx src/components/layout/components/Sidebar.tsx
git diff ORIG_HEAD..HEAD -- docker-compose.yml .env.example .gitignore
```

> **Nota:** Não use `HEAD~1..HEAD` após merge — `HEAD~1` aponta para o commit de merge, não para a base upstream. `ORIG_HEAD` é o commit pré-merge correto.

### Quebra imediata

Tratar como quebra e parar a liberação se upstream:
- mover ou reescrever o boot do nginx/frontend
- alterar a estrutura de `index.html` removendo ou deslocando `<title>` ou `<link rel="icon">`
- alterar o entrypoint frontend a ponto de inviabilizar a chamada do branding script
- alterar o seed auth a ponto de mudar a criação de `RuntimeConfig.account`
- alterar configuração de email/mailer que impacte a interpretação de `SUPPORT_EMAIL`

## Fase 4 — Reaplicação dos patches `[PATCH]`

### Frontend

Aplicar no branch local do submodule:

```bash
git -C evo-ai-frontend-community am ../docs/patches/evo-frontend/0001-branding-entrypoint-call.patch
git -C evo-ai-frontend-community am ../docs/patches/evo-frontend/0002-runtime-branding-placeholders.patch
```

### Auth

```bash
git -C evo-auth-service-community am ../docs/patches/evo-auth/0001-seeds-white-label-require.patch
```

> **Nota CRLF:** Os patches foram gerados no Windows e podem conter CRLF. Em Linux/VPS, se `git am` emitir warning `quoted CRLF` ou falhar, adicionar a flag `--keep-cr`:
> ```bash
> git -C evo-ai-frontend-community am --keep-cr ../docs/patches/evo-frontend/0001-branding-entrypoint-call.patch
> ```
> Alternativamente, converter os patches para LF antes de aplicar:
> ```bash
> dos2unix docs/patches/evo-frontend/*.patch docs/patches/evo-auth/*.patch
> ```

### Se `git am` falhar

1. Inspecionar conflito.
2. Decidir se o contexto upstream mudou pouco ou estruturalmente.
3. Resolver manualmente somente no branch local de customização.

Comandos úteis:

```bash
git -C evo-ai-frontend-community am --show-current-patch=diff
git -C evo-ai-frontend-community am --continue
git -C evo-ai-frontend-community am --abort

git -C evo-auth-service-community am --show-current-patch=diff
git -C evo-auth-service-community am --continue
git -C evo-auth-service-community am --abort
```

### Quando regenerar patch

Regenerar o patch e atualizar `docs/CHANGES-LOCAL.md` se:
- a resolução manual mudou mais do que contexto/trivial offset
- o arquivo upstream passou a exigir patch diferente do registrado
- um patch deixou de ser “mínimo” e precisou de nova estratégia

Após regenerar:
- substituir o `.patch` em `docs/patches/<submodule>/`
- atualizar a referência correspondente em `docs/CHANGES-LOCAL.md`
- registrar o motivo da regeneração no log de execução do sync

## Fase 5 — Validação pós-sync

Executar em staging ou ambiente local equivalente:

```bash
make setup
```

Ou fluxo equivalente por container/compose, desde que recrie frontend e auth com as variáveis atuais.

### Validações obrigatórias

Frontend:
- confirmar logo da instância
- confirmar `<title>` do browser
- confirmar favicon
- confirmar fallback sem vars WL configuradas

Auth:
- confirmar `RuntimeConfig.account.name`
- confirmar `RuntimeConfig.account.support_email`

Comandos/checagens sugeridos:

```bash
docker compose config --quiet
docker compose up -d
curl -sf http://localhost:3001/health
curl -sf http://localhost:3000/health
```

Validação funcional esperada:
- com WL configurado: branding correto
- sem WL configurado: comportamento padrão Evolution continua intacto

## Fase 6 — Critérios de quebra

Não liberar produção se qualquer item abaixo ocorrer:
- `git am` falhou e a resolução manual não ficou clara/repetível
- favicon, logo ou título não refletem branding esperado
- `RuntimeConfig.account.name` não corresponde ao valor configurado
- `RuntimeConfig.account.support_email` não corresponde ao valor configurado
- fallback sem vars WL quebra layout ou seed
- arquivos `[MONITOR]` mudaram de forma que a customização local ficou semanticamente incerta

## Fase 7 — Registro e auditoria

Cada sync deve deixar registro mínimo com:
- data
- operador
- upstream/base usada
- submodules atualizados
- patches reaplicados
- conflitos encontrados
- decisão tomada
- resultado da validação final

Template:

```markdown
## Sync WL — YYYY-MM-DD
- Operador:
- Base upstream:
- Submodules atualizados:
- Patches reaplicados:
  - evo-frontend:
  - evo-auth:
- Arquivos [MONITOR] revisados:
- Conflitos:
- Patches regenerados:
- Resultado da validação:
- Observações:
```

Se houve mudança relevante na forma de reaplicação, atualizar também:
- `docs/CHANGES-LOCAL.md`
- este `docs/white-label-sync-checklist.md`

## Saída esperada

Ao final do sync:
- patches `[PATCH]` reaplicados ou regenerados
- arquivos `[MONITOR]` revisados
- branding validado
- seed auth validado
- rastreabilidade atualizada
