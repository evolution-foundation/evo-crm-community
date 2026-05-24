# Prompt — Etapa 1: Domain Research (DR)

**Workflow:** `/evo-bmm-domain-research`
**Agente:** 📊 Mary (Business Analyst)
**Carregar:** `/evo-analyst`
**Janela:** Nova janela de contexto

---

## Prompt para colar ao agente

```
Preciso de um Domain Research completo sobre o domínio de provedores de internet (ISP) no Brasil
e a integração com o ERP HubSoft via Evo CRM.

## Contexto do projeto

O Evo CRM Community é um CRM open-source single-tenant com capacidades de agentes de IA.
Vamos integrar com o HubSoft — ERP específico para provedores de internet (ISPs) brasileiros —
para atender clientes via WhatsApp/chat em 3 setores:

1. **Financeiro** — Verificar bloqueio por inadimplência, oferecer desbloqueio de confiança,
   gerar e enviar código PIX ou link de boleto
2. **Suporte** — Executar testes básicos de linha/conexão, exibir diagnósticos disponíveis
3. **Vendas** — Consultar planos disponíveis (fibra óptica e planos móveis), vender para
   clientes novos ou fazer upgrade

## Documentação HubSoft disponível

- REST API: https://github.com/hubsoftbrasil/api
- GraphQL API: https://wiki.hubsoft.com.br/pt-br/api-graphql
- Docs gerais: https://docs.hubsoft.com.br/

## Questões que preciso responder

1. Como funciona o modelo de negócio de um ISP brasileiro típico?
2. Quais são os termos técnicos e de negócio específicos do setor (CTO, OLT, GPON, inadimplência, corte, reconexão)?
3. Como o HubSoft modela clientes, contratos, planos e cobranças?
4. Qual o fluxo típico de atendimento em cada setor (financeiro, suporte, vendas)?
5. Quais dados o atendente precisa para identificar um cliente no HubSoft?
6. Que restrições legais/regulatórias existem para bloqueio/desbloqueio de serviço?

## Output esperado

Documento em português com:
- Glossário do domínio ISP + HubSoft
- Fluxos de atendimento por setor (narrativo)
- Entidades principais do HubSoft (cliente, contrato, plano, fatura, protocolo)
- Pontos de atenção e riscos do domínio
```
