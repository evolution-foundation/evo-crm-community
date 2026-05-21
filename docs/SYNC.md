# Procedimento de Sincronização com Upstream

**Fork:** `Luizcc87/evo-crm-community`
**Upstream:** `EvolutionAPI/evo-crm-community`

---

## Quando sincronizar

| Tipo | SLA | Quem |
|---|---|---|
| CVE crítico / hotfix de segurança | 48h após publicação upstream | Lead técnico |
| Nova release / release candidate | 7 dias após tag oficial | Lead técnico |
| Verificação semanal de novidades | Toda segunda-feira | Qualquer dev |

---

## 1. Sincronizar o orquestrador

```bash
# 1. Atualizar referências upstream
git fetch upstream

# 2. Verificar o que chegou antes de mergear
git log main..upstream/main --oneline
git diff main upstream/main -- .gitmodules docker-compose.yml .env.example

# 3. Mergear upstream em main local
git checkout main
git merge upstream/main --no-ff -m "sync(upstream): merge upstream vX.Y.Z"

# 4. Push main para origin (seu fork)
git push origin main

# 5. Abrir PR main → develop para revisão de conflitos e testes
gh pr create --base develop --head main \
  --title "sync(upstream): merge vX.Y.Z" \
  --body "Sync automático com upstream. Revisar conflitos e rodar smoke tests antes de mergear."
```

---

## 2. Checklist de conflitos (obrigatório antes de fechar o PR)

- [ ] `.gitmodules` — SHAs de submodules não foram sobrescritos inadvertidamente
- [ ] `docker-compose.yml` — variáveis de ambiente novas/removidas comparadas à versão anterior
- [ ] `.env.example` — diff contra versão anterior; propagar novas vars para `.env` de cada ambiente
- [ ] Migrations Rails — sem gaps ou duplicatas na numeração; rodar `db:migrate:status | grep down`
- [ ] Migrations Go — verificar versão atual com `migrate ... version` nos serviços core e bot-runtime
- [ ] `Gemfile.lock` / `go.sum` / `package-lock.json` — regenerar dentro dos containers, não editar manualmente

---

## 3. Sincronizar submodules com customizações

Para cada submodule que possui fork próprio (`Luizcc87/<submodule>`):

```bash
cd <submodule>

# Nomenclatura de remotes neste projeto:
# origin → evolution-foundation/<repo>  (upstream oficial, read-only)
# fork   → Luizcc87/<repo>              (seu fork, write)

# 1. Puxar do upstream oficial
git fetch origin

# 2. Mergear em main do fork
git checkout main
git merge origin/main --no-ff
git push fork main

# 3. Integrar em develop
git checkout develop
git merge main --no-ff
# resolver conflitos se houver
git push fork develop
```

Submodules sem customizações (`evolution-api`, `evolution-go`, `evo-nexus`): atualizar SHA no `.gitmodules` do orquestrador após validação.

---

## 4. Smoke tests após sync (obrigatório)

```bash
# Ambiente limpo
make clean && make setup

# Verificar health de todos os serviços
curl -sf http://localhost:3001/health          && echo "auth OK"
curl -sf http://localhost:3000/health          && echo "crm OK"
curl -sf http://localhost:5555/api/v1/health   && echo "core OK"
curl -sf http://localhost:8000/health          && echo "processor OK"
curl -sf http://localhost:8080/health          && echo "bot-runtime OK"

# Migrations Rails sem pendências
docker compose run --rm evo-crm bundle exec rails db:migrate:status | grep " down " && echo "MIGRATIONS PENDENTES" || echo "migrations OK"
```

---

## 5. Registrar o sync no CHANGELOG interno

Abrir `CHANGELOG.md` na raiz e adicionar entrada:

```markdown
## [internal] YYYY-MM-DD
### Sync
- Merged upstream vX.Y.Z
- Conflitos resolvidos: <arquivo> (<N>), <arquivo> (<N>)
- Migrations novas: <serviço> #<número>, ...
- Observações: <qualquer detalhe relevante>
```

---

## Referências rápidas

| Repositório | Upstream oficial | Fork Luiz |
|---|---|---|
| orquestrador | `EvolutionAPI/evo-crm-community` | `Luizcc87/evo-crm-community` |
| evo-auth | `evolution-foundation/evo-auth-service-community` | `Luizcc87/evo-auth-service-community` |
| evo-crm | `evolution-foundation/evo-ai-crm-community` | `Luizcc87/evo-ai-crm-community` |
| evo-frontend | `evolution-foundation/evo-ai-frontend-community` | `Luizcc87/evo-ai-frontend-community` |
| evo-processor | `evolution-foundation/evo-ai-processor-community` | `Luizcc87/evo-ai-processor-community` |
| evo-core | `evolution-foundation/evo-ai-core-service-community` | `Luizcc87/evo-ai-core-service-community` |
| evo-bot-runtime | `evolution-foundation/evo-bot-runtime` | `Luizcc87/evo-bot-runtime` |
