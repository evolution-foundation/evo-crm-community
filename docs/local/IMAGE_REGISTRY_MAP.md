# Source of Truth: Registry de Imagens (Fork vs Upstream)

Este documento define a origem correta das imagens Docker (o "Registry") para o deployment do Evo-CRM Community neste fork local. Como temos customizações específicas, algumas imagens precisam obrigatoriamente ser construídas e providas pela conta local (`lc1868`) enquanto as que não sofreram alterações em código-fonte são puxadas diretamente da origem oficial (`evoapicloud`).

## Mapa de Imagens (Atualizado)

| Microserviço | Registry Alvo | Nome da Imagem | Tag | Motivo / Observação |
| :--- | :--- | :--- | :--- | :--- |
| **Gateway** (Nginx) | `lc1868` | `lc1868/evo-crm-gateway` | `1.0.0` | Container modificado localmente. |
| **Auth** | `lc1868` | `lc1868/evo-auth-service-community` | `1.0.0` | Customizações na autenticação e sidekiq. |
| **Core** (Go) | `lc1868` | `lc1868/evo-ai-core-service-community` | `1.0.0` | Ajustes e conexões com banco local. |
| **Processor** (Python)| `lc1868` | `lc1868/evo-ai-processor-community`| `1.0.0` | Driver DB assíncrono ajustado, migrations custom. |
| **Bot Runtime** | `lc1868` | `lc1868/evo-bot-runtime` | `1.0.0` | Ajustes do motor de bot. |
| **Frontend** | `lc1868` | `lc1868/evo-ai-frontend-community` | `1.0.0` | Ajustes visuais, features desabilitadas / editadas. |
| **CRM / CRM Sidekiq** | `evoapicloud`| `evoapicloud/evo-ai-crm-community`| `latest` | **Não modificado em código.** Usando upstream puro. |
| **Evolution GO (WhatsApp)** | `lc1868` | `lc1868/evolution-go` | `0.7.1-proxyhealth` | Fork com logs/status de proxy health (usar quando o deploy incluir o Evolution GO). |

## Regras de Operação para Agentes e CI/CD

1. **Arquivos Swarm**: Quando qualquer serviço em `deploy/local/*.yaml` for alterado, o agente / humano deve obrigatoriamente consultar esta tabela antes de imputar ou alterar os nomes em `image:`.
2. **Novos Builds**: Se o **CRM** sofrer edições locais de código (adicionada nova feature, controller, etc), ele passa a requerer um `docker build` próprio. Somente nesse caso transfira a responsabilidade da tabela acima para `lc1868/evo-ai-crm-community:1.0.0`.
3. **Imagens Base**: Imagens externas como Redis, Postgres, etc, continuam usando o upstream oficial das suas mantenedoras (`redis:7-alpine`, `postgres:15-alpine`).

## Como Fazer Manutenção deste Arquivo

Se você customizar um serviço que antes não era customizado (como o CRM), atualize a coluna _Registry Alvo_ para o seu prefixo pessoal e registre o motivo da alteração de escopo. Todos os agentes consumirão este arquivo de agora em diante antes de mexer na infra.
