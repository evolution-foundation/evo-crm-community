# Prompt — Etapa 3: Create Brief (CB)

**Workflow:** `/evo-bmm-create-product-brief`
**Agente:** 📊 Mary (Business Analyst)
**Carregar:** `/evo-analyst`
**Janela:** Nova janela de contexto
**Pré-requisito:**
- [domain-research-isp-brasil-hubsoft.md](../domain-research-isp-brasil-hubsoft.md) ✅ concluído
- [technical-research-api-hubsoft.md](../technical-research-api-hubsoft.md) ✅ concluído

---

## Prompt para colar ao agente

```
Preciso criar um Product Brief para a integração HubSoft → Evo CRM Community.
Já tenho os resultados de Domain Research e Technical Research. Vou colar abaixo os pontos
principais. Use para criar um brief objetivo e estruturado.

## Contexto do produto

**O quê:** Integração entre Evo CRM Community e o ERP HubSoft para atendimento automatizado
de clientes de provedores de internet (ISPs) via WhatsApp/chat.

**Para quem:** Atendentes e agentes de IA do ISP que precisam resolver demandas de clientes
sem sair do Evo CRM.

**Por quê:** Hoje o atendente precisa acessar o HubSoft separadamente para cada ação
(consultar fatura, desbloquear, testar linha). A integração traz essas ações para dentro
do fluxo de atendimento do CRM com triagem automática por setor.

## Setores e casos de uso

### Setor Financeiro
- Identificar cliente por CPF/telefone
- Verificar situação: adimplente, inadimplente, bloqueado
- Se bloqueado: oferecer desbloqueio de confiança (limite: 1x por mês)
- Se inadimplente: gerar e enviar código PIX ou link de boleto da fatura mais recente
- Registrar interação no CRM

### Setor Suporte
- Identificar cliente e contrato ativo
- Executar teste básico de sinal via API HubSoft
- Exibir resultado ao cliente (sinal OK / sem sinal / sinal fraco)
- Se problema confirmado: abrir protocolo de suporte automaticamente
- Registrar protocolo no CRM

### Setor Vendas
- Buscar planos disponíveis por CEP/endereço
- Apresentar planos fibra óptica e móvel com preços
- Capturar interesse e criar lead no CRM
- Encaminhar para consultor humano se necessário

## Restrições técnicas conhecidas

- Evo CRM: Ruby on Rails 7.1, Go (core-service), Python FastAPI (processor)
- Integração via serviço dedicado (novo microserviço ou módulo no processor)
- HubSoft: autenticação Bearer Token (ver TR), rate limits documentados no TR
- TR identificou gaps: testes de ONU/OLT podem exigir integração direta com NMS do ISP
- Single-tenant: um ISP por instalação

## O que o brief deve definir

1. Proposta de valor em 2 frases
2. Personas principais (atendente, agente IA, cliente final)
3. Casos de uso priorizados (MoSCoW por setor)
4. Escopo fora (o que NÃO faremos nesta versão)
5. Métricas de sucesso (TMA, taxa de resolução no primeiro contato)
6. Riscos e dependências principais
7. Próximos passos → PRD

## Inputs — cole o conteúdo destes arquivos antes de enviar

**Domain Research** (`docs/hubsoft-integration/domain-research-isp-brasil-hubsoft.md`):
[cole o conteúdo completo aqui]

**Technical Research** (`docs/hubsoft-integration/technical-research-api-hubsoft.md`):
[cole o conteúdo completo aqui]
```
