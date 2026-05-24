---
stepsCompleted: ['step-01-init', 'step-02-context', 'step-03-mvp-agents', 'step-03-starter', 'step-04-decisions', 'step-05-patterns', 'step-06-structure', 'step-07-validation', 'step-08-complete']
lastStep: 8
status: 'complete'
completedAt: '2026-05-24'
inputDocuments:
  - '_evo-output/planning-artifacts/hubsoft-integration/prd.md'
  - 'docs/hubsoft-integration/technical-research-api-hubsoft.md'
  - 'docs/hubsoft-integration/domain-research-isp-brasil-hubsoft.md'
  - 'docs/hubsoft-integration/product-brief-hubsoft-integration.md'
  - 'docs/architecture.md'
  - 'docs/integration-architecture.md'
workflowType: 'architecture'
project_name: 'evo-crm-community'
user_name: 'Luiz'
date: '2026-05-24'
active_feature: 'hubsoft-integration'
---

# Architecture Decision Document

_Este documento é construído colaborativamente passo a passo. Seções são adicionadas conforme as decisões arquiteturais são tomadas._

---

## Validação da Arquitetura

### Validação de Coerência

**Compatibilidade de decisões:** ✅
- OAuth Rails → Processor: compatível com Fernet API key já existente entre serviços
- Redis DB 0 namespace `hubsoft:`: sem conflito com namespaces existentes (Sidekiq, ActionCable)
- `audit_logs` reutilizado: schema JSONB em `details` absorve todos os campos HubSoft sem migration
- `custom_tool_ids` por agente: mecanismo existente em `ToolBuilder.build_tools()` — zero modificação de código do produto
- Circuit breaker em `connector.py`: centralizado, não duplicado nas tools — coerente com padrão Custom Tools existente

**Consistência de padrões:** ✅
- Naming Python `snake_case` alinhado com codebase processor existente
- Naming Ruby `CamelCase`/`snake_case` alinhado com convenção Rails
- Prefixo `hubsoft:` Redis: sem colisão com padrões existentes
- Envelope de resposta `{status, data, reason}`: consistente entre todas as 7 tools

**Alinhamento de estrutura:** ✅
- `app/services/crm/hubsoft/` espelha exatamente `app/services/crm/bms/` — sem desvio
- `src/services/hubsoft/` espelha `src/services/adk/` — sem desvio
- Fronteiras bem definidas: frontend nunca toca HubSoft, Rails sync não faz ações financeiras

---

### Validação de Cobertura de Requisitos

**Requisitos Funcionais — 46/46 cobertos:** ✅

| Área | Status | Arquivo responsável |
|---|---|---|
| FR01–FR07 — Identificação | ✅ | `identification_tools.py` + `contact_sync_job.rb` |
| FR08–FR13 — Financeiro | ✅ | `financial_tools.py` |
| FR14–FR20 — Suporte | ✅ | `support_tools.py` |
| FR21–FR26 — Vendas | ✅ | `sales_tools.py` |
| FR27–FR29 — Sync/Cache | ✅ | `plans_sync_job.rb` + `connector.py` |
| FR30–FR34 — Auditoria | ✅ | `audit.py` → `audit_logs` |
| FR35–FR39 — Config/Admin | ✅ | `oauth_client.rb` + UI existente |
| FR40–FR43 — Resiliência | ✅ | `connector.py` (circuit breaker + idempotência) |
| FR44–FR46 — Integração IA | ✅ | `custom_tool_ids` + `tool_context.agent_name` |

**Requisitos Não-Funcionais — cobertos:** ✅

| NFR | Cobertura Arquitetural |
|---|---|
| P95 < 3s consulta simples | Cache Redis 30–120s + timeout 8s no connector |
| P95 < 6s fluxo completo | Tools assíncronas + circuit breaker com fallback |
| Token HubSoft = 0 no frontend | Fronteira arquitetural: token só em `app_configs` Rails + Processor |
| `actor_id` 100% ações | `audit.py` obrigatório em todas tools de escrita; pattern documentado |
| Idempotência 0 duplicatas | Chave Redis TTL 5min em `connector.py` |
| CPF mascarado 100% logs | `masking.py` + regra obrigatória documentada em padrões |
| Retenção log ≥ 12 meses | `audit_logs` existente; política via admin Rails existente |
| Cobertura ≥ 80% | 9 arquivos de teste mapeados com escopo definido |
| Disponibilidade 99,5% | Circuit breaker + degradação graciosa + escalonamento humano |

---

### Validação de Prontidão para Implementação

**Completude das decisões:** ✅
- 7 decisões arquiteturais documentadas com rationale
- Stack brownfield: sem versões a verificar — herdadas do codebase
- Exemplos concretos para todos os padrões críticos
- Anti-padrões explícitos documentados

**Completude da estrutura:** ✅
- 21 arquivos novos mapeados (12 Rails + 9 Python)
- 9 arquivos de teste com escopo por arquivo
- 5 fronteiras arquiteturais com protocolo e direção
- Todos os 46 FRs apontam para arquivo específico

**Completude dos padrões:** ✅
- 8 pontos de conflito identificados e resolvidos
- Naming conventions: Python, Ruby, Redis, audit log
- Resposta envelope: padrão único para todas as tools
- Processo: retry, cache, mascaramento, pré-condições

---

### Análise de Gaps

**Gaps críticos:** nenhum — arquitetura pronta para implementação.

**Gaps importantes (a resolver no desenvolvimento):**
| Gap | Impacto | Quando resolver |
|---|---|---|
| `id_tipo_atendimento` HubSoft: valores válidos dependem do ISP | `abrir_protocolo_hubsoft` precisa do ID correto | Na configuração do tenant piloto |
| Token OAuth endpoint interno — rota `/internal/hubsoft/token` não existe ainda | Bloqueante para Processor | 1ª story de implementação (Rails) |
| `plans_sync_job.rb` — frequência de cron (6h) a configurar no Sidekiq | Job não roda sem configuração de schedule | Durante setup do ambiente |
| Mascaramento de `pix_copia_cola` em logs — regra de corte (10 chars?) a definir | Cobertura LGPD | Ao implementar `masking.py` |

**Gaps nice-to-have (pós-MVP):**
- GraphQL schema introspection para leituras agregadas
- Dashboard analítico de auditoria com filtros avançados
- Webhook HubSoft → Evo CRM para eventos de baixa de pagamento em tempo real

---

### Checklist de Completude da Arquitetura

**Análise de Requisitos:**
- [x] Contexto do projeto analisado (46 FRs, 5 categorias NFR)
- [x] Complexidade avaliada: `high` brownfield
- [x] Restrições técnicas identificadas (LGPD, Anatel, OAuth HubSoft)
- [x] Preocupações transversais mapeadas (8 concerns)

**Decisões Arquiteturais:**
- [x] OAuth client: Rails armazena, Processor consome via endpoint interno
- [x] Cache: Redis DB 0, namespace `hubsoft:`, TTLs por tipo
- [x] Audit log: `audit_logs` existente com JSONB
- [x] Estrutura de arquivos: espelha BMS (Rails) + Custom Tools (Python)
- [x] Isolamento por setor: `custom_tool_ids` por agente
- [x] Idempotência: Redis TTL 5min
- [x] Circuit breaker: `connector.py`, 3 falhas, reset 60s

**Padrões de Implementação:**
- [x] Naming conventions: Python, Ruby, Redis, audit log
- [x] Assinatura FunctionTool padrão
- [x] Envelope de resposta: `{status, data, reason}`
- [x] `actor_id` obrigatório em todas as escritas
- [x] Mascaramento antes de logar
- [x] Pré-condição `id_cliente_servico` antes de ação financeira/técnica
- [x] 8 anti-padrões documentados

**Estrutura do Projeto:**
- [x] 21 arquivos novos definidos (12 Rails + 9 Python)
- [x] 5 fronteiras arquiteturais com protocolo
- [x] Mapeamento 46 FRs → arquivo específico
- [x] 9 arquivos de teste com escopo
- [x] Fluxo de dados end-to-end documentado

**MVP via Ferramentas Personalizadas (Fase 0 + Fase 1):**
- [x] 7 Ferramentas Personalizadas definidas (endpoint, método, params, descrição)
- [x] 5 agentes com prompts completos
- [x] Regras de transferência para humano por agente + time
- [x] Configuração "Devolver ao finalizar" definida
- [x] Sequência de implementação em 3 semanas

---

### Avaliação de Prontidão

**Status geral:** ✅ **PRONTO PARA IMPLEMENTAÇÃO**

**Nível de confiança:** Alto

**Pontos fortes da arquitetura:**
1. Zero modificação de código do produto para o MVP (Ferramentas Personalizadas)
2. Padrões de implementação da Fase 2 espelham código existente — curva zero
3. `audit_logs` existente elimina migration complexa
4. Circuit breaker + idempotência garantem segurança operacional
5. State machine LGPD resolve compliance e risco de ação em contrato errado

**Áreas para evolução futura:**
- GraphQL após introspecção de schema real do tenant
- Webhook HubSoft → Evo para baixa de pagamento em tempo real
- Multi-tenant (Phase 3)

---

### Handoff para Implementação

**Sequência de primeira implementação:**

```
Story 1 (Rails): hubsoft_token_controller.rb + oauth_client.rb
  → valida OAuth HubSoft no tenant real
  → testa renovação em HTTP 401

Story 2 (Python): connector.py + token_provider.py
  → circuit breaker + cache Redis + idempotência
  → testa circuit breaker com mock HubSoft offline

Story 3 (Python): identification_tools.py
  → state machine LGPD
  → testa todos os estados (UNKNOWN → ACTION_AUTHORIZED)

Story 4 (Python): financial_tools.py
  → consulta + PIX/boleto + desbloqueio
  → testa desbloqueio elegível + recusado + idempotência

Story 5 (Python): support_tools.py
  → status + protocolo + pré-condição financeira

Story 6 (Python): sales_tools.py
  → planos CEP + criar prospecto

Story 7 (Rails): contact_sync_job.rb + contact_mapper.rb
  → sync ao primeiro atendimento

Story 8 (Rails): plans_sync_job.rb
  → Sidekiq cron 6h + catálogo de planos

Story 9: audit.py + masking.py
  → integrado em todas as tools de escrita

Story 10: testes end-to-end no tenant real do ISP piloto
```

**Diretrizes para agentes de IA implementando:**
- Este documento é a referência para todas as decisões arquiteturais
- Seguir padrões da Seção "Padrões de Implementação" sem exceção
- Toda escrita em HubSoft passa por `connector.py` — nunca `requests.get()` direto nas tools
- `actor_id` não é opcional — falha de auditoria = falha de implementação

---

## Estrutura do Projeto e Fronteiras Arquiteturais

### Árvore completa de arquivos novos

Apenas arquivos novos a criar. Arquivos existentes referenciados mas não modificados.

```
evo-ai-crm-community/
├── app/
│   ├── controllers/
│   │   └── internal/
│   │       └── hubsoft_token_controller.rb          # FR35–FR39: endpoint token p/ Processor
│   ├── services/
│   │   └── crm/
│   │       └── hubsoft/
│   │           ├── api/
│   │           │   ├── client.rb                    # HTTP client Rails (Bearer token)
│   │           │   └── oauth_client.rb              # OAuth2 Password Grant + renovação
│   │           ├── mappers/
│   │           │   └── contact_mapper.rb            # HubSoft cliente → Evo CRM Contact
│   │           └── processor_service.rb             # orquestra sync de contato
│   └── jobs/
│       └── crm/
│           └── hubsoft/
│               ├── contact_sync_job.rb              # FR07, FR29: sync ao 1º atendimento
│               └── plans_sync_job.rb                # FR27: sync periódico de catálogo (6h)
├── config/
│   └── routes/
│       └── internal.rb                              # rota /internal/hubsoft/token
└── spec/
    └── services/
        └── crm/
            └── hubsoft/
                ├── api/
                │   ├── client_spec.rb
                │   └── oauth_client_spec.rb
                ├── mappers/
                │   └── contact_mapper_spec.rb
                └── processor_service_spec.rb

evo-ai-processor-community/
└── src/
    └── services/
        └── hubsoft/
            ├── connector.py                         # circuit breaker, cache, retry, backoff
            ├── auth/
            │   └── token_provider.py                # GET Rails /internal/hubsoft/token
            ├── tools/
            │   ├── identification_tools.py          # FR01–FR07: buscar_cliente
            │   ├── financial_tools.py               # FR08–FR13: financeiro, boleto, PIX, desbloqueio
            │   ├── support_tools.py                 # FR14–FR20: status, protocolo, OS
            │   └── sales_tools.py                   # FR21–FR26: planos CEP, prospecto
            └── utils/
                ├── masking.py                       # mask_cpf, mask_pix, mask_linha_digitavel
                └── audit.py                         # helper write → audit_logs

tests/hubsoft/                                       # co-localizado no submodulo processor
    ├── test_connector.py
    ├── test_identification_tools.py
    ├── test_financial_tools.py
    ├── test_support_tools.py
    └── test_sales_tools.py
```

---

### Mapeamento de FRs para arquivos

| FRs | Arquivo(s) | Serviço |
|---|---|---|
| FR01–FR06 — identificação e lookup | `identification_tools.py` | Processor |
| FR07 — sync contato ao 1º atendimento | `contact_sync_job.rb`, `contact_mapper.rb` | CRM Rails |
| FR08–FR10 — consulta financeira, PIX, boleto | `financial_tools.py` | Processor |
| FR11–FR12 — elegibilidade e desbloqueio | `financial_tools.py` | Processor |
| FR13 — log financeiro | `audit.py` + `financial_tools.py` | Processor |
| FR14 — status e última conexão | `support_tools.py` | Processor |
| FR15 — verificação bloqueio financeiro | `support_tools.py` (pré-condição) | Processor |
| FR16 — extrato Radius | `support_tools.py` | Processor |
| FR17–FR18 — abertura protocolo/OS | `support_tools.py` | Processor |
| FR19–FR20 — log suporte + handoff | `audit.py` + `support_tools.py` | Processor |
| FR21–FR23 — classificação lead, planos CEP | `sales_tools.py` | Processor |
| FR24–FR25 — captura dados, criação prospecto | `sales_tools.py` | Processor |
| FR26 — escalonamento vendas | `sales_tools.py` (retorno status) | Processor |
| FR27 — sync catálogo planos | `plans_sync_job.rb` | CRM Rails |
| FR28 — cache por TTL | `connector.py` | Processor |
| FR29 — atualização contato | `contact_sync_job.rb`, `contact_mapper.rb` | CRM Rails |
| FR30–FR34 — audit log + RBAC | `audit.py` → tabela `audit_logs` | Processor + Rails |
| FR35–FR36 — config credenciais + teste OAuth | `oauth_client.rb`, admin UI existente | CRM Rails |
| FR37–FR38 — config N8N/MCP | admin UI existente (app_configs) | CRM Rails |
| FR39 — renovação token automática | `oauth_client.rb` + `token_provider.py` | Rails + Processor |
| FR40–FR41 — degradação graciosa, escalonamento | `connector.py` (circuit breaker) | Processor |
| FR42 — idempotência | `connector.py` (chave Redis TTL 5min) | Processor |
| FR43 — prazo PIX | `financial_tools.py` (instrução no retorno) | Processor |
| FR44 — toolset por setor | `custom_tool_ids` por agente (config UI) | Config agentes |
| FR45 — N8N/MCP escape hatch | `tool_builder.py` existente (já suporta) | Processor |
| FR46 — actor_id IA | `audit.py` + `tool_context.agent_name` | Processor |

---

### Fronteiras arquiteturais

**Fronteira 1 — Frontend ↔ CRM Rails**
```
Frontend (React :5173)
  → GET/POST /api/v1/admin/app_configs    # configurar credenciais HubSoft (FR35)
  → GET /api/v1/admin/audit_logs          # visualizar log (FR31–FR32)
  NÃO acessa HubSoft diretamente — nunca
```

**Fronteira 2 — CRM Rails ↔ Processor**
```
CRM Rails (:3000)
  → GET /internal/hubsoft/token           # Processor busca token (decisão Arch-1)
  Processor (:8000)
  → POST /api/v1/hubsoft/sync_contact     # CRM aciona sync após evento WhatsApp
```

**Fronteira 3 — Processor ↔ HubSoft**
```
Processor Python
  → HTTPS REST HubSoft (todos os endpoints)
  Autenticação: Bearer token via token_provider.py
  Circuit breaker: connector.py
  Cache: Redis DB 0 namespace hubsoft:
  NÃO passa credenciais HubSoft para além do Processor
```

**Fronteira 4 — CRM Rails ↔ HubSoft (sync apenas)**
```
CRM Rails (Sidekiq)
  → GET /api/v1/integracao/cliente        # contact_sync_job.rb
  → GET /api/v1/integracao/prospecto/create?cep= # plans_sync_job.rb
  Apenas operações de leitura/sync — sem ações financeiras ou técnicas
```

**Fronteira 5 — evolution-go/api ↔ CRM Rails**
```
evolution-go → webhook → CRM Rails
  → dispara contact_sync_job ao receber mensagem de número novo
  → agente IA começa fluxo de identificação
```

---

### Fluxo de dados — atendimento financeiro completo

```
Cliente WhatsApp
  → evolution-go (webhook)
    → CRM Rails (evento de mensagem)
      → contact_sync_job.rb (background, < 30s)
        → GET /cliente?busca=telefone (HubSoft)
        → contact_mapper.rb → Contact.upsert
      → Agente Raiz (processor)
        → identification_tools.py
          → connector.py → cache Redis OU GET /cliente HubSoft
          → tool_context.state["id_cliente_servico"] = 22703
      → Sub-agente Financeiro (processor)
        → financial_tools.py
          → connector.py → GET /cliente/financeiro HubSoft
          → retorna: {pix_copia_cola, linha_digitavel, link, valor}
        → agente envia PIX ao cliente
        → [opcional] POST /desbloqueio_confianca
          → connector.py (verifica idempotência Redis)
          → audit.py → audit_logs.create!
      → CRM Rails recebe log via internal endpoint
```

---

### Testes — organização e cobertura mínima

| Arquivo | Tipo | Cobertura mínima |
|---|---|---|
| `connector.py` | Unit + integration | Circuit breaker, cache TTL, idempotência, retry |
| `identification_tools.py` | Unit | State machine LGPD (todos os estados) |
| `financial_tools.py` | Unit + integration | PIX/boleto retorno, desbloqueio elegível/recusado |
| `support_tools.py` | Unit | Pré-condição financeira, abertura protocolo |
| `sales_tools.py` | Unit | Planos por CEP fibra vs móvel, criar prospecto |
| `masking.py` | Unit | Todos os tipos de dado sensível |
| `audit.py` | Unit | actor_id presente, campos obrigatórios |
| `oauth_client.rb` | Unit | Renovação em 401, storage em app_configs |
| `contact_mapper.rb` | Unit | Campos HubSoft → Contact Rails |

**Meta:** ≥ 80% de cobertura em `src/services/hubsoft/` e `app/services/crm/hubsoft/`.

---

## Análise de Contexto do Projeto

### Visão Geral dos Requisitos

**Requisitos Funcionais:**

46 FRs organizados em 9 áreas. Distribuição e implicações arquiteturais:

| Área | FRs | Implicação Arquitetural |
|---|---|---|
| Identificação de cliente | FR01–FR07 | State machine no processor; lookup silencioso + sync Rails |
| Financeiro | FR08–FR13 | FunctionTools no processor; idempotência obrigatória em FR12 |
| Suporte técnico | FR14–FR20 | FunctionTools por setor; verificação de pré-condição (FR15) |
| Vendas/pré-venda | FR21–FR26 | Fluxo separado sem `id_cliente_servico`; escrita em HubSoft + Evo CRM |
| Sync e cache | FR27–FR29 | Background jobs Rails; Redis cache com TTL por tipo |
| Auditoria | FR30–FR34 | Tabela dedicada com `actor_id`; RBAC no acesso ao log |
| Configuração/admin | FR35–FR39 | `app_configs` criptografado; toggle N8N sem redeploy |
| Resiliência | FR40–FR43 | Circuit breaker; degradação graciosa; sem 500 exposto |
| Integração IA | FR44–FR46 | `custom_tool_ids` por agente; `actor_id` em todos os FunctionTools |

**Requisitos Não-Funcionais Críticos:**

| NFR | Critério | Impacto Arquitetural |
|---|---|---|
| Latência P95 consulta simples | < 3s | Cache obrigatório; sem `cliente/all` em tempo real |
| Latência P95 fluxo completo | < 6s | Tools assíncronas; circuit breaker com timeout configurado |
| Token HubSoft no frontend | 0 ocorrências | Conector 100% no backend (processor + Rails) |
| `actor_id` em 100% das ações | Verificado por teste | Campo não-nullable na tabela de audit log |
| Idempotência desbloqueio/protocolo | 0 duplicatas em retry | Chave de idempotência por (`id_cliente_servico` + ação + janela 5min) |
| Mascaramento CPF/CNPJ em logs | 100% entradas | Middleware de sanitização antes de write em log |
| Retenção log | ≥ 12 meses | Particionamento por data ou política de arquivamento |
| Cobertura de testes | ≥ 80% em `hubsoft/` | Testabilidade como constraint de design |

**Escala e Complexidade:**

- **Domínio primário:** backend API + integração ERP + agente IA
- **Nível de complexidade:** `high` — multi-contrato por cliente, OAuth externo, compliance LGPD + Anatel, IA no caminho crítico, idempotência em operações com efeitos colaterais externos
- **Componentes arquiteturais estimados:** 8 (OAuth client, connector, 3× tool modules, sync jobs, audit log, admin config UI)

---

### Restrições e Dependências Técnicas

**Stack existente (brownfield):**
- Rails CRM (`:3000`) ↔ Python Processor (`:8000`) via HTTP/REST + Fernet API key
- Redis (DB 0) para cache Sidekiq do CRM; disponível para cache HubSoft
- `app_configs` Rails — mecanismo AES-256 já usado por BMS e LeadSquared para tokens externos
- `ToolBuilder.build_tools()` + `custom_tool_ids` — carregamento condicional de FunctionTools já suportado
- BMS pattern (`services/crm/bms/`) — referência direta para estrutura do sync Rails

**Dependências externas:**
- HubSoft tenant real: `host`, `client_id`, `client_secret`, usuário técnico, permissões OAuth — **bloqueante para validação**
- Confirmação da regra de desbloqueio em confiança configurada no HubSoft do ISP piloto
- Schema GraphQL: **bloqueado no MVP** — apenas REST documentado; GraphQL pós-introspecção real
- N8N MCP Server: opcional por ISP — não está no caminho crítico

**Restrições hard:**
- Credenciais HubSoft nunca chegam ao frontend (bloqueado por arquitetura, não só por configuração)
- N8N/MCP proibido em operações síncronas do fluxo de atendimento (latência imprevisível)
- `id_cliente_servico` obrigatório em todas as ações financeiras e técnicas — `id_cliente` sozinho é insuficiente
- CPF/CNPJ nunca em mensagem de confirmação antes de `IDENTITY_CONFIRMED`

---

### Preocupações Transversais Identificadas

| Concern | Afeta | Abordagem |
|---|---|---|
| **Autenticação OAuth HubSoft** | Todos os módulos do conector | Cliente OAuth centralizado com renovação automática; token em `app_configs` |
| **`actor_id` em auditoria** | Todos os FunctionTools + sync jobs | Campo obrigatório injetado no contexto de cada operação |
| **Idempotência** | Desbloqueio em confiança, abertura de protocolo | Chave composta por `id_cliente_servico` + tipo de ação + janela temporal |
| **Circuit breaker** | Todos os calls HubSoft | Implementado em `connector.py`; compartilhado entre tools |
| **Mascaramento de dados sensíveis** | Logs, traces, respostas ao frontend | Middleware/decorator aplicado antes de qualquer write em log |
| **RBAC por setor** | FunctionTools do agente IA | `custom_tool_ids` por agente — toolset financeiro ≠ suporte ≠ vendas |
| **Cache invalidation** | Dados de cliente e financeiro | Invalidação por evento (ação que muda status) além de TTL |
| **Estado de identidade LGPD** | State machine de identificação | Enum de estado (`UNKNOWN → ACTION_AUTHORIZED`) compartilhado entre tools |

---

## MVP — Arquitetura de Agentes e Ferramentas

### Visão geral

MVP implementado **sem modificar código do produto** — usa Ferramentas Personalizadas (HTTP tools via UI) e configuração de agentes/sub-agentes já disponível no Evo CRM.

**Fase 0:** importação da base HubSoft via CSV (script externo + import nativo).  
**Fase 1:** agentes com Ferramentas Personalizadas fazendo chamadas REST em tempo real.

---

### Hierarquia de agentes

```
Agente Raiz  (triagem + identificação LGPD + roteamento)
├── Sub-agente Financeiro
│     Tools: consultar_financeiro_hubsoft
│             desbloquear_confianca_hubsoft
├── Sub-agente Suporte
│     Tools: status_conexao_hubsoft
│             abrir_protocolo_hubsoft
├── Sub-agente Vendas Fibra
│     Tools: planos_por_cep_hubsoft  (filtro fibra)
│             criar_prospecto_hubsoft
└── Sub-agente Vendas Móvel
      Tools: planos_por_cep_hubsoft  (filtro móvel)
              criar_prospecto_hubsoft
```

**Total:** 7 Ferramentas Personalizadas · 5 agentes · 4 times no Evo CRM

---

### Ferramentas Personalizadas (definição completa)

#### Tool 1 — `buscar_cliente_hubsoft`
| Campo | Valor |
|---|---|
| Método | GET |
| Endpoint | `https://{hubsoft_host}/api/v1/integracao/cliente` |
| Headers | `Authorization: Bearer {hubsoft_token}` |
| Query params | `busca` (cpf_cnpj \| telefone \| codigo_cliente), `termo_busca`, `cancelado=nao`, `ultima_conexao=sim` |
| Descrição para o agente | Busca cliente no HubSoft. Use `busca=telefone` para lookup silencioso ao iniciar atendimento. Use `busca=cpf_cnpj` quando cliente informa CPF. Retorna `id_cliente`, `servicos[]` com `id_cliente_servico`, `status_prefixo` e última conexão. |

#### Tool 2 — `consultar_financeiro_hubsoft`
| Campo | Valor |
|---|---|
| Método | GET |
| Endpoint | `https://{hubsoft_host}/api/v1/integracao/cliente/financeiro` |
| Headers | `Authorization: Bearer {hubsoft_token}` |
| Query params | `busca=id_cliente_servico`, `termo_busca` (id_cliente_servico), `apenas_pendente=sim` |
| Descrição para o agente | Consulta faturas pendentes. OBRIGATÓRIO: usar apenas após confirmar `id_cliente_servico`. Retorna numa mesma fatura: `pix_copia_cola` (PIX), `linha_digitavel` + `link` (boleto), `valor`, `data_vencimento`. |

#### Tool 3 — `desbloquear_confianca_hubsoft`
| Campo | Valor |
|---|---|
| Método | POST |
| Endpoint | `https://{hubsoft_host}/api/v1/integracao/cliente/desbloqueio_confianca` |
| Headers | `Authorization: Bearer {hubsoft_token}`, `Content-Type: application/json` |
| Body params | `id_cliente_servico` (integer), `dias_desbloqueio` (integer — 1 ou 2) |
| Descrição para o agente | Executa desbloqueio temporário em confiança. Usar SOMENTE quando `status_prefixo=bloqueado_financeiro` e cliente confirmar pagamento. Se HubSoft recusar, NÃO retente — informe cliente e transfira para humano. |

#### Tool 4 — `status_conexao_hubsoft`
| Campo | Valor |
|---|---|
| Método | GET |
| Endpoint | `https://{hubsoft_host}/api/v1/integracao/cliente` |
| Headers | `Authorization: Bearer {hubsoft_token}` |
| Query params | `busca=cpf_cnpj` ou `id_cliente_servico`, `termo_busca`, `ultima_conexao=sim` |
| Descrição para o agente | Consulta status técnico e última conexão do serviço. SEMPRE use antes de diagnóstico técnico para distinguir: `bloqueado_financeiro` (→ Financeiro) vs falha técnica (→ troubleshooting) vs conectado normal (→ verificar dispositivo cliente). |

#### Tool 5 — `abrir_protocolo_hubsoft`
| Campo | Valor |
|---|---|
| Método | POST |
| Endpoint | `https://{hubsoft_host}/api/v1/integracao/atendimento` |
| Headers | `Authorization: Bearer {hubsoft_token}`, `Content-Type: application/json` |
| Body params | `id_cliente_servico`, `id_tipo_atendimento`, `descricao`, `nome`, `telefone`, `email`, `abrir_os` (boolean) |
| Descrição para o agente | Abre protocolo de suporte. Usar quando problema técnico confirmado ou inconclusivo após troubleshooting básico. Incluir na `descricao` tudo que foi verificado. Retorna número do protocolo — informar ao cliente. |

#### Tool 6 — `planos_por_cep_hubsoft`
| Campo | Valor |
|---|---|
| Método | GET |
| Endpoint | `https://{hubsoft_host}/api/v1/integracao/prospecto/create` |
| Headers | `Authorization: Bearer {hubsoft_token}` |
| Query params | `cep` (string, obrigatório) |
| Descrição para o agente | Retorna `servicos[]` com planos disponíveis para o CEP. Cada item contém `id_servico`, `descricao`, `valor`, `velocidade_download`, `velocidade_upload`. Filtre por tecnologia: FIBRA para sub-agente Fibra, MOVEL/4G/5G para sub-agente Móvel. Atenção: resultado é pré-filtro comercial — viabilidade física (porta/CTO) requer técnico. |

#### Tool 7 — `criar_prospecto_hubsoft`
| Campo | Valor |
|---|---|
| Método | POST |
| Endpoint | `https://{hubsoft_host}/api/v1/integracao/prospecto` |
| Headers | `Authorization: Bearer {hubsoft_token}`, `Content-Type: application/json` |
| Body params | `cep`, `servico` (`{id_servico, valor}`), `nome_razaosocial`, `cpf_cnpj`, `telefone`, `tipo_pessoa` (pf/pj), `bairro`, `endereco`, `numero` |
| Descrição para o agente | Cria prospecto no HubSoft. Usar após cliente confirmar interesse em plano específico. Coletar nome, CPF/CNPJ, telefone e CEP antes de chamar. Após criar, transferir para time Comercial para fechar venda. |

---

### Prompts dos agentes

#### Agente Raiz — Triagem, Identificação e Roteamento

```
Você é o atendente virtual do [Nome do ISP]. Siga SEMPRE esta sequência:

IDENTIFICAÇÃO (obrigatória antes de qualquer ação):
1. Use buscar_cliente_hubsoft com busca=telefone e o número do WhatsApp do contato.
2. Se encontrar 1 cliente: confirme identidade perguntando rua ou bairro cadastrado.
   NUNCA mencione o CPF, CNPJ, fatura ou dados financeiros antes desta confirmação.
3. Se encontrar múltiplos ou nenhum: peça CPF ou CNPJ.
4. Após confirmar identidade: liste os serviços ativos (nome do plano e tipo).
   NÃO exiba status financeiro na listagem.
5. Se múltiplos serviços: "Para qual serviço você precisa de atendimento?
   Fibra [endereço] ou Móvel [número]?"
6. Registre o id_cliente_servico confirmado para passar ao sub-agente.

ROTEAMENTO (após identificação):
- "pagamento", "boleto", "PIX", "fatura", "cobrança", "bloqueado" → Sub-agente Financeiro
- "internet", "sem sinal", "caiu", "lento", "não conecta", "técnico" → Sub-agente Suporte
- "contratar", "quero fibra", "plano fibra", "internet em casa", "instalação" → Sub-agente Vendas Fibra
- "chip", "celular", "móvel", "4G", "5G", "plano celular" → Sub-agente Vendas Móvel
- Ambíguo fibra/móvel: "É para internet em casa (fibra) ou para o celular?"

NUNCA execute ações financeiras ou técnicas sem id_cliente_servico confirmado.
```

#### Sub-agente Financeiro

```
Você resolve demandas de cobrança e pagamento. Recebe id_cliente_servico já confirmado.

FLUXO:
1. Use consultar_financeiro_hubsoft (busca=id_cliente_servico, apenas_pendente=sim).
2. Se houver fatura pendente, pergunte: "Prefere pagar por PIX ou boleto?"
   - PIX: envie o campo pix_copia_cola exatamente como retornado.
   - Boleto: envie linha_digitavel + link do PDF.
3. Se serviço com status bloqueado_financeiro e cliente alegar pagamento recente:
   "O PIX/boleto pode levar alguns minutos para compensar. Posso verificar
   se você está elegível para desbloqueio temporário enquanto aguarda."
4. Para desbloqueio em confiança: use desbloquear_confianca_hubsoft com dias_desbloqueio=1.
   Se HubSoft recusar: "Não foi possível liberar automaticamente. Vou transferir
   para nossa equipe financeira." → transfira para humano.
5. NUNCA prometa reconexão antes de nova confirmação de quitação no HubSoft.

Antes de transferir para humano, envie mensagem interna:
"Cliente: [nome] | id_cliente_servico: [id] | Fatura: R$[valor] venc.[data] |
Motivo: [motivo da transferência] | Já consultado: [o que foi feito]"
```

#### Sub-agente Suporte

```
Você faz triagem técnica. Recebe id_cliente_servico já confirmado.

FLUXO:
1. Use status_conexao_hubsoft para verificar última conexão e status do serviço.
2. Se status_prefixo = bloqueado_financeiro:
   "Vi que seu serviço está com pendência financeira. Vou te transferir
   para nossa equipe de cobrança." → transfira para Sub-agente Financeiro.
3. Se desconectado: guie troubleshooting básico:
   - Roteador está ligado? Luzes indicam problema?
   - Cabos estão conectados?
   - Tentou reiniciar o roteador (desligar 30s)?
4. Se problema persistir ou inconclusivo após troubleshooting:
   Use abrir_protocolo_hubsoft com descrição completa do diagnóstico.
   Informe o número do protocolo ao cliente.
5. Diagnóstico de ONU/OLT, potência óptica, troca de equipamento: transfira para humano.

Antes de transferir, envie mensagem interna:
"Cliente: [nome] | id_cliente_servico: [id] | Última conexão: [status] |
Troubleshooting feito: [o que foi testado] | Protocolo: [número se aberto]"
```

#### Sub-agente Vendas Fibra

```
Você atende interessados em fibra óptica. Não exige id_cliente_servico (lead pode não ser cliente).

FLUXO:
1. "Para verificar os planos disponíveis, qual é o CEP do endereço de instalação?"
2. Use planos_por_cep_hubsoft. Apresente APENAS planos de FIBRA (GPON/FTTH/fibra).
   Para cada plano: nome, velocidade download, velocidade upload, valor mensal.
3. Se cliente escolher plano, colete: nome completo, CPF/CNPJ, telefone.
4. Use criar_prospecto_hubsoft e confirme: "Prospecto criado! Nosso consultor
   entrará em contato para confirmar disponibilidade e agendar a instalação."
5. Transferir para time Comercial após criar o prospecto.

ATENÇÃO: planos por CEP são estimativa comercial. Viabilidade física (porta/CTO/capacidade)
é confirmada pelo técnico na visita. Nunca garantir instalação antes da visita técnica.

Antes de transferir, envie mensagem interna:
"Lead: [nome] | CPF: [cpf] | Tel: [tel] | CEP: [cep] | Plano escolhido: [nome/id] |
id_prospecto: [id retornado pelo HubSoft]"
```

#### Sub-agente Vendas Móvel

```
Você atende interessados em planos de celular. Não exige id_cliente_servico.

FLUXO:
1. "Para verificar planos disponíveis, qual é o seu CEP?"
2. Use planos_por_cep_hubsoft. Apresente APENAS planos MÓVEIS (4G/5G/chip/celular).
   Para cada plano: nome, tipo (pré/pós), franquia de dados, valor.
3. Pergunte: "É um plano novo ou você quer portabilidade de outra operadora?"
   - Portabilidade: "Para portabilidade, nosso consultor precisa orientar o processo."
     Colete nome + telefone e transfira para time Comercial.
   - Plano novo: colete nome completo, CPF/CNPJ, telefone.
4. Use criar_prospecto_hubsoft e confirme: "Registrado! Nosso consultor
   entrará em contato para ativar seu chip."
5. Transferir para time Comercial.

Antes de transferir, envie mensagem interna:
"Lead: [nome] | CPF: [cpf] | Tel: [tel] | Plano: [nome/id] |
Portabilidade: [sim/não] | id_prospecto: [id]"
```

---

### Regras de transferência para humano

| Agente | Time | Quando transferir |
|---|---|---|
| **Raiz** | Atendimento Geral | Cliente pede humano; falha de identificação após 2 tentativas; raiva/emergência; assunto fora do escopo |
| **Financeiro** | Financeiro | Negociação/desconto/parcelamento/cancelamento; HubSoft recusa desbloqueio; contestação de fatura; erro de API |
| **Suporte** | Suporte Técnico | Problema persiste após protocolo; queda regional; visita urgente; reset de equipamento/PPPoE/MAC; erro de API |
| **Vendas Fibra** | Comercial | Plano empresarial; CEP sem cobertura; negociação; prospecto criado (fechar venda) |
| **Vendas Móvel** | Comercial | Portabilidade; múltiplas linhas; plano empresarial; prospecto criado |

**Configuração "Devolver ao finalizar":**
- ✅ Ativar: Financeiro e Suporte (humano resolve, conversa volta ao agente)
- ❌ Desativar: Comercial (consultor conduz até o fechamento)

---

### Times a criar no Evo CRM

| Time | Agentes que recebem transferência |
|---|---|
| Atendimento Geral | Agente Raiz |
| Financeiro | Sub-agente Financeiro |
| Suporte Técnico | Sub-agente Suporte |
| Comercial | Sub-agente Vendas Fibra + Vendas Móvel |

---

### Fase 0 — Importação CSV da base HubSoft

Script externo (sem instalar nada no servidor) chama `GET /cliente/all` e gera CSV no formato nativo do Evo CRM. Campos `id_cliente` e `id_cliente_servico` gravados no campo `descricao` para referência futura dos agentes.

**Colunas do CSV gerado:**
```
tipo, nome, primeiro_nome, sobrenome, email, telefone, cpf_cnpj,
website, segmento_industria, cidade, pais, codigo_pais,
linkedin, facebook, instagram, twitter, github,
descricao, empresas_vinculadas, custom_attribute_1, custom_attribute_2
```

`descricao` = `"id_cliente:{X} | id_servico:{Y} | plano:{nome} | status:{status_prefixo}"`

Upload via: Contatos → Importar → selecionar CSV.

---

---

## Stack Tecnológica (Brownfield — sem starter)

Projeto é extensão do Evo CRM Community existente. Stack já definida — nenhum starter aplicável.

| Camada | Tecnologia | Versão | Uso na integração HubSoft |
|---|---|---|---|
| CRM Backend | Ruby on Rails | 7.1 / Ruby 3.4 | Sync jobs, `app_configs`, OAuth token storage |
| Processor (IA) | Python / FastAPI | 3.10 | FunctionTools HubSoft, connector, circuit breaker |
| Frontend | React / TypeScript / Vite | — | Config UI de credenciais HubSoft, log de auditoria |
| Cache / Jobs | Redis + Sidekiq | — | Cache TTL por tipo, background jobs de sync |
| Banco de dados | PostgreSQL + pgvector | — | Audit log, contatos, `app_configs` |
| WhatsApp | evolution-go / evolution-api | — | Canal de entrada; dispara lookup silencioso |

---

## Decisões Arquiteturais Centrais

### Prioridade das decisões

**Críticas (bloqueiam implementação):**
- OAuth client: onde vive e como o Processor acessa o token
- Audit log: tabela nova ou existente
- Cache: namespace e invalidação

**Importantes (moldam arquitetura):**
- Estrutura de arquivos do conector
- Toolset por setor: mecanismo de isolamento
- Idempotência: chave e janela temporal

**Diferidas (pós-MVP):**
- GraphQL HubSoft (bloqueado até introspecção de schema real)
- Multi-tenant (Phase 3)
- Particionamento do audit log por data

---

### Decisão 1 — OAuth Client HubSoft: armazenamento e acesso

**Decisão:** Rails armazena token em `app_configs` (AES-256, mesmo mecanismo BMS/LeadSquared). Processor acessa via endpoint interno Rails `/internal/hubsoft/token`.

**Rationale:** token em lugar único, já criptografado, já auditável. Processor não duplica lógica de storage. Call extra é irrelevante — token dura 30 dias, renovação é evento raro.

**Implementação:**
```
Rails:
  app/services/crm/hubsoft/api/oauth_client.rb   # obtém + renova token HubSoft
  app/controllers/internal/hubsoft_token_controller.rb  # expõe token ao Processor

Processor:
  src/services/hubsoft/auth/token_provider.py    # GET Rails /internal/hubsoft/token
```

**Fluxo de renovação:**
1. Processor chama HubSoft → recebe HTTP 401
2. Processor chama Rails `/internal/hubsoft/token?refresh=true`
3. Rails chama `POST /oauth/token` HubSoft → salva novo token em `app_configs`
4. Rails retorna token ao Processor
5. Processor retry a chamada original

---

### Decisão 2 — Cache HubSoft

**Decisão:** Redis DB 0 existente. Namespace `hubsoft:` por prefixo. Sem novo Redis DB.

| Chave Redis | TTL | Invalidação ativa |
|---|---|---|
| `hubsoft:client:{id_cliente}` | 120s | Após qualquer ação que mude cadastro |
| `hubsoft:financial:{id_cliente_servico}` | 60s | Após desbloqueio executado |
| `hubsoft:plans:{cep}` | 21600s (6h) | Sync periódico do catálogo |
| `hubsoft:status:{id_cliente_servico}` | 30s | Após abertura de protocolo |

**Regra de ouro:** dados financeiros e status NUNCA ficam em cache por mais de 60s. Catálogo de planos pode ficar até 24h.

---

### Decisão 3 — Audit Log

**Decisão:** reusar tabela `audit_logs` existente (já tem `user_id`, `action`, `resource_type`, `resource_id`, `details` JSONB, `success`, índices GIN em `details`).

**Campos HubSoft em `details` JSONB:**
```json
{
  "actor_id": "agent_uuid_ou_user_uuid",
  "actor_type": "human | ai_agent",
  "id_cliente_servico": 22703,
  "id_cliente": 11201,
  "hubsoft_action": "desbloqueio_confianca | envio_boleto | abertura_protocolo | ...",
  "hubsoft_response": "success | refused | error",
  "masked_data": { "cpf": "***.***.***-01", "fatura_id": 43653 }
}
```

**`resource_type`** = `"HubsoftIntegration"` · **`action`** = tipo de operação HubSoft.

**RBAC no acesso ao log:**
- `account_owner`: filtra por qualquer `user_id` + período
- `agent`: filtra apenas `user_id = current_user.id`

---

### Decisão 4 — Estrutura de arquivos do conector

**Decisão:** seguir exatamente o padrão BMS para Rails, exatamente o padrão Custom Tools para Python.

```
evo-ai-crm-community/
  app/services/crm/hubsoft/
    api/
      client.rb              # HTTP client com Bearer token
      oauth_client.rb        # obtém/renova token OAuth HubSoft
    mappers/
      contact_mapper.rb      # HubSoft cliente → Evo CRM Contact
  app/jobs/crm/hubsoft/
    contact_sync_job.rb      # disparado no primeiro atendimento
    plans_sync_job.rb        # Sidekiq cron, a cada 6h
  app/controllers/internal/
    hubsoft_token_controller.rb  # endpoint interno para Processor

evo-ai-processor-community/
  src/services/hubsoft/
    connector.py             # circuit breaker, cache Redis, retry, backoff
    tools/
      identification_tools.py   # buscar_cliente (FR01–FR07)
      financial_tools.py        # consultar_financeiro, desbloquear (FR08–FR13)
      support_tools.py          # status_conexao, abrir_protocolo (FR14–FR20)
      sales_tools.py            # planos_por_cep, criar_prospecto (FR21–FR26)
    auth/
      token_provider.py         # GET Rails /internal/hubsoft/token
```

---

### Decisão 5 — Isolamento de toolset por setor

**Decisão:** `custom_tool_ids` por agente (mecanismo já suportado por `ToolBuilder.build_tools()`). Cada sub-agente recebe apenas os IDs das tools do seu setor. Agente Raiz não recebe nenhuma tool HubSoft — só roteia.

| Agente | `custom_tool_ids` |
|---|---|
| Raiz | `[]` — nenhuma tool HubSoft |
| Financeiro | `[buscar_cliente, consultar_financeiro, desbloquear_confianca]` |
| Suporte | `[buscar_cliente, status_conexao, abrir_protocolo]` |
| Vendas Fibra | `[planos_por_cep, criar_prospecto]` |
| Vendas Móvel | `[planos_por_cep, criar_prospecto]` |

**Guardrail:** agente financeiro tenta abrir protocolo → tool não está em `custom_tool_ids` → ADK retorna erro de permissão. Sem código adicional.

---

### Decisão 6 — Idempotência

**Decisão:** chave Redis com TTL de 5 minutos por operação com efeito colateral externo.

```python
# Chave: hubsoft:idempotency:{tipo_acao}:{id_cliente_servico}:{hash_params}
# TTL: 300s (5 minutos)
# Se chave existe: retorna resultado cacheado sem chamar HubSoft
# Operações cobertas: desbloqueio_confianca, abrir_protocolo
```

---

### Decisão 7 — Circuit Breaker

**Decisão:** implementado em `connector.py`, compartilhado por todos os tools.

- 3 falhas consecutivas → estado OPEN
- Estado OPEN: retorna erro gracioso + escala para humano (FR41)
- Reset após 60s (estado HALF-OPEN → teste → CLOSED ou OPEN)
- Timeout por chamada: 8s (P95 resposta agente ≤ 8s incluindo call HubSoft)

---

### Análise de impacto das decisões

| Decisão | Componentes afetados | Sequência de implementação |
|---|---|---|
| OAuth via Rails endpoint interno | Rails `oauth_client.rb`, Processor `token_provider.py` | 1º — bloqueante para tudo |
| Cache Redis namespace `hubsoft:` | `connector.py` | 2º — junto com connector |
| Audit log em `audit_logs` existente | Todos os tools Python + jobs Rails | 3º — injetado em cada operação |
| Estrutura de arquivos | Todas as implementações | Define desde o início |
| `custom_tool_ids` por agente | Configuração de agentes na UI | Após tools implementadas |
| Idempotência Redis | `connector.py` + tools de escrita | Junto com desbloqueio e protocolo |
| Circuit breaker | `connector.py` | 2º — junto com connector |

**Dependências críticas:**
```
oauth_client.rb (Rails)
  └── token_provider.py (Processor)
        └── connector.py (circuit breaker + cache + idempotência)
              ├── financial_tools.py
              ├── support_tools.py
              └── sales_tools.py
```

**Padrões de referência no codebase:**
- Sync Rails: `app/services/crm/bms/` + `app/jobs/crm/bms/`
- AI Tools Python: `src/services/adk/custom_tools.py` + `tool_builder.py`
- Token storage: `app_configs` com AES-256 (mesmo padrão BMS/LeadSquared)

---

## Padrões de Implementação e Regras de Consistência

### Pontos críticos de conflito identificados

8 áreas onde agentes de IA poderiam fazer escolhas inconsistentes sem estas regras:
nomeação de chaves Redis · estrutura de FunctionTool · formato de resposta de erro · injeção de `actor_id` · mascaramento de dados sensíveis · padrão de retry/backoff · formato do audit log · convenção de nomes de arquivos.

---

### Padrões de Nomenclatura

**Arquivos Python (processor):**
```
snake_case para tudo:
  financial_tools.py   ✅
  financialTools.py    ❌
  FinancialTools.py    ❌

Classes: PascalCase
  class HubsoftConnector  ✅
  class hubsoft_connector  ❌

Funções/métodos: snake_case
  def buscar_cliente_hubsoft()   ✅
  def buscarClienteHubsoft()     ❌
```

**Arquivos Ruby (CRM):**
```
snake_case para arquivos e métodos — já é convenção Rails:
  hubsoft_contact_mapper.rb   ✅
  HubsoftContactMapper.rb     ❌

Classes: CamelCase
  class HubsoftContactMapper  ✅
```

**Chaves Redis — padrão obrigatório:**
```
hubsoft:{tipo}:{identificador}

hubsoft:client:{id_cliente}              ✅
hubsoft:financial:{id_cliente_servico}   ✅
hubsoft:plans:{cep}                      ✅
hubsoft:idempotency:{acao}:{id_cs}:{hash} ✅

client_hubsoft:{id}   ❌  (prefixo invertido)
hubsoft_{id}          ❌  (underscore em vez de colon)
```

**Endpoints internos Rails → Processor:**
```
/internal/hubsoft/{recurso}

/internal/hubsoft/token      ✅
/internal/hubsoft_token      ❌
/api/v1/internal/hubsoft/... ❌  (não usar namespace api/v1 para rotas internas)
```

---

### Padrões de Estrutura

**Todo FunctionTool HubSoft segue esta assinatura:**
```python
def nome_da_tool(
    tool_context: ToolContext,
    # parâmetros específicos da tool
) -> dict:
    """
    Descrição curta do que faz.
    
    Args:
        tool_context: contexto ADK (contém agent_name, session_id)
        param1: descrição
    
    Returns:
        dict com campos: status, data, error (se houver)
    """
```

**Nunca retornar string direta — sempre dict:**
```python
return {"status": "success", "data": {...}}   ✅
return "Cliente encontrado"                    ❌
return {"cliente": {...}}                      ❌  (sem envelope status)
```

**Injeção de `actor_id` — obrigatória em TODA tool de escrita:**
```python
# Em financial_tools.py, support_tools.py — qualquer POST para HubSoft
actor_id = tool_context.state.get("actor_id") or tool_context.agent_name
audit_log(actor_id=actor_id, action="desbloqueio_confianca", ...)
```

---

### Padrões de Formato

**Resposta padrão de tool HubSoft:**
```python
# Sucesso
{"status": "success", "data": {<payload HubSoft normalizado>}}

# Erro de negócio (HubSoft recusou — ex: desbloqueio não elegível)
{"status": "refused", "reason": "Limite de desbloqueios atingido", "data": {}}

# Erro técnico (HubSoft offline, timeout, circuit breaker aberto)
{"status": "error", "reason": "Serviço temporariamente indisponível", "data": {}}

# Idempotência: operação já executada na janela de 5min
{"status": "duplicate", "reason": "Operação já executada", "data": {<resultado_original>}}
```

**Formato obrigatório de entrada no `audit_logs`:**
```python
AuditLog.create!(
    user_id: actor_uuid,           # UUID do humano ou agente IA
    action: "hubsoft_desbloqueio_confianca",   # prefixo hubsoft_ obrigatório
    resource_type: "HubsoftIntegration",
    resource_id: id_cliente_servico_uuid_ou_string,
    success: response["status"] == "success",
    details: {
        actor_id: actor_id,
        actor_type: "human" | "ai_agent",
        id_cliente_servico: 22703,
        id_cliente: 11201,
        hubsoft_action: "desbloqueio_confianca",
        hubsoft_response: response["status"],
        masked_data: {cpf: mask_cpf(cpf), fatura_id: fatura_id}
    }
)
```

**Mascaramento obrigatório — funções helper:**
```python
# src/services/hubsoft/utils/masking.py
def mask_cpf(cpf: str) -> str:         # "12345678901" → "***.***.***-01"
def mask_pix(pix: str) -> str:         # primeiros 10 chars + "..."
def mask_linha_digitavel(ld: str) -> str:  # primeiros 5 + "..."

# NUNCA logar CPF, CNPJ, pix_copia_cola, linha_digitavel sem mascaramento
logger.info(f"Fatura cliente {mask_cpf(cpf)}")  ✅
logger.info(f"CPF: {cpf}")                       ❌
```

---

### Padrões de Comunicação

**Logging estruturado (Python):**
```python
logger.info("[HubSoft] buscar_cliente", extra={
    "action": "buscar_cliente",
    "busca": "telefone",        # tipo de busca, não o valor
    "found": True,
    "agent": tool_context.agent_name,
    "session": tool_context.session_id,
})
# NUNCA logar o termo_busca (pode ser CPF/telefone)
```

**Propagação de erro ao agente (nunca expor stack trace):**
```python
# connector.py — tratamento central
except HubsoftUnavailableError:
    return {"status": "error", "reason": "Serviço temporariamente indisponível"}
except requests.Timeout:
    return {"status": "error", "reason": "Tempo de resposta excedido"}
# O agente interpreta "error" → escala para humano (FR40, FR41)
```

**Sidekiq jobs Rails — nomenclatura de fila:**
```ruby
queue_as :hubsoft_sync   # fila dedicada, não usar :default ou :low
```

---

### Padrões de Processo

**Retry e backoff — apenas no `connector.py`:**
```python
# Exponential backoff: 1s, 2s, 4s — máximo 3 tentativas
# Não implementar retry em tools individuais — centralizado no connector
# Circuit breaker abre após 3 falhas → sem retry quando OPEN
MAX_RETRIES = 3
BACKOFF_BASE = 1  # segundos
```

**Verificação de pré-condição antes de ação financeira/técnica:**
```python
# Padrão obrigatório em financial_tools e support_tools
# 1. Verificar se id_cliente_servico está em tool_context.state
# 2. Verificar se estado de identidade é IDENTITY_CONFIRMED ou ACTION_AUTHORIZED
# 3. Só então chamar connector
if not tool_context.state.get("id_cliente_servico"):
    return {"status": "refused", "reason": "Serviço não identificado. Volte ao início."}
```

**Cache — sempre via connector, nunca diretamente nas tools:**
```python
# connector.py expõe:
connector.get_cliente(id_cliente, use_cache=True)   ✅
connector.get_financeiro(id_cs, use_cache=True)     ✅

# tools NUNCA acessam Redis diretamente:
redis.get(f"hubsoft:client:{id}")   ❌  (acoplamento)
```

---

### Regras obrigatórias — todo agente de IA DEVE seguir

1. **`actor_id` não é opcional** — toda tool de escrita (POST para HubSoft) loga no `audit_logs` com `actor_id`. Se `tool_context.state["actor_id"]` estiver vazio, usar `tool_context.agent_name` como fallback.

2. **Mascarar antes de logar** — CPF, CNPJ, telefone, `pix_copia_cola`, `linha_digitavel` nunca aparecem em logs sem máscara.

3. **`id_cliente_servico` antes de ação** — tools financeiras e de suporte verificam presença de `id_cliente_servico` em `tool_context.state` antes de chamar o connector.

4. **Respostas sempre como dict com envelope** — `{"status": ..., "data": ..., "reason": ...}`. Nunca string.

5. **Retry apenas no connector** — tools não implementam retry próprio.

6. **Prefixo `hubsoft:` em todas as chaves Redis** — sem exceção.

7. **Prefixo `hubsoft_` em todas as entradas de `audit_logs.action`** — ex: `hubsoft_buscar_cliente`, `hubsoft_desbloqueio_confianca`.

8. **Fila Sidekiq `hubsoft_sync`** — jobs de sync HubSoft não usam filas genéricas.

---

### Anti-padrões

```python
# ❌ Tool retornando string
return "Cliente encontrado com sucesso"

# ❌ Retry dentro de tool
for i in range(3):
    resp = requests.get(...)

# ❌ CPF em log sem máscara
logger.info(f"Buscando CPF {cpf}")

# ❌ Ação financeira sem checar id_cliente_servico
def enviar_boleto(tool_context, **kwargs):
    fatura = connector.get_financeiro(kwargs.get("id_cs"))  # e se id_cs for None?

# ❌ Redis direto na tool
import redis; r = redis.Redis(); r.get("hubsoft:client:123")

# ❌ actor_id não logado em desbloqueio
connector.post_desbloqueio(id_cs=22703, dias=1)  # sem audit_log()
```

---

### Sequência de implementação MVP

```
Semana 1:
  □ Criar usuário técnico dedicado no HubSoft (permissões mínimas)
  □ Obter token OAuth e validar endpoints no tenant real
  □ Rodar script de exportação e importar base via CSV no Evo CRM
  □ Criar 7 Ferramentas Personalizadas na UI

Semana 2:
  □ Criar Sub-agente Financeiro + testar fluxo PIX/boleto + desbloqueio
  □ Criar Sub-agente Suporte + testar abertura de protocolo
  □ Criar Sub-agentes Vendas Fibra e Móvel + testar planos por CEP

Semana 3:
  □ Criar Agente Raiz com roteamento completo
  □ Criar times (Financeiro, Suporte Técnico, Comercial, Atendimento Geral)
  □ Configurar regras de transferência em cada agente
  □ Teste end-to-end com número real do WhatsApp do ISP piloto
  □ Validar checklist LGPD: sem CPF em confirmação, sem dados financeiros antes de IDENTITY_CONFIRMED
```
