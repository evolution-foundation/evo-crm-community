# Prompt — Etapa 4: Create PRD (CP) — OBRIGATÓRIO

**Workflow:** `/evo-bmm-create-prd`
**Agente:** 📋 John (Product Manager)
**Carregar:** `/evo-pm`
**Janela:** Nova janela de contexto
**Pré-requisito:**
- [domain-research-isp-brasil-hubsoft.md](../domain-research-isp-brasil-hubsoft.md) ✅ concluído
- [technical-research-api-hubsoft.md](../technical-research-api-hubsoft.md) ✅ concluído
- [product-brief-hubsoft-integration.md](../product-brief-hubsoft-integration.md) ✅ concluído

---

## Prompt para colar ao agente

```
Preciso criar o PRD completo para a integração HubSoft → Evo CRM Community.
Já tenho o Product Brief aprovado. Vou colar abaixo. Use para produzir um PRD
detalhado com requisitos funcionais, não-funcionais e rotas de integração.

## Stack do Evo CRM Community

| Serviço | Stack | Porta |
|---|---|---|
| evo-ai-crm-community | Ruby 3.4 / Rails 7.1 | 3000 |
| evo-auth-service-community | Ruby 3.4 / Rails 7.1 | 3001 |
| evo-ai-frontend-community | React / TypeScript / Vite | 5173 |
| evo-ai-processor-community | Python 3.10 / FastAPI | 8000 |
| evo-ai-core-service-community | Go / Gin | 5555 |
| evolution-go | Go / Gin (WhatsApp engine) | 8080 |

- Banco: PostgreSQL + pgvector (compartilhado Rails; Go usa schemas próprios)
- Single-tenant: um ISP por instalação
- Auth: JWT compartilhado entre serviços

## HubSoft API

- REST: https://github.com/hubsoftbrasil/api
- GraphQL: https://wiki.hubsoft.com.br/pt-br/api-graphql
- Docs: https://docs.hubsoft.com.br/

## Setores e rotas de integração

### Rota Financeiro
Trigger: cliente contata via WhatsApp com dúvida/reclamação financeira

```
WhatsApp → evolution-go → evo-ai-processor (triagem IA)
  → identifica setor: financeiro
  → chama HubSoft: GET /clientes?cpf={cpf}
  → chama HubSoft: GET /clientes/{id}/financeiro
  → if bloqueado → oferece desbloqueio confiança
      → POST /clientes/{id}/desbloqueio-confianca
  → if inadimplente → gera PIX ou boleto
      → POST /faturas/{id}/pix
      → GET /faturas/{id}/boleto
  → registra atendimento no evo-ai-crm-community
```

### Rota Suporte
Trigger: cliente relata problema de conexão/internet

```
WhatsApp → evolution-go → evo-ai-processor (triagem IA)
  → identifica setor: suporte
  → chama HubSoft: GET /clientes?cpf={cpf}
  → chama HubSoft: POST /clientes/{id}/teste-linha
  → exibe resultado ao cliente
  → if problema confirmado → POST /protocolos (abre chamado)
  → registra protocolo no evo-ai-crm-community
```

### Rota Vendas
Trigger: cliente consulta planos ou demonstra interesse

```
WhatsApp → evolution-go → evo-ai-processor (triagem IA)
  → identifica setor: vendas
  → coleta CEP do cliente
  → chama HubSoft: GET /planos?cep={cep}&tipo=fibra|movel
  → apresenta opções com preços
  → captura interesse → cria lead no evo-ai-crm-community
  → escalona para humano se necessário
```

## O que o PRD deve incluir

1. **Visão e objetivos** — proposta de valor, métricas de sucesso
2. **Personas** — atendente, agente IA, cliente ISP
3. **Requisitos funcionais** por setor (tabela: ID, descrição, prioridade MoSCoW)
4. **Requisitos não-funcionais** — latência (<3s por chamada HubSoft), disponibilidade, segurança (token HubSoft não exposto ao frontend)
5. **Arquitetura de integração** — onde vive o conector HubSoft (processor? novo serviço?)
6. **Modelo de dados** — tabelas/entidades novas no CRM para registrar interações HubSoft
7. **Fluxos detalhados** por rota (diagrama ou narrativa passo a passo)
8. **Identificação de cliente** — estratégia: busca por CPF, telefone, número de contrato; fallback humano
9. **Tratamento de erros** — HubSoft offline, cliente não encontrado, limite desbloqueio atingido
10. **Fora de escopo** — o que NÃO está nesta versão
11. **Épicos e stories de alto nível** — lista inicial para quebrar em sprints
12. **Riscos e dependências**

## Inputs — cole o conteúdo destes arquivos antes de enviar

**Product Brief** (`docs/hubsoft-integration/product-brief-hubsoft-integration.md`):
[cole o conteúdo completo aqui]

**Technical Research** (`docs/hubsoft-integration/technical-research-api-hubsoft.md`):
[cole o conteúdo completo aqui — especialmente tabelas de endpoints e gaps identificados]
```
