# Integração HubSoft → Evo CRM

ERP para provedores de internet (ISP) integrado ao Evo CRM Community para atendimento triado por setor.

## Setores

| Setor | Objetivo |
|---|---|
| **Financeiro** | Verificar bloqueio por inadimplência, desbloqueio de confiança, enviar PIX/boleto |
| **Suporte** | Testes de linha, diagnósticos disponíveis via API |
| **Vendas** | Planos fibra óptica e móvel, busca de clientes e planos |

## Docs HubSoft

- REST API: https://github.com/hubsoftbrasil/api
- GraphQL: https://wiki.hubsoft.com.br/pt-br/api-graphql
- Docs gerais: https://docs.hubsoft.com.br/

## Sequência de análise

```
1. DR  → Domain Research      (Mary / evo-analyst)
2. TR  → Technical Research   (Mary / evo-analyst)
3. CB  → Create Brief         (Mary / evo-analyst)
4. CP  → Create PRD           (John / evo-pm)      ← OBRIGATÓRIO
```

## Artefatos gerados

- [Domain Research](domain-research-isp-brasil-hubsoft.md)
- [Technical Research](technical-research-api-hubsoft.md)
- [Product Brief](product-brief-hubsoft-integration.md)

## Prompts por etapa

- [01-domain-research.md](prompts/01-domain-research.md)
- [02-technical-research.md](prompts/02-technical-research.md)
- [03-create-brief.md](prompts/03-create-brief.md)
- [04-create-prd.md](prompts/04-create-prd.md)
