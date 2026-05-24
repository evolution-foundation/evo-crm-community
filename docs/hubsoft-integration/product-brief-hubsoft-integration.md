---
title: "Product Brief: Integracao HubSoft -> Evo CRM Community"
date: 2026-05-24
author: "Mary (Business Analyst)"
project: "Evo CRM Community"
feature: "hubsoft-integration"
inputs:
  - "docs/hubsoft-integration/domain-research-isp-brasil-hubsoft.md"
  - "docs/hubsoft-integration/technical-research-api-hubsoft.md"
next_step: "PRD"
---

# Product Brief: Integracao HubSoft -> Evo CRM Community

## 1. Proposta de valor

A integracao HubSoft -> Evo CRM Community permite que atendentes e agentes de IA resolvam demandas financeiras, tecnicas e comerciais de clientes de ISPs diretamente no fluxo de atendimento por WhatsApp/chat, sem alternar manualmente para o ERP.

O primeiro valor do produto e reduzir tempo medio de atendimento e aumentar resolucao no primeiro contato ao trazer contexto de cliente, servico, faturas, protocolos e planos para dentro do CRM, com guardrails para LGPD, regulacao e operacao de rede.

## 2. Contexto e oportunidade

ISPs brasileiros operam com alto volume de atendimento local, forte dependencia de WhatsApp/chat e processos recorrentes de cobranca, suporte e venda. O HubSoft concentra dados criticos de cliente, `cliente_servico`, faturas, boleto/PIX, desbloqueio em confianca, protocolos, OS, prospectos e planos.

Hoje, o atendente precisa consultar o HubSoft separadamente para cada acao. Isso cria friccao, aumenta o TMA, dificulta automacao por setor e amplia risco de erro em clientes com multiplos contratos, status financeiro sensivel ou problemas tecnicos que dependem de contexto operacional.

## 3. Personas principais

### Atendente humano do ISP

Precisa consultar e agir rapidamente sem sair do Evo CRM. Seu objetivo e reduzir troca de telas, evitar erros de identificacao, registrar protocolo e escalar apenas os casos que exigem decisao humana.

### Agente de IA do atendimento

Precisa acessar ferramentas seguras e bem delimitadas para identificar cliente, selecionar o servico correto, consultar dados autorizados, executar acoes permitidas e encaminhar para humano quando houver risco, ambiguidade ou gap tecnico.

### Cliente final do ISP

Quer resolver problemas simples pelo WhatsApp/chat: receber PIX/boleto, entender bloqueio, solicitar desbloqueio temporario quando elegivel, reportar falta de internet, abrir protocolo ou consultar planos disponiveis.

## 4. Casos de uso priorizados por setor

### Financeiro

| Prioridade | Caso de uso | Resultado esperado |
|---|---|---|
| Must | Identificar cliente por CPF/CNPJ, telefone ou codigo e selecionar `cliente_servico` correto | Evitar vazamento e acao no contrato errado |
| Must | Consultar faturas pendentes, status financeiro e status do servico | Informar situacao de forma objetiva e segura |
| Must | Enviar PIX copia e cola ou link/linha digitavel do boleto da fatura mais recente em aberto | Reduzir atendimento humano para 2a via |
| Must | Registrar consulta, envio de cobranca e resultado no CRM | Criar trilha de auditoria e contexto do atendimento |
| Should | Consultar elegibilidade e executar desbloqueio em confianca quando autorizado pelo HubSoft | Resolver bloqueio temporario sem acao manual |
| Should | Reconsultar fatura apos alegacao de pagamento | Evitar prometer reconexao antes da baixa |
| Could | Gerar QR Code visual a partir do PIX copia e cola | Melhorar experiencia no canal |
| Won't | Negociar acordo, desconto, parcelamento ou baixa manual nesta versao | Exige politica comercial e controle humano |

### Suporte

| Prioridade | Caso de uso | Resultado esperado |
|---|---|---|
| Must | Identificar cliente e contrato/servico ativo | Ancorar diagnostico no `id_cliente_servico` |
| Must | Verificar se ha bloqueio financeiro antes de troubleshooting tecnico | Direcionar corretamente o atendimento |
| Must | Consultar status do servico, ultima conexao e dados tecnicos disponiveis no HubSoft | Distinguir falha provavel de acesso, bloqueio ou cadastro |
| Must | Abrir atendimento/protocolo de suporte quando houver problema confirmado ou inconclusivo | Garantir rastreabilidade e handoff |
| Should | Consultar extrato Radius e historico recente de OS quando disponivel | Enriquecer triagem tecnica |
| Should | Registrar no CRM o protocolo, resumo do diagnostico e proxima acao | Manter continuidade para humano |
| Could | Encaminhar massivas ou alertas regionais quando o HubSoft retornar mensagens de alerta | Reduzir repeticao de atendimentos |
| Won't | Executar teste real de ONU/OLT ou potencia optica sem integracao NMS/OLT confirmada | API publica nao comprova esse endpoint |

### Vendas

| Prioridade | Caso de uso | Resultado esperado |
|---|---|---|
| Must | Classificar lead como novo cliente, cliente atual, ex-cliente ou upgrade | Evitar proposta inadequada |
| Must | Buscar planos disponiveis por CEP via HubSoft | Pre-filtrar ofertas comerciais |
| Must | Apresentar planos de fibra e movel com preco e condicoes essenciais | Dar resposta comercial rapida |
| Must | Capturar interesse e criar prospecto/lead no HubSoft/Evo CRM | Gerar continuidade comercial |
| Should | Encaminhar para consultor humano quando houver negociacao, cobertura duvidosa ou plano empresarial | Proteger conversao e margem |
| Should | Validar cliente existente antes de oferta de upgrade | Evitar venda para inadimplente ou contrato inadequado |
| Could | Registrar preferencia de plano, melhor horario e endereco estruturado | Melhorar handoff comercial |
| Won't | Confirmar viabilidade fisica definitiva por CTO/porta nesta versao | Planos por CEP nao provam capacidade real |

## 5. Escopo da primeira versao

A primeira versao deve entregar uma integracao operacional assistida, single-tenant, com backend dedicado para HubSoft e exposicao controlada ao Evo CRM/agentes de IA.

Inclui:

- autenticacao HubSoft via OAuth2 Password Grant e uso de Bearer Token;
- conector backend isolado, sem chamada direta do frontend ao HubSoft;
- identificacao de cliente por CPF/CNPJ, telefone, codigo e, quando disponivel, `id_cliente_servico`;
- normalizacao de contexto em torno de cliente, servico/contrato, financeiro, protocolo e lead;
- fluxo financeiro MVP com consulta de faturas, envio de boleto/PIX e desbloqueio em confianca quando elegivel;
- fluxo de suporte com triagem, checagem financeira, ultima conexao, extrato disponivel e abertura de protocolo/OS;
- fluxo de vendas com planos por CEP e criacao de prospecto;
- mascaramento de dados sensiveis, logs auditaveis e limites internos de uso;
- registro das interacoes relevantes no Evo CRM.

## 6. Fora de escopo nesta versao

- multi-tenant ou marketplace de integracoes para multiplos ISPs na mesma instalacao;
- baixa manual de pagamento, conciliacao bancaria ou promessa de reconexao antes de confirmacao no HubSoft;
- negociacao automatica de desconto, acordo, parcelamento, cancelamento ou negativacao;
- bloqueio/desbloqueio definitivo de servico fora do endpoint documentado de desbloqueio em confianca;
- teste optico real de ONU/OLT, leitura de potencia RX/TX, reboot/provisionamento ou comandos NMS sem API confirmada do provedor;
- viabilidade fisica definitiva de fibra por CTO/porta/capacidade;
- aceite contratual completo, assinatura digital ou onboarding completo de instalacao;
- dashboards analiticos avancados via GraphQL antes de introspeccao do schema real do tenant;
- integracao direta do frontend com credenciais HubSoft.

## 7. Metricas de sucesso

| Metrica | Definicao | Meta inicial sugerida |
|---|---|---|
| TMA financeiro | Tempo medio para identificar cliente e enviar PIX/boleto | Reducao de 30% apos implantacao |
| Resolucao no primeiro contato | Percentual de atendimentos resolvidos sem troca para HubSoft ou humano | 50% nos casos financeiros elegiveis |
| Contencao assistida por IA | Atendimentos finalizados por agente com guardrails sem intervencao humana | 30% dos casos repetitivos no MVP |
| Taxa de erro de identificacao | Casos com cliente/servico selecionado incorretamente | 0 incidente critico |
| Uso de desbloqueio elegivel | Desbloqueios executados somente quando HubSoft retornar permissao | 100% aderente |
| Abertura de protocolo | Atendimentos financeiros sensiveis e suporte com registro no CRM/HubSoft | 95%+ |
| Escalonamento correto | Casos fora de regra enviados para humano com contexto suficiente | 90%+ avaliados como completos |
| Tempo de resposta da integracao | Latencia das consultas HubSoft no atendimento | P95 abaixo de 3s para consultas simples |

## 8. Riscos e dependencias

### Riscos principais

- **LGPD e sigilo:** CPF/CNPJ, endereco, fatura, status financeiro e dados tecnicos exigem minimizacao, mascaramento e controle de permissao por setor.
- **Cliente com multiplos servicos:** a acao errada em `id_cliente_servico` pode enviar fatura incorreta, desbloquear contrato errado ou abrir OS inutil.
- **Baixa de pagamento nao instantanea:** PIX/boleto pode levar minutos ou depender de conciliacao; o agente nao deve prometer quitacao antes de confirmacao.
- **Desbloqueio em confianca:** precisa respeitar elegibilidade, limite e politica configurada no HubSoft.
- **Suporte tecnico incompleto:** API publica nao comprova teste real de ONU/OLT; diagnostico avancado pode depender de NMS/OLT/Radius do ISP.
- **Venda sem viabilidade real:** planos por CEP sao pre-filtro comercial, nao garantia de porta, CTO ou capacidade.
- **Rate limit nao documentado:** chamadas pesadas, especialmente `cliente/all` e GraphQL, podem degradar o tenant.
- **Permissoes OAuth amplas:** ausencia de escopos publicos exige usuario tecnico dedicado e testes de permissao.

### Dependencias

- tenant HubSoft real com host, `client_id`, `client_secret`, usuario tecnico e permissoes;
- validacao dos endpoints REST no ambiente do ISP;
- confirmacao da regra de desbloqueio em confianca configurada no painel HubSoft;
- definicao dos tipos de atendimento e OS usados pelo ISP;
- mapeamento dos setores, filas e permissoes no Evo CRM;
- politica operacional para envio de fatura a contato nao cadastrado;
- introspeccao GraphQL se for usado para telas agregadas futuras;
- decisao tecnica sobre microservico dedicado ou modulo no processor.

## 9. Decisoes recomendadas para PRD

1. Priorizar o MVP financeiro assistido como primeira entrega, porque tem maior volume repetitivo e melhor cobertura documentada na API REST.
2. Tratar suporte e vendas como fluxos assistidos na mesma fase ou fase seguinte, com limites claros para diagnostico tecnico e viabilidade comercial.
3. Modelar todas as acoes em torno de `id_cliente_servico`, nunca apenas `id_cliente`.
4. Usar REST como trilha principal da primeira versao; reservar GraphQL para leituras agregadas apos introspeccao do schema do tenant.
5. Implementar conector HubSoft no backend, com cache curto, backoff, idempotencia e auditoria.
6. Exigir confirmacao de identidade antes de exibir detalhes financeiros ou enviar documentos para contatos divergentes.
7. Definir handoff humano obrigatorio para contestacao de debito, acordo, cancelamento, plano empresarial, diagnostico tecnico inconclusivo e qualquer operacao sem endpoint validado.

## 10. Proximos passos para PRD

O PRD deve detalhar:

- arquitetura alvo do conector HubSoft no Evo CRM;
- entidades normalizadas e contrato de dados interno;
- fluxos funcionais por setor, com estados, mensagens, permissoes e handoffs;
- matriz de endpoints HubSoft por caso de uso;
- requisitos de seguranca, LGPD, auditoria e retencao;
- regras de idempotencia, cache, retry, backoff e tratamento de erro;
- criterios de aceite para financeiro, suporte e vendas;
- plano de validacao no tenant real com massa de teste;
- recorte de MVP, fase 2 e dependencias externas.
