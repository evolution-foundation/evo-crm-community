# Prompt — Etapa 2: Technical Research (TR)

**Workflow:** `/evo-bmm-technical-research`
**Agente:** 📊 Mary (Business Analyst)
**Carregar:** `/evo-analyst`
**Janela:** Nova janela de contexto
**Pré-requisito:** [domain-research-isp-brasil-hubsoft.md](../domain-research-isp-brasil-hubsoft.md) ✅ concluído

---

## Prompt para colar ao agente

```
Preciso de um Technical Research sobre a API do HubSoft para mapear todos os endpoints
disponíveis que podemos usar na integração com o Evo CRM.

## Contexto do projeto

Domain Research concluído em: `docs/hubsoft-integration/domain-research-isp-brasil-hubsoft.md`
Fontes usadas: HubSoft REST API, GraphQL, App do Cliente, Wiki HubSoft, Anatel PPP 2025, Resolução Anatel 765/2023, Marco Civil da Internet.

Evo CRM Community (Ruby on Rails 7.1 + Go + Python FastAPI) integrado ao HubSoft ERP via API
para atendimento automatizado de clientes ISP em 3 setores:

1. **Financeiro** — bloqueio/desbloqueio, desbloqueio de confiança, PIX, boleto
2. **Suporte** — testes de linha, diagnósticos de conexão
3. **Vendas** — consulta e venda de planos fibra/móvel

## Documentação oficial HubSoft

- REST API (GitHub): https://github.com/hubsoftbrasil/api
- GraphQL API: https://wiki.hubsoft.com.br/pt-br/api-graphql
- Docs gerais: https://docs.hubsoft.com.br/

## O que preciso mapear

### Autenticação
- Método de autenticação (API Key, OAuth, JWT?)
- Escopos ou permissões por módulo
- Rate limits documentados

### Busca de clientes
- Endpoint para buscar cliente por CPF/CNPJ
- Endpoint para buscar por nome, telefone, endereço
- Endpoint para buscar por número de contrato
- Campos retornados: id, nome, status, plano atual, saldo devedor

### Módulo Financeiro
- Endpoint para verificar situação financeira (adimplente/inadimplente/bloqueado)
- Endpoint para listar faturas em aberto
- Endpoint para gerar código PIX de fatura
- Endpoint para obter link/PDF de boleto
- Endpoint para registrar desbloqueio de confiança
- Endpoint para executar bloqueio/desbloqueio de serviço

### Módulo Suporte
- Endpoint para abrir protocolo de suporte
- Endpoint para executar teste de sinal/linha (ONU, OLT)
- Endpoint para verificar status da conexão do cliente
- Endpoint para listar protocolos abertos do cliente

### Módulo Vendas
- Endpoint para listar planos disponíveis (fibra, móvel)
- Endpoint para verificar cobertura por endereço/CEP
- Endpoint para criar proposta/pré-venda
- Endpoint para consultar status de instalação

### GraphQL
- Queries disponíveis para cada módulo acima
- Mutations disponíveis (desbloqueio, abertura de protocolo)
- Schema principal das entidades

## Output esperado

Documento em português com:
- Tabela de endpoints por módulo (método, path, parâmetros, resposta)
- Exemplos de request/response para os endpoints críticos
- Gaps identificados (o que a API não suporta)
- Recomendação de abordagem: REST vs GraphQL por caso de uso
- Diagrama de sequência simplificado para cada setor (texto/mermaid)
```
