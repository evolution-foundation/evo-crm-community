---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success', 'step-04-journeys', 'step-05-domain', 'step-06-innovation', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish']
inputDocuments:
  - docs/hubsoft-integration/product-brief-hubsoft-integration.md
  - docs/hubsoft-integration/technical-research-api-hubsoft.md
workflowType: 'prd'
project: 'evo-crm-community'
feature: 'hubsoft-integration'
classification:
  projectType: saas_b2b
  domain: telecom_isp
  complexity: high
  projectContext: brownfield
---

# PRD: Integração HubSoft → Evo CRM Community

**Autor:** Luiz  
**Data:** 2026-05-24  
**Feature:** `hubsoft-integration`  
**Contexto:** Brownfield — nova feature adicionada ao Evo CRM Community existente

---

## Executive Summary

A integração HubSoft → Evo CRM Community entrega atendimento de ISP seguro, nivelado e rastreável via WhatsApp/chat. Qualquer atendente — novo ou veterano — resolve demandas financeiras, técnicas e comerciais no primeiro contato, com contexto completo do cliente extraído do HubSoft em tempo real, sem risco de ação no contrato errado e com trilha auditável de cada operação.

O produto serve três perfis simultâneos: o **atendente humano** que precisa agir rápido sem alternar sistemas; o **agente de IA** que faz triagem, identifica o `id_cliente_servico` correto e entrega ferramentas seguras e delimitadas por setor; e o **gestor do ISP** que precisa de rastreabilidade completa e garantia de compliance com LGPD antes de autorizar automação no atendimento.

O problema central não é velocidade — é **confiança para agir**: atendente e agente precisam ter certeza de que estão operando no contrato certo, com dados autorizados, antes de executar qualquer ação financeira ou técnica. Sem esse contexto verificado, automação amplifica erros em vez de reduzi-los.

### Diferenciadores

**Triagem IA + contexto HubSoft entregues juntos, com identidade de ator em cada ação.**

1. **Erro zero de contrato:** toda ação é ancorada em `id_cliente_servico` confirmado — nunca apenas `id_cliente`. Clientes com múltiplos serviços não são ambíguos.
2. **Nivelamento de equipe:** agente IA faz triagem e entrega contexto estruturado; atendente junior opera com a mesma segurança do veterano.
3. **Trilha auditável:** cada operação registra `actor_id` (humano ou agente IA), timestamp, dados consultados e ação executada — o ISP prova compliance para auditor sem esforço adicional.
4. **Conector isolado no backend:** credenciais HubSoft nunca chegam ao frontend; token OAuth armazenado criptografado, renovado automaticamente.

### Classificação do Projeto

| Campo | Valor |
|---|---|
| Tipo | `saas_b2b` — plataforma B2B single-tenant com CRM, integrações e automação de atendimento |
| Domínio | `telecom_isp` com elementos de cobrança (PIX, boleto, inadimplência, LGPD) |
| Complexidade | `high` — multi-contrato por cliente, ERP externo, IA no fluxo, compliance LGPD + Anatel |
| Instalação | Single-tenant auto-hospedado na infra do próprio ISP |

---

## Success Criteria

### User Success

| Critério | Meta | Como medir |
|---|---|---|
| Atendente resolve cobrança sem abrir HubSoft | 80% dos atendimentos de cobrança via fluxo integrado em 60 dias | Log de sessões com origem `hubsoft-connector` |
| Zero ação no contrato errado | 0 incidentes de ação em `id_cliente_servico` incorreto | Auditoria de logs |
| Cliente recebe PIX/boleto sem transferência humana | 50% dos casos financeiros elegíveis resolvidos no 1º contato | Taxa de resolução sem escalonamento |
| Gestor rastreia qualquer ação em retrospecto | 100% das ações com `actor_id` + timestamp + `id_cliente_servico` | Verificação de completude do log |
| Gestor exporta trilha de atendimento | Exportação em < 2 minutos por período | Teste funcional |

### Business Success

| Métrica | Meta | Prazo |
|---|---|---|
| Redução TMA financeiro | -30% vs. baseline pré-integração | 90 dias pós-deploy |
| Resolução no 1º contato — financeiro | 50% dos casos elegíveis | 90 dias |
| Contenção por agente IA — casos repetitivos | 30% (financeiro + suporte simples) | 90 dias |
| Abertura de protocolo com registro | 95%+ dos casos de suporte confirmados | Contínuo |
| Escalonamento com contexto suficiente | 90%+ avaliados como completos pelo receptor | Contínuo |
| Desbloqueio em confiança — aderência à política | 100% apenas quando HubSoft retorna elegibilidade | Contínuo — 0 exceção |

### Technical Success

| Requisito | Meta |
|---|---|
| Latência P95 — consulta simples HubSoft | < 3s por chamada |
| Latência P95 — fluxo completo | < 6s end-to-end |
| Disponibilidade do conector | 99,5% |
| Token HubSoft exposto ao frontend | 0 ocorrências |
| `actor_id` em 100% dos logs de ação | Verificado por teste automatizado |
| Duplicatas em retry (desbloqueio + protocolo) | 0 ocorrências |

### Measurable Outcomes — MVP

- Zero incidentes de ação no contrato errado nos primeiros 90 dias
- 1 ISP piloto com os três fluxos (financeiro, suporte, vendas) operacionais
- Trilha auditável aprovada pelo gestor do ISP piloto antes de rollout
- Checklist de validação no tenant real 100% executado antes do go-live

---

## Product Scope

### MVP — Phase 1

**Arquitetura:** módulo `hubsoft_connector` no `evo-ai-processor` (Python/FastAPI), namespace isolado `/hubsoft/`. Trilha principal REST para todos os fluxos documentados. Escape hatch N8N via MCP para endpoints sem documentação pública.

**Três fluxos simultâneos** — justificativa: compartilham a mesma infraestrutura transversal (identificação, `actor_id`, log, circuit breaker); implementar isolado não reduz esforço e deixa o piloto sem cobertura completa.

**Fluxo Financeiro:** identificação → consulta de faturas → envio PIX/boleto → desbloqueio em confiança (quando elegível) → registro no Evo CRM com `actor_id`.

**Fluxo Suporte:** identificação → verificação de bloqueio financeiro → consulta de status/última conexão → abertura de protocolo/OS → handoff com contexto para campo.

**Fluxo Vendas:** classificação de lead → consulta de planos por CEP → apresentação de opções → captura de dados → criação de prospecto no HubSoft + lead no Evo CRM → escalonamento para consultor.

**Infraestrutura transversal:** OAuth2 criptografado + renovação automática, log auditável com `actor_id`, mascaramento de dados sensíveis em logs, circuit breaker + degradação graciosa, idempotência para desbloqueio e abertura de protocolo, cache por tipo de dado (cliente 30–120s, financeiro 30–60s, planos 6–24h), sync de contato ao primeiro atendimento, sync periódico de catálogo de planos.

**Resource Requirements:** 1 dev backend Python, 1 dev fullstack Rails/React, acesso a tenant HubSoft real.

### Growth Features — Phase 2

- Reconsulta de fatura após alegação de pagamento
- Extrato de conexão Radius histórico no diagnóstico de suporte
- Alertas de massiva regional via campo `alerta` do HubSoft
- Validação de cliente existente antes de oferta de upgrade
- QR Code visual gerado a partir de `pix_copia_cola`
- GraphQL para contexto 360 do cliente após introspecção do schema do tenant
- Filtros avançados e exportação de log de auditoria

### Vision — Phase 3

- Multi-tenant: múltiplos ISPs por instalação
- Integração NMS/OLT para diagnóstico técnico real (potência óptica, ONU)
- Dashboard analítico avançado via GraphQL
- Aceite contratual digital e onboarding de instalação no fluxo de vendas
- Marketplace de conectores para outros ERPs de ISP (SGP, Ispfy, etc.)

### Fora de Escopo (v1)

- Bloqueio/desbloqueio definitivo de serviço fora do endpoint documentado
- Negociação de desconto, acordo, parcelamento ou baixa manual
- Teste óptico real de ONU/OLT ou comandos NMS sem API confirmada
- Viabilidade física por CTO/porta/capacidade
- Schema GraphQL antes de introspecção no tenant real
- Credenciais HubSoft no frontend

---

## User Journeys

### Máquina de Estados de Identificação (transversal a todos os fluxos)

```
UNKNOWN
  → lookup silencioso por telefone WhatsApp → HubSoft GET /cliente?busca=telefone
  → CANDIDATE_FOUND (1 cliente) → confirma por ENDEREÇO ("Sua rua é X, bairro Y?")
      → confirmado → IDENTITY_CONFIRMED
      → não confirmado → pede CPF/CNPJ → IDENTITY_CONFIRMED ou ESCALATE_HUMAN
  → AMBIGUOUS (múltiplos clientes) → pede CPF/CNPJ → CANDIDATE_FOUND → confirma endereço
  → NOT_FOUND → pede CPF/CNPJ → CANDIDATE_FOUND ou ESCALATE_HUMAN
  → IDENTITY_CONFIRMED → lista serviços ativos (sem dados financeiros)
      → 1 serviço → ancora em id_cliente_servico automaticamente → ACTION_AUTHORIZED
      → múltiplos serviços → apresenta lista ("Fibra 500MB – Rua X" / "Móvel – nº Y")
          → cliente escolhe → ACTION_AUTHORIZED
```

**Regra LGPD:** nunca exibir CPF mascarado antes de o cliente informar o próprio CPF. Endereço (rua/bairro) é o único dado exposto na confirmação silenciosa.

---

### Jornada 1 — Atendente Junior: cobrança inadimplente

**Persona:** Lucas, 22 anos, 5 dias de empresa, sozinho no turno. Chega mensagem: *"oi, minha internet tá cortada, mas eu paguei"*.

Lucas abre o Evo CRM. Agente IA identificou o número e localizou candidato. Confirma por endereço. Ancora em `id_cliente_servico` da fibra. Consulta financeiro: fatura de R$ 89,90 vencida há 3 dias, serviço `bloqueado_financeiro`. Agente verifica elegibilidade de desbloqueio — HubSoft retorna elegível por 2 dias. Lucas executa. Agente registra com `actor_id: lucas@isp`. Cliente recebe confirmação de reconexão temporária + PIX.

Lucas fechou o atendimento sem abrir o HubSoft, sem risco de contrato errado.

**FRs cobertos:** FR01, FR02, FR06, FR07, FR08, FR11, FR12, FR13, FR30.

---

### Jornada 2 — Cliente Multi-contrato: suporte com ambiguidade

**Persona:** Dona Maria, 58 anos, fibra residencial + chip móvel no mesmo CPF. *"o internet não funciona"*.

Lookup retorna 1 cliente, 2 serviços. Agente confirma identidade por endereço. Apresenta: *"Fibra 200MB (Rua das Flores) ou Móvel Pré (nº 37999991234)?"* Dona Maria responde "o de casa". Sistema ancora na fibra. Última conexão: `false` há 18h, sem bloqueio financeiro. Agente orienta verificações básicas. Cliente confirma roteador ligado. Agente abre protocolo com `abrir_os: true` — protocolo nº 40821 retornado. Contexto técnico encaminhado para campo.

**FRs cobertos:** FR01–FR03, FR06, FR14, FR15, FR17, FR18, FR19, FR20, FR30.

---

### Jornada 3 — Lead Novo: consulta de planos e pré-venda

**Persona:** Rafael, 34 anos, mudou de bairro. *"vocês atendem na Vila Nova? quanto custa fibra?"*

Lookup: `NOT_FOUND`. Agente não pede CPF. Pergunta CEP. Rafael informa. Agente consulta HubSoft: 3 planos de fibra disponíveis. Rafael escolhe 300MB. Agente coleta nome, CPF, telefone. Cria prospecto no HubSoft + lead no Evo CRM vinculados. Consultor recebe lead com plano escolhido, CEP e histórico da conversa.

**FRs cobertos:** FR21–FR26, FR30.

---

### Jornada 4 — Gestor: auditoria mensal

**Persona:** Carla, gerente de atendimento. Final do mês — verifica desbloqueios executados.

Carla filtra log por `desbloqueio_confianca` nos últimos 30 dias. Vê `actor_id`, timestamp, `id_cliente_servico`, resultado HubSoft. Encontra 1 tentativa recusada por limite excedido — sistema registrou o erro, não executou, escalou para humano. Exporta log em < 2 minutos. Apresenta à diretoria como evidência de compliance.

**FRs cobertos:** FR30–FR34.

---

### Jornada 5 — Integrador Técnico: setup e escape hatch N8N

**Persona:** Thiago, dev do ISP, configura a integração.

Thiago informa `host`, `client_id`, `client_secret`, usuário técnico. Sistema testa OAuth, armazena token criptografado, confirma conexão. Identifica que ISP usa relatório batch sem endpoint REST documentado. Registra workflow N8N existente como MCP tool no Evo CRM. Agente IA invoca o workflow via MCP para esse caso específico, sem modificar o conector principal.

**FRs cobertos:** FR35–FR39, FR45.

---

### Journey Requirements Summary

| Capacidade | Jornadas |
|---|---|
| Lookup silencioso por telefone WhatsApp | 1, 2, 3 |
| Confirmação de identidade por endereço (sem expor CPF) | 1, 2 |
| Seleção explícita de serviço em multi-contrato | 2 |
| Consulta financeira por `id_cliente_servico` | 1 |
| Desbloqueio em confiança com verificação de elegibilidade | 1 |
| Abertura de protocolo/OS com diagnóstico | 2 |
| Handoff com contexto para campo/consultor | 2, 3 |
| Consulta de planos por CEP (sem cliente cadastrado) | 3 |
| Criação de prospecto HubSoft + lead Evo CRM | 3 |
| Log auditável com `actor_id` + timestamp + resultado | 1, 2, 3, 4 |
| Exportação de log por tipo de ação e período | 4 |
| Configuração de credenciais HubSoft por tenant | 5 |
| Registro de workflows N8N como ferramentas MCP | 5 |

---

## Domain-Specific Requirements

### Compliance & Regulatório

**LGPD (Lei 13.709/2018):**
- CPF/CNPJ nunca exposto em mensagem de confirmação; endereço (rua/bairro) é o único dado exibido antes de `IDENTITY_CONFIRMED`
- Dados financeiros (fatura, linha digitável, PIX) transmitidos somente após `IDENTITY_CONFIRMED`
- Logs com dados pessoais: retenção mínima 12 meses, acesso restrito por papel (`account_owner`)
- Mascaramento obrigatório de CPF/CNPJ, linha digitável e `pix_copia_cola` em logs e traces
- Base legal: execução de contrato (Art. 7º, V LGPD)

**Anatel (Resolução 632/2014):**
- Sistema não executa bloqueio definitivo — apenas desbloqueio temporário em confiança via endpoint documentado HubSoft
- Abertura de protocolo obrigatória em 100% dos casos de falha de serviço confirmados
- Timestamp de abertura de protocolo registrado para SLA regulatório

**Restrições operacionais de ISP:**
- Política de desbloqueio em confiança configurada no painel HubSoft (dias, limite por cliente/mês); conector respeita resposta HubSoft sem sobrescrever
- PIX/boleto: baixa não é instantânea; agente informa prazo de processamento e não promete reconexão antes de nova confirmação
- Planos por CEP são pré-filtro comercial — viabilidade física (porta/CTO/capacidade) é etapa humana

### Estratégia de Sincronização de Dados

O Evo CRM é auto-hospedado na infra do próprio ISP — ISP é controlador dos dados HubSoft, sem transferência para terceiros.

**Nível 1 — ao entrar contato (automático):**
- `GET /cliente?busca=telefone` → identifica cliente, retorna dados cadastrais + serviços
- Cria ou atualiza contato no Evo CRM; contato nunca fica vazio após primeiro atendimento

**Nível 2 — sob demanda, por setor:**
- Financeiro: `GET /cliente/financeiro?busca=id_cliente_servico` — só quando triagem detecta cobrança
- Suporte: `GET /cliente?ultima_conexao=sim` + `GET /extrato_conexao` — só quando relata falha técnica
- Vendas: `GET /prospecto/create?cep=` — só quando solicita planos

**Batch periódico:** catálogo de planos por CEP/unidade de negócio — sync a cada 6–24h, disponível localmente sem chamada HubSoft em tempo real.

**Nunca sincronizar em batch:** faturas, status financeiro, status de serviço, extrato Radius — sempre on-demand.

### Integrações

| Sistema | Direção | Protocolo | Status |
|---|---|---|---|
| HubSoft REST API | Evo → HubSoft | HTTPS REST JSON + OAuth2 | ✅ MVP |
| evolution-go (WhatsApp) | WhatsApp → Evo | Webhook interno | ✅ existente |
| N8N via MCP | Evo ↔ N8N | MCP Server | ✅ MVP (opcional por ISP) |
| HubSoft GraphQL | Evo → HubSoft | HTTPS GraphQL + OAuth2 | 🔜 Pós-MVP |
| NMS/OLT do ISP | Evo → NMS | A definir | 🔜 Pós-MVP |

**Contrato interno de dados:**
- Toda ação financeira ou técnica exige `id_cliente_servico` confirmado — `id_cliente` sozinho é insuficiente
- Prospecto de vendas usa fluxo separado sem `id_cliente_servico` (lead ainda não é cliente)

### Mitigações de Risco

| Risco | Impacto | Mitigação |
|---|---|---|
| Ação no `id_cliente_servico` errado | Crítico | Confirmação por endereço + seleção explícita de serviço antes de qualquer ação |
| CPF exposto antes de autenticação | LGPD | Hard-coded: nunca exibir CPF em mensagem de confirmação |
| Baixa de PIX não refletida no HubSoft | Reconexão prematura | Agente informa prazo; nova consulta obrigatória antes de confirmar quitação |
| HubSoft offline | Atendimento travado | Circuit breaker + degradação graciosa + escalonamento com contexto parcial |
| Rate limit HubSoft não documentado | Bloqueio operacional | Cache curto, backoff, `cliente/all` nunca em tempo real |
| Token HubSoft comprometido | Acesso total ao ERP | Usuário técnico dedicado, permissões mínimas, detecção de 401 inesperado como alerta |
| Desbloqueio além do limite configurado | Violação de política | Sem retry em recusa de desbloqueio; resposta HubSoft é definitiva |
| Schema GraphQL divergente entre tenants | Queries quebradas | GraphQL bloqueado no MVP; habilitado após introspecção e snapshot do schema real |

---

## Innovation & Novel Patterns

**1. Agente IA com toolset delimitado por setor**
Cada setor expõe conjunto específico de ferramentas ao agente — guardrails impedem ações cruzadas (agente financeiro não abre OS; agente de suporte não emite boleto). Reduz superfície de erro e simplifica auditoria.

**2. Máquina de estados de identificação LGPD-safe**
Confirmação por endereço antes de expor dado sensível — sem CPF mascarado antes de o cliente provar identidade. Resolve simultaneamente minimização de dados LGPD e risco operacional de contrato errado.

**3. Escape hatch N8N/MCP como extensão plugável**
Trilha principal REST no processor + N8N via MCP para endpoints sem documentação. ISP customiza automações sem modificar código do produto base — extensibilidade sem fork.

**4. `actor_id` unificado para humano e agente IA**
Mesmo campo de auditoria registra ações humanas e automatizadas. Gestor distingue "quem fez o quê" sem sistemas separados — base para compliance e calibração de guardrails ao longo do tempo.

**Contexto de mercado:** integrações ERP-CRM para ISPs brasileiros existem como projetos customizados por integradoras, sem produto com IA embarcada, guardrails por setor e auditabilidade como features de produto open-source auto-hospedado.

**Validação no MVP:**

| Inovação | Como validar |
|---|---|
| Toolset por setor | Agente financeiro tenta abrir OS — deve retornar erro de permissão |
| Identificação LGPD-safe | Auditoria confirma 0 atendimentos com CPF exposto antes de `IDENTITY_CONFIRMED` |
| Escape hatch N8N/MCP | ISP piloto invoca 1 workflow N8N em caso real via agente |
| `actor_id` unificado | Gestor valida relatório de auditoria do 1º mês de operação |

---

## Functional Requirements

### 1. Identificação de Cliente

- **FR01:** O sistema identifica cliente HubSoft pelo telefone WhatsApp de entrada, silenciosamente, sem solicitar dado ao cliente
- **FR02:** O sistema confirma identidade pelo endereço cadastral (rua/bairro) sem expor CPF, CNPJ ou dados financeiros antes da confirmação
- **FR03:** O sistema solicita CPF ou CNPJ quando confirmação por endereço falha ou nenhum candidato é encontrado por telefone
- **FR04:** O sistema resolve ambiguidade (múltiplos clientes no mesmo telefone) solicitando CPF/CNPJ para desambiguação
- **FR05:** O sistema escala para atendimento humano com contexto parcial quando nenhum método de identificação é bem-sucedido
- **FR06:** O sistema lista serviços ativos do cliente identificado sem exibir dados financeiros, permitindo seleção do serviço para atendimento
- **FR07:** O sistema cria ou atualiza contato no Evo CRM com dados cadastrais e serviços do cliente no primeiro atendimento HubSoft

### 2. Atendimento Financeiro

- **FR08:** Atendente ou agente IA consulta faturas pendentes e status financeiro de um `id_cliente_servico`
- **FR09:** Atendente ou agente IA envia PIX copia-e-cola da fatura em aberto mais recente ao cliente
- **FR10:** Atendente ou agente IA envia link e linha digitável do boleto da fatura em aberto mais recente
- **FR11:** O sistema verifica elegibilidade de desbloqueio em confiança junto ao HubSoft antes de oferecer ou executar a opção
- **FR12:** Atendente ou agente IA executa desbloqueio em confiança exclusivamente quando HubSoft retorna elegibilidade para o `id_cliente_servico`
- **FR13:** O sistema registra no Evo CRM consultas financeiras, envios de cobrança e resultados de desbloqueio com `actor_id`, timestamp e `id_cliente_servico`

### 3. Atendimento de Suporte Técnico

- **FR14:** Atendente ou agente IA consulta status do serviço e dados da última conexão de um `id_cliente_servico`
- **FR15:** O sistema verifica bloqueio financeiro antes de diagnóstico técnico e redireciona para fluxo financeiro quando bloqueio é identificado
- **FR16:** Atendente ou agente IA consulta extrato de conexão Radius de um serviço para diagnóstico de falha
- **FR17:** Atendente ou agente IA abre protocolo de suporte no HubSoft com diagnóstico estruturado associado ao `id_cliente_servico`
- **FR18:** O sistema abre OS de campo vinculada ao protocolo quando o problema exige visita técnica
- **FR19:** O sistema registra no Evo CRM o protocolo, diagnóstico e próxima ação com `actor_id` e timestamp
- **FR20:** O sistema encaminha contexto técnico completo para equipe de campo ou atendente humano ao escalonar

### 4. Atendimento de Vendas e Pré-venda

- **FR21:** O agente IA classifica contato como novo cliente, cliente atual, ex-cliente ou candidato a upgrade antes de iniciar fluxo de vendas
- **FR22:** O sistema consulta planos disponíveis para CEP informado pelo cliente
- **FR23:** O sistema apresenta planos fibra e móvel disponíveis com velocidade, preço e condições essenciais
- **FR24:** Atendente ou agente IA captura dados de interesse (CEP, plano, nome, CPF/CNPJ, telefone) para criação de prospecto
- **FR25:** O sistema cria prospecto no HubSoft e lead correspondente no Evo CRM vinculados entre si
- **FR26:** O sistema escala para consultor humano com contexto completo quando venda exige negociação ou validação

### 5. Sincronização e Cache de Dados

- **FR27:** O sistema sincroniza catálogo de planos HubSoft periodicamente, disponibilizando localmente sem chamada em tempo real
- **FR28:** O sistema aplica cache de curta duração a consultas de cliente e financeiro respeitando TTLs por tipo de dado
- **FR29:** O sistema atualiza dados do contato no Evo CRM quando lookup HubSoft retorna informações mais recentes

### 6. Auditoria e Rastreabilidade

- **FR30:** O sistema registra toda ação HubSoft com `actor_id` (humano ou agente IA), timestamp, `id_cliente_servico`, tipo de ação e resultado
- **FR31:** O `account_owner` visualiza log de auditoria completo filtrável por tipo de ação, período e `actor_id`
- **FR32:** O `account_owner` exporta log de auditoria de um período selecionado
- **FR33:** O sistema registra tentativas de ação recusadas pelo HubSoft no log com motivo do recuse
- **FR34:** O `agent` visualiza log de auditoria restrito aos próprios atendimentos

### 7. Configuração e Administração

- **FR35:** O `account_owner` configura credenciais HubSoft (`host`, `client_id`, `client_secret`, usuário técnico, senha) via painel administrativo
- **FR36:** O sistema testa autenticação OAuth HubSoft e confirma conectividade ao salvar credenciais
- **FR37:** O `account_owner` configura URL do MCP Server N8N como escape hatch opcional
- **FR38:** O `account_owner` ativa ou desativa o escape hatch N8N/MCP sem redeploy
- **FR39:** O sistema renova token OAuth HubSoft automaticamente ao detectar expiração ou HTTP 401

### 8. Resiliência e Tratamento de Erros

- **FR40:** O sistema detecta indisponibilidade do HubSoft e informa o usuário sem expor stack trace ou detalhes técnicos internos
- **FR41:** O sistema escala atendimento para humano com contexto parcial quando HubSoft está indisponível durante fluxo ativo
- **FR42:** O sistema garante idempotência em desbloqueio em confiança e abertura de protocolo, evitando duplicatas em retentativas
- **FR43:** O agente IA informa prazo de processamento de pagamento sem prometer reconexão antes de nova confirmação de quitação no HubSoft

### 9. Integração com Agente IA

- **FR44:** O agente IA acessa ferramentas HubSoft restritas ao setor identificado pela triagem, sem acesso cruzado entre toolsets de setores distintos
- **FR45:** O agente IA invoca workflows N8N via MCP para casos sem endpoint REST documentado, quando escape hatch estiver configurado
- **FR46:** O sistema registra `actor_id` do agente IA em todas as ações automatizadas, distinguindo-as de ações humanas no log

---

## Non-Functional Requirements

### Performance

| Requisito | Critério |
|---|---|
| Consulta simples HubSoft (cliente, financeiro) | P95 < 3s por chamada |
| Fluxo completo (identificação + financeiro + ação) | P95 < 6s end-to-end |
| Consulta de planos por CEP (cache warm) | P95 < 500ms |
| Resposta do agente IA ao cliente | P95 < 8s incluindo chamada HubSoft |
| Sync de contato ao primeiro atendimento (background) | < 30s após evento |
| Sync de catálogo de planos (batch) | < 5 minutos para catálogo completo |

### Segurança

| Requisito | Critério |
|---|---|
| Token OAuth HubSoft em repouso | AES-256 via `app_configs` — mesmo mecanismo BMS/LeadSquared |
| Token HubSoft no frontend | 0 ocorrências — bloqueado por arquitetura |
| CPF/CNPJ em logs | Mascarado (`***.***.***-XX`) em 100% das entradas |
| Linha digitável e PIX em logs | Mascarados ou omitidos em 100% das entradas |
| Acesso a log de auditoria | `account_owner`: completo; `agent`: apenas próprios atendimentos |
| Credenciais HubSoft no código | 0 ocorrências hardcoded |
| Transmissão de dados | HTTPS com certificado validado em todas as chamadas |

### Confiabilidade

| Requisito | Critério |
|---|---|
| Disponibilidade do conector | 99,5% (excluindo manutenção programada) |
| HubSoft offline | Degradação graciosa em 100% dos casos — sem HTTP 500 exposto |
| Circuit breaker | Ativa após 3 falhas consecutivas; reset após 60s |
| Idempotência — desbloqueio em confiança | 0 duplicatas em retry dentro de janela de 5 min por `id_cliente_servico` |
| Idempotência — abertura de protocolo | 0 duplicatas em retry dentro de janela de 5 min por `id_cliente_servico` + descrição |
| Renovação de token OAuth | Automática — sem intervenção humana |

### Integração e Cache

| Requisito | Critério |
|---|---|
| Compatibilidade REST HubSoft | Validada contra checklist completo da technical research antes do deploy |
| Cache — dados de cliente | TTL 30–120s; invalidado após ação que muda status |
| Cache — dados financeiros | TTL 30–60s |
| Cache — catálogo de planos | TTL 6–24h configurável por instalação |
| N8N/MCP no caminho crítico | Proibido — apenas para operações batch/assíncronas |

### Privacidade e Conformidade (LGPD)

| Requisito | Critério |
|---|---|
| Dado sensível antes de `IDENTITY_CONFIRMED` | 0 ocorrências de CPF, CNPJ, fatura ou status financeiro expostos |
| Vazamento de cache entre clientes distintos | 0 ocorrências |
| Retenção de logs de auditoria | Mínimo 12 meses; configurável pelo `account_owner` |
| Base legal registrada | Execução de contrato (Art. 7º, V LGPD) na configuração da integração |

### Manutenibilidade

| Requisito | Critério |
|---|---|
| Toolset por setor | Configurável via painel admin sem redeploy |
| Adição de endpoint HubSoft | Sem modificação fora do namespace `/hubsoft/` |
| Cobertura de testes | ≥ 80% nos módulos `hubsoft/tools/` e `hubsoft/connector.py` |
| Validação no tenant real | 100% do checklist executado e documentado antes do go-live |

---

## Architecture & Implementation Reference

### Modelo de Permissões (RBAC)

| Ação HubSoft | `account_owner` | `agent` |
|---|---|---|
| Configurar credenciais HubSoft | ✅ | ❌ |
| Configurar N8N/MCP | ✅ | ❌ |
| Visualizar log completo | ✅ | ❌ |
| Exportar log | ✅ | ❌ |
| Executar desbloqueio em confiança | ✅ | ✅ (se HubSoft retorna elegibilidade) |
| Consultar dados financeiros | ✅ | ✅ |
| Abrir protocolo/OS | ✅ | ✅ |
| Criar prospecto | ✅ | ✅ |

Guardrails de setor do agente IA aplicados independentemente do papel do atendente que iniciou a sessão.

### Padrão de Implementação (confirmado no codebase)

**Padrão 1 — Sync de dados → seguir BMS:**
- Referência: `evo-ai-crm-community/app/services/crm/bms/` + `app/jobs/crm/bms/`
- Estrutura HubSoft: `app/services/crm/hubsoft/processor_service.rb`, `api/client.rb`, `mappers/contact_mapper.rb`
- `app/jobs/crm/hubsoft/contact_sync_job.rb` — disparado por evento de contato
- `app/jobs/crm/hubsoft/plans_sync_job.rb` — sync periódico de catálogo

**Padrão 2 — Ferramentas do agente IA → seguir Custom Tools:**
- Referência: `evo-ai-processor-community/src/services/adk/custom_tools.py` + `tool_builder.py`
- Ferramentas HubSoft como `FunctionTool` (Google ADK) registradas via `ToolBuilder.build_tools()`
- Toolset por setor via `custom_tool_ids` por agente — carregamento condicional já suportado
- N8N/MCP tools no mesmo pipeline `build_tools()` — escape hatch sem modificação de código

**Estrutura de arquivos proposta:**
```
evo-ai-crm-community/
  app/services/crm/hubsoft/
    processor_service.rb       # sync de contatos
    api/client.rb              # HTTP client Rails (OAuth + token)
    mappers/contact_mapper.rb  # HubSoft → Evo CRM contact
  app/jobs/crm/hubsoft/
    contact_sync_job.rb        # sync ao primeiro atendimento
    plans_sync_job.rb          # sync periódico de planos

evo-ai-processor-community/
  src/services/hubsoft/
    tools/
      financial_tools.py       # FR08–FR13
      support_tools.py         # FR14–FR20
      sales_tools.py           # FR21–FR26
    auth/
      oauth_client.py          # token OAuth, renovação, criptografia
    connector.py               # circuit breaker, cache, idempotência
```

Token OAuth armazenado via `app_configs` — mesmo mecanismo criptografado usado pelo BMS e LeadSquared.
