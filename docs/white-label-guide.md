# White Label — Guia de Configuração

Como personalizar identidade visual e textos de marca do Evo CRM Community.

---

## Variáveis de ambiente

Todas as variáveis abaixo ficam no `.env` (copie de `.env.example`).

### Identidade básica

| Variável | Default | Descrição |
|---|---|---|
| `APP_NAME` | `Evo CRM` | Nome exibido na sidebar e serviços |
| `APP_TITLE` | `Evo CRM` | Título da aba do browser (`<title>`) |
| `APP_DOMAIN` | `localhost` | Domínio público da instância |
| `ACCOUNT_NAME` | `Evolution Community` | Nome da conta criado pelo seed |
| `SUPPORT_EMAIL` | `support@evolution.com` | Email de suporte mostrado ao usuário |
| `ACCOUNT_LOCALE` | `en` | Locale padrão da conta (`en`, `pt`, `es`) |

### Logo e favicon

| Variável | Default | Descrição |
|---|---|---|
| `APP_LOGO_URL` | *(vazio)* | URL pública da logo; vazio = logo Evolution padrão |
| `APP_FAVICON_URL` | *(vazio)* | URL pública do favicon; vazio = fallback para `APP_LOGO_URL` ou `/favicon.svg` |
| `BRANDING_ASSETS_PATH` | *(vazio)* | Caminho local com assets montados no container (ver abaixo) |

---

## Opções para logo e favicon

### Opção 1 — URL remota (recomendado para produção)

```env
APP_LOGO_URL=https://cdn.minhaempresa.com/logo.svg
APP_FAVICON_URL=https://cdn.minhaempresa.com/favicon.svg
```

O frontend substitui as referências no boot do container via `branding-entrypoint.sh`.  
Não requer rebuild da imagem.

### Opção 2 — Volume local (desenvolvimento / on-premise)

```env
BRANDING_ASSETS_PATH=/home/user/meus-assets
```

Coloque os arquivos no diretório local:
```
/home/user/meus-assets/
  logo.svg      ← logo principal
  favicon.svg   ← favicon (opcional; fallback para logo.svg)
```

O `docker-compose.yml` monta esse diretório em `/usr/share/nginx/html/branding/` dentro do container nginx.  
O `branding-entrypoint.sh` detecta os arquivos e os usa com precedência sobre `APP_LOGO_URL`.

> **Nota**: em produção com Swarm/Kubernetes prefira URL remota. Volume local exige que o arquivo esteja acessível em todos os nós do cluster.

### Ordem de precedência (logo)

1. `BRANDING_ASSETS_PATH` + arquivo `logo.svg` presente no volume
2. `APP_LOGO_URL` (URL remota não-vazia)
3. `/logo.svg` embutido na imagem (logo Evolution padrão)

---

## Seed de identidade

O seed do auth (`evo-auth-service-community`) lê as variáveis `ACCOUNT_NAME`, `SUPPORT_EMAIL`, `APP_DOMAIN` e `ACCOUNT_LOCALE` para criar a conta no banco.

Se a conta já existir (re-seed), o seed **não sobrescreve** — rode `make clean && make setup` para recomeçar do zero.

Arquivo responsável: `evo-auth-service-community/db/seeds/white_label.rb`

---

## Exemplo completo (produção)

```env
# Identidade
APP_NAME=Minha Empresa CRM
APP_TITLE=Minha Empresa CRM
APP_DOMAIN=crm.minhaempresa.com
ACCOUNT_NAME=Minha Empresa
SUPPORT_EMAIL=suporte@minhaempresa.com
ACCOUNT_LOCALE=pt

# Logo/favicon via CDN
APP_LOGO_URL=https://cdn.minhaempresa.com/logo.svg
APP_FAVICON_URL=https://cdn.minhaempresa.com/favicon.svg

# Volume local não usado em produção
BRANDING_ASSETS_PATH=
```

---

## Desenvolvimento local

```env
APP_NAME=Minha Empresa CRM
APP_TITLE=Minha Empresa CRM
APP_DOMAIN=localhost
ACCOUNT_NAME=Minha Empresa
SUPPORT_EMAIL=suporte@minhaempresa.com
ACCOUNT_LOCALE=pt

# Volume local com assets
BRANDING_ASSETS_PATH=./branding
```

Crie a pasta `branding/` na raiz do projeto (já em `.gitignore`) e coloque `logo.svg` lá.

---

## Admin padrão de desenvolvimento

Criado automaticamente pelo seed do auth em ambiente não-produção:

| Variável | Default |
|---|---|
| `DEV_ADMIN_EMAIL` | `admin@evocrm.local` |
| `DEV_ADMIN_PASSWORD` | `Admin@12345` |
| `DEV_ADMIN_NAME` | `Admin` |

Role atribuída automaticamente: **Account Owner**.  
Ignorado quando `RAILS_ENV=production`.

---

## O que NÃO é configurável via env (ainda)

- Textos i18n hardcoded em `src/i18n/locales/*/setup.json` (ex.: rodapé do wizard)
- Imagem `hover-evolution.png` usada em interações de hover
- Emails transacionais (templates do Devise/Rails mailer)

Para customizar esses pontos é necessário editar os arquivos nos submodules e rebuildar a imagem.  
Ver análise completa: [white-label-analysis.md](white-label-analysis.md)
