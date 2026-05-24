# Domain Research: ISPs no Brasil e Integracao HubSoft via Evo CRM

**Data:** 2026-05-24  
**Autor:** Mary (Business Analyst)  
**Projeto:** Evo CRM Community  
**Tipo:** Domain Research  

## Resumo executivo

O mercado brasileiro de provedores de internet e dominado por uma longa cauda de prestadoras regionais, especialmente no segmento de banda larga fixa. Segundo divulgacao da Anatel sobre o 2o trimestre de 2025, pequenas operadoras respondiam por 56,4% dos servicos de banda larga fixa ofertados, com cerca de 22,5 mil prestadoras atuando quando somadas as autorizadas e as dispensadas de outorga. Isso cria um dominio operacional muito diferente das grandes teles: alto volume de atendimento local, dependencia de rede GPON/FTTH, cobranca recorrente sensivel a inadimplencia, suporte de campo e necessidade de automacao em WhatsApp/chat.

Para a integracao Evo CRM + HubSoft, o centro do dominio nao e apenas "consultar cliente". O fluxo real cruza quatro dimensoes: identidade do assinante, servico/contrato ativo, estado financeiro e estado tecnico da conexao. O HubSoft modela boa parte disso em torno de `cliente`, `cliente_servico`, `servico/plano`, contratos, cobrancas/faturas, protocolos/atendimentos e recursos de autoatendimento como 2a via, PIX e desbloqueio em confianca.

As tres frentes propostas para o Evo CRM devem ser tratadas com niveis diferentes de risco:

- **Financeiro:** alto impacto regulatorio e de LGPD. Deve consultar debitos, status de bloqueio, faturas, PIX/boleto e elegibilidade para desbloqueio em confianca, sem prometer baixa instantanea antes da confirmacao do HubSoft/banco.
- **Suporte:** alto risco operacional. Deve coletar identificacao, contrato/servico, sintomas e diagnosticos disponiveis, mas acionar tecnico humano quando houver indisponibilidade massiva, queda de PON, equipamento offline persistente ou falta de endpoint confiavel.
- **Vendas:** risco comercial e cadastral. Deve distinguir novo cliente, cliente existente e upgrade, validar cobertura/endereco, plano disponivel, fidelidade, viabilidade tecnica e regras fiscais/comerciais do provedor.

## Fontes principais

- HubSoft REST API: repositorio oficial `hubsoftbrasil/api`, que aponta para a documentacao oficial e wiki HubSoft. Fonte: https://github.com/hubsoftbrasil/api
- HubSoft GraphQL: API em `/graphql/v1`, autenticada pelo mesmo OAuth da API publica; exemplo publico de query `clientes` retorna `id_cliente`, `codigo_cliente`, `nome_razaosocial` e `cpf_cnpj`. Fonte: https://wiki.hubsoft.com.br/pt-br/api-graphql
- HubSoft App do Cliente: autoatendimento com 2a via de boleto, PIX QR Code, PIX copia e cola, desbloqueio em confianca, senha Wi-Fi e tecnico a caminho. Fonte: https://hubsoft.io/aplicativos/aplicativo-do-cliente/
- HubSoft Servico/Plano: planos possuem status inicial, tecnologia, grupo, composicao, contratos, descontos, taxa de instalacao, parametros de navegacao/download/upload, pacotes e rede neutra. Fonte: https://wiki.hubsoft.com.br/pt-br/modulos/configuracao/geral/servico
- Anatel PPP: definicao de Prestadora de Pequeno Porte como grupo com participacao nacional inferior a 5% em cada mercado de varejo, conforme PGMC citado pela Anatel. Fonte: https://www.gov.br/anatel/pt-br/regulado/prestadoras-de-pequeno-porte
- Anatel mercado 2025: pequenas operadoras com 56,4% da banda larga fixa e cerca de 22,5 mil prestadoras atuando no 2o trimestre de 2025. Fonte: https://agenciagov.ebc.com.br/noticias/202507/56-por-cento-da-banda-larga-no-brasil-ofertada-por-pequenas-operadoras
- Anatel RGC 2023/Res. 765: regras de suspensao, notificacao, rescisao e restabelecimento por inadimplencia. Fonte: https://informacoes.anatel.gov.br/legislacao/resolucoes/1900-resolucao-765
- Marco Civil da Internet: direito do usuario a nao suspensao da conexao, salvo debito diretamente decorrente de sua utilizacao. Fonte: https://jurishand.com/lei-12965-de-23-abril-2014/artigo-7

## 1. Modelo de negocio de um ISP brasileiro tipico

Um ISP regional brasileiro normalmente vende conectividade recorrente para residencias e pequenos negocios. A principal receita e mensalidade de banda larga fixa, geralmente FTTH/GPON, complementada por taxa de instalacao, roteador/ONU em comodato ou locacao, planos empresariais, telefonia, TV/OTT, cameras, mesh Wi-Fi, planos moveis via MVNO/parceria e servicos adicionais.

A operacao combina:

- **Aquisicao e ativacao:** marketing local, consulta de cobertura, viabilidade no endereco, venda do plano, cadastro, contrato, instalacao e ativacao tecnica.
- **Rede de acesso:** backbone/backhaul, POPs, OLTs, splitters, CTOs, drop optico, ONU/ONT e roteador do cliente.
- **Ciclo financeiro:** geracao recorrente de faturas, boleto/PIX, baixa bancaria, cobranca, notificacao de debito, suspensao, desbloqueio temporario e reconexao.
- **Suporte:** triagem remota, testes de equipamento/linha, abertura de ordem de servico, despacho tecnico e acompanhamento.
- **Retencao e upgrade:** aumento de velocidade, troca de plano, renegociacao, fidelidade, desconto e migracao tecnologica.

O diferencial competitivo de ISPs regionais costuma ser proximidade local, instalacao rapida, atendimento via WhatsApp, preco competitivo e capilaridade em bairros/cidades pouco priorizados por grandes operadoras. O risco operacional e que muitas decisoes dependem de informacao em tempo real do ERP, concentrador/Radius, OLT, gateways de pagamento e agenda de campo.

## 2. Glossario do dominio ISP + HubSoft

| Termo | Significado para o dominio |
|---|---|
| ISP / Provedor | Empresa que presta servico de conexao a internet, normalmente SCM no contexto regulatorio brasileiro. |
| SCM | Servico de Comunicacao Multimidia; enquadramento regulatorio usual da banda larga fixa. |
| PPP | Prestadora de Pequeno Porte; segundo a Anatel, grupo com participacao nacional inferior a 5% no mercado de varejo relevante. |
| FTTH | Fiber to the Home; fibra optica ate a residencia/empresa do assinante. |
| GPON | Padrao de rede optica passiva usado em FTTH, compartilhando uma porta OLT entre multiplos clientes por divisao optica. |
| OLT | Optical Line Terminal; equipamento no POP/central que controla portas PON e ONUs/ONTs dos clientes. |
| PON | Rede optica passiva entre OLT, splitters e clientes. Tambem aparece como porta/interface PON. |
| ONU/ONT | Equipamento optico no cliente que autentica/conecta a fibra do provedor. |
| CTO | Caixa de Terminação Optica; ponto de distribuicao na rua, poste, predio ou condominio para conexao do drop do cliente. |
| Drop optico | Cabo final entre CTO e residencia/empresa do cliente. |
| POP | Ponto de presenca do provedor onde ficam OLTs, roteadores e agregacao de rede. |
| Backhaul | Transporte entre POPs/cidades e a rede principal ou upstream. |
| Upstream/transito IP | Conectividade comprada para acesso a internet global. |
| IX/PTT | Ponto de troca de trafego, como IX.br, usado para reduzir custo e latencia. |
| Radius/PPPoE/IPoE | Mecanismos de autenticacao e controle de acesso do assinante. |
| CGNAT | Compartilhamento de IPv4 publico entre varios clientes; relevante para suporte, jogos, cameras e logs. |
| Plano/Servico | Oferta comercial/tecnica vendida ao cliente; no HubSoft, Servico/Plano define tecnologia, grupo, composicao, contratos, descontos, taxa de instalacao, download/upload e pacotes. |
| Cliente | Pessoa fisica ou juridica cadastrada no ERP, com dados cadastrais, contatos, documentos e servicos vinculados. |
| Cliente servico | Instancia do plano contratado por um cliente; e o ponto operacional para contrato, autenticacao, endereco, status, faturamento e acoes tecnicas. |
| Contrato | Instrumento juridico/comercial vinculado ao plano e ao servico do cliente; pode ser obrigatorio ou opcional conforme configuracao do plano. |
| Fatura/cobranca | Documento financeiro de mensalidade, taxa ou outros lancamentos; pode ter boleto, PIX, vencimento, pagamento, juros/multa e status. |
| Boleto | Meio de pagamento bancario tradicional, usado para cobranca recorrente. |
| PIX copia e cola / QR Code | Representacao do PIX para pagamento; no HubSoft App do Cliente, cliente pode consultar QR Code e copia e cola. |
| Inadimplencia | Existencia de debito vencido; pode iniciar notificacao e processo de suspensao conforme contrato e regulacao. |
| Corte/bloqueio/suspensao | Restricao ou suspensao do servico por inadimplencia. No RGC atual, SCM pode ser suspenso integralmente apos o prazo de notificacao aplicavel. |
| Desbloqueio em confianca | Liberacao temporaria do servico para cliente inadimplente, por politica comercial do provedor. HubSoft oferece esse recurso no App do Cliente quando habilitado no sistema web. |
| Reconexao/restabelecimento | Retorno do servico apos pagamento, acordo ou desbloqueio permitido; o RGC exige restabelecimento em ate 1 dia apos ciencia do pagamento antes da rescisao. |
| Protocolo/atendimento | Registro formal de contato e tratativa; essencial para auditoria, regulatorio, suporte e LGPD. |
| Ordem de servico (OS) | Tarefa tecnica para equipe de campo ou backoffice. |
| Viabilidade | Confirmacao de cobertura e capacidade tecnica no endereco antes da venda/upgrade. |
| Rede neutra | Modelo em que infraestrutura de acesso e operacao comercial podem ser separadas; HubSoft possui configuracoes de rede neutra no plano. |

## 3. Como o HubSoft modela clientes, contratos, planos e cobrancas

### Cliente

Pela API GraphQL publica, a entidade `clientes` expõe pelo menos `id_cliente`, `codigo_cliente`, `nome_razaosocial` e `cpf_cnpj`. Isso indica dois identificadores importantes: um ID interno e um codigo operacional de cliente. Para atendimento conversacional, o Evo CRM deve tratar CPF/CNPJ e codigo do cliente como chaves fortes, mas nunca como unica prova de identidade em acoes sensiveis.

Na API REST, a documentacao indexada informa que consultas podem usar parametros como `codigo_cliente`, `cpf_cnpj`, `id_cliente_servico` e `protocolo` em rotas de cliente/atendimento. Tambem ha opcoes de incluir relacoes, por exemplo contratos e desbloqueios em confianca vinculados ao servico. Como a documentacao publica e ampla e dinamica, a confirmacao final dos campos deve ser feita no tenant HubSoft real do provedor via Postman/schema.

### Cliente servico

`cliente_servico` e a entidade critica para a integracao. Ela representa um servico/plano efetivamente instalado ou contratado por um cliente. A documentacao REST expõe endpoints relacionados a cliente servico, incluindo senhas/documentacao do servico e operacoes que usam `id_cliente_servico`. Tambem ha referencia a CPE por `phy_addr`, descrito como MAC/serial da ONU ou equipamento equivalente que fornece acesso em camada 2.

Para Evo CRM, quase todas as acoes devem ser ancoradas em `id_cliente_servico`, nao apenas em `id_cliente`, porque um cliente pode ter mais de um contrato, endereco ou servico.

### Servico/Plano

No HubSoft, Servico/Plano concentra configuracao comercial, fiscal, contratual e tecnica:

- status inicial ao cadastrar;
- tecnologia do servico;
- grupo de servico;
- composicao financeira/fiscal;
- contratos vinculados, obrigatorios ou opcionais;
- desconto ate vencimento e mensalidade progressiva;
- taxa de instalacao;
- parametros de navegacao, incluindo download/upload;
- pacotes;
- configuracoes de rede neutra.

Isso significa que a venda via Evo CRM nao deve tratar "plano" como simples nome e preco. O plano pode disparar contrato, taxa, desconto, composicao fiscal e regras de rede.

### Contratos

O HubSoft permite vincular modelos de contrato a planos. Quando obrigatorio, o contrato fica atrelado ao servico no ato da adicao e nao pode ser removido nesse momento. A API REST tambem referencia endpoints de contrato que exigem `id_cliente_servico`, `id_contrato` e `id_empresa`, e permite envio de contratos pendentes por email.

Para automacao, aceite de contrato, envio e registro de autorizacao devem ser tratados como etapa propria, com evidencia e protocolo.

### Faturas, cobrancas, boleto e PIX

A documentacao publica e os materiais do App do Cliente indicam suporte a 2a via de boleto, QR Code PIX, PIX copia e cola, envio de fatura por email e pagamento por cartao em modulo especifico. A documentacao REST indexada indica filtros de faturas/cobrancas por `cpf_cnpj`, `codigo_cliente`, `id_cliente_servico`, status pendente, datas, vencimento, pagamento, cadastro, valor e cobrancas agrupadas.

O HubSoft tambem possui integracoes PIX bancarias. Em pagina de integracao PIX Sicoob/Bradesco, a wiki informa que o PIX pode aparecer na fatura e que o PIX COBV tem caracteristicas similares ao boleto, com vencimento, juros, multa, desconto e relacao direta com o boleto. Uma pagina da wiki informa que rotinas de verificacao de pagamentos PIX podem levar alguns minutos, portanto o atendimento deve separar "enviei o codigo" de "pagamento baixado".

### Protocolo e atendimento

O dominio regulatorio e de suporte exige protocolo. A documentacao REST indexada menciona filtros por `protocolo` e relacoes como `atendimento_mensagem`, `ordem_servico_mensagem` e `checklists`. Para Evo CRM, todo atendimento automatizado que consulte debito, desbloqueie, envie cobranca, execute diagnostico ou registre venda deve gerar ou vincular protocolo.

## 4. Dados necessarios para identificar cliente no HubSoft

### Identificacao minima recomendada

Para consulta inicial:

- CPF/CNPJ;
- codigo do cliente, quando disponivel;
- telefone/WhatsApp de contato;
- nome/razao social para confirmacao;
- endereco ou bairro, se houver ambiguidade;
- protocolo, se o cliente ja abriu atendimento;
- `id_cliente_servico`, quando o atendimento ja veio contextualizado.

Para acoes sensiveis:

- confirmar pelo menos dois fatores cadastrais nao triviais, por exemplo CPF/CNPJ + data de nascimento, endereco, email, nome completo ou ultimos digitos do documento;
- confirmar qual servico/contrato sera afetado quando houver multiplos enderecos;
- registrar aceite explicito antes de desbloqueio, acordo, envio de boleto/PIX para terceiro, upgrade ou contratacao.

### Regras praticas para Evo CRM

- Se houver um unico cliente e um unico `cliente_servico`, o bot pode seguir para triagem.
- Se houver multiplos servicos, o bot deve pedir escolha por endereco/apelido/plano, evitando expor dados em excesso.
- Se o WhatsApp nao bater com contato cadastrado, limitar informacoes e escalar para humano antes de exibir debitos detalhados ou enviar documentos.
- Nunca retornar CPF/CNPJ completo em mensagens; mascarar documentos.

## 5. Fluxos de atendimento por setor

### Financeiro

O fluxo financeiro comeca pela identificacao do cliente e do servico. O atendente, ou agente de IA, consulta o HubSoft por CPF/CNPJ, codigo do cliente, telefone ou protocolo e seleciona o `cliente_servico` correto. Em seguida verifica status financeiro: faturas pendentes, vencidas, valor atualizado, vencimento, juros/multa, existencia de suspensao, elegibilidade para desbloqueio em confianca e meios de pagamento disponiveis.

Se o cliente esta inadimplente mas ainda nao suspenso, o atendimento deve priorizar orientacao de pagamento: enviar 2a via, PIX copia e cola ou link/documento de boleto, informando vencimento e valor. Se o cliente ja esta suspenso, o agente deve explicar a situacao de forma neutra, oferecer pagamento e, se a politica do provedor permitir, oferecer desbloqueio em confianca. O desbloqueio em confianca deve ser registrado como acao temporaria, com prazo claro e sem afirmar quitacao da divida.

Apos envio de PIX/boleto, o agente deve informar que a baixa depende do processamento pelo banco/HubSoft. Quando houver confirmacao de pagamento ou primeira parcela de acordo antes da rescisao, a regulacao da Anatel exige restabelecimento em ate 1 dia contado da ciencia do pagamento. O Evo CRM deve registrar protocolo, canal, fatura enviada, acao realizada e resultado.

Pontos de escalonamento: contestacao de valor, acordo/parcelamento, cliente sem reconhecimento do debito, pedido de cancelamento, negativacao, divergencia cadastral, multiplos contratos, cliente vulneravel ou qualquer falha no retorno do HubSoft.

### Suporte

O fluxo de suporte comeca por identificar cliente e `cliente_servico`, confirmar endereco afetado e coletar sintoma: sem internet, lentidao, Wi-Fi ruim, queda intermitente, luz LOS/PON, problema em site/app especifico, mudanca de senha ou equipamento. O agente consulta o HubSoft para obter dados do servico e, quando disponivel via integracoes do provedor, diagnosticos da linha/CPE/ONU.

Diagnosticos comuns incluem status do servico, status financeiro que possa bloquear acesso, equipamento online/offline, sinal optico, autenticação PPPoE/IPoE, MAC/serial (`phy_addr`), ultima conexao, plano contratado, velocidade, CTO/porta, endereco e historico recente de OS. O agente deve separar falha financeira de falha tecnica: um cliente suspenso por inadimplencia nao deve ser conduzido por testes longos de Wi-Fi antes de resolver o bloqueio.

Para problemas simples, o agente pode orientar reinicio controlado de roteador/ONU, verificar cabos, confirmar luzes, testar outro dispositivo e coletar evidencias. Para problemas de rede, sinal optico ruim, ONU offline, rompimento provavel, CTO sem sinal, varias reclamacoes na mesma regiao ou falha recorrente, deve abrir ou encaminhar OS/protocolo para equipe tecnica.

Pontos de escalonamento: diagnostico inconclusivo, equipamento sem telemetria, necessidade de acesso a OLT/Radius nao exposto na API, cliente empresarial/SLA, suspeita de massiva, mudanca de endereco, troca de titularidade, visita tecnica e qualquer ajuste que possa derrubar o servico.

### Vendas

O fluxo de vendas deve primeiro classificar o lead: cliente novo, cliente existente interessado em upgrade, ex-cliente ou cliente com mais de um endereco. Para cliente novo, coletar nome, CPF/CNPJ, WhatsApp, endereco completo e preferencia de plano. Para cliente existente, identificar cliente e servico ativo antes de ofertar upgrade.

Em seguida, o atendimento consulta planos disponiveis e valida viabilidade. Planos nao sao apenas velocidade e preco: no HubSoft podem carregar tecnologia, grupo, contratos, taxa de instalacao, descontos, composicao e pacotes. Para fibra optica, a venda deve depender de cobertura, porta/CTO/capacidade e agenda. Para planos moveis, deve depender de disponibilidade comercial, cobertura movel, regras de chip/eSIM, portabilidade e documento.

Quando houver plano elegivel, o agente apresenta oferta com preco, velocidade, fidelidade, taxa de instalacao, prazo de instalacao, equipamentos e condicoes. Antes de confirmar, deve registrar aceite, gerar lead/cliente/contrato conforme regra do provedor e abrir tarefa comercial ou OS de instalacao. Para upgrade, deve verificar fidelidade, vencimento, mudanca de preco, necessidade de trocar equipamento e impacto no contrato.

Pontos de escalonamento: endereco sem cobertura, cliente inadimplente pedindo upgrade, plano empresarial, negociacao fora da tabela, cancelamento/retencao, alteracao de titularidade, portabilidade movel e aceite contratual.

## 6. Restricoes legais e regulatorias para bloqueio/desbloqueio

### Suspensao por inadimplencia

O RGC vigente na Resolucao Anatel 765/2023 permite que a prestadora suspenda o servico apos 15 dias da notificacao ao consumidor sobre debito vencido, fim dos creditos ou fim da validade dos creditos. Para SCM, a norma permite suspensao integral apos o prazo de notificacao. A notificacao deve informar motivos, regras e prazos de suspensao/rescisao, valor do debito e mes de referencia, possibilidade de registro em protecao ao credito apos rescisao e prazo de restabelecimento.

### Rescisao e restabelecimento

Transcorridos 60 dias da suspensao, a prestadora pode rescindir o contrato mediante previa notificacao. Se o consumidor pagar o debito antes da rescisao, a prestadora deve restabelecer o servico em ate 1 dia contado da ciencia do pagamento. E vedada a cobranca pelo restabelecimento. Em parcelamento, o prazo conta da ciencia do pagamento da primeira parcela.

### Limite do bloqueio

As providencias de suspensao devem atingir apenas o servico ou codigo de acesso em que foi constatada a inadimplencia. Isso e importante para clientes com multiplos contratos: nao se deve bloquear outro servico sem debito proprio.

### Marco Civil da Internet

O Marco Civil da Internet estabelece como direito do usuario a nao suspensao da conexao, salvo por debito diretamente decorrente de sua utilizacao. Para a automacao, isso reforca que bloqueio/desbloqueio deve ser amarrado a debito do proprio servico de conexao e a regras contratuais/regulatorias, nao a qualquer divida generica.

### Desbloqueio em confianca

O desbloqueio em confianca e uma politica comercial/operacional do provedor suportada pelo HubSoft, nao uma quitacao. A pagina do App do Cliente informa que o cliente pode realizar desbloqueio em confianca quando a funcionalidade esta ativa no Sistema Web. Para Evo CRM, isso implica:

- consultar elegibilidade no HubSoft antes de oferecer;
- informar prazo temporario de liberacao;
- registrar aceite e protocolo;
- nao prometer novo desbloqueio futuro;
- nao mascarar que a fatura continua pendente;
- respeitar as politicas do provedor sobre quantidade, intervalo e dias de desbloqueio.

### LGPD e sigilo

Atendimentos por WhatsApp/chat manipulam CPF/CNPJ, endereco, historico financeiro, contrato, logs tecnicos e protocolos. O Evo CRM deve aplicar minimizacao de dados, mascaramento, controle de permissao por setor, trilha de auditoria e retencao adequada. Envio de boleto/PIX para contato nao cadastrado deve ser tratado como risco de vazamento e fraude.

## 7. Pontos de atencao e riscos do dominio

### Riscos financeiros

- Baixa de PIX/boleto pode nao ser instantanea no HubSoft, mesmo que o cliente apresente comprovante.
- Reativar servico sem elegibilidade pode violar politica comercial e aumentar inadimplencia.
- Enviar fatura errada em cliente com multiplos contratos pode vazar dados.
- Contestacao de debito exige fluxo humano e protocolo forte.

### Riscos tecnicos

- "Sem internet" pode ser inadimplencia, falha Wi-Fi, ONU offline, rompimento de fibra, queda regional, Radius, CGNAT ou DNS.
- Diagnosticos de OLT/Radius podem depender de integracoes do provedor que nao estao garantidas na API publica.
- Acoes automaticas em rede, como reboot/provisionamento, podem derrubar cliente errado se `id_cliente_servico` ou `phy_addr` estiver incorreto.
- CTO/porta/endereco desatualizados geram OS improdutiva.

### Riscos comerciais

- Plano no HubSoft carrega regras de contrato, taxa, desconto e composicao; vender apenas por nome/preco gera divergencia.
- Upgrade pode exigir novo contrato, troca de ONU/roteador ou alteracao de fidelidade.
- Disponibilidade de fibra depende de viabilidade real, nao apenas CEP.
- Plano movel envolve regras diferentes de portabilidade, cobertura e ativacao.

### Riscos regulatorios

- Suspensao deve seguir notificacao, prazos e escopo do debito.
- Restabelecimento apos pagamento tem prazo regulatorio.
- Registro em protecao ao credito exige notificacao e baixa apos quitacao.
- Cancelamento pode ser solicitado mesmo com inadimplencia; debitos remanescentes devem ser informados, nao usados para impedir o pedido.

### Riscos de IA conversacional

- O agente pode prometer prazos, descontos ou desbloqueios sem confirmacao do HubSoft.
- O agente pode revelar informacoes financeiras antes de validar identidade.
- O agente pode confundir "cliente" com "servico" em contas com multiplos enderecos.
- O agente pode insistir em troubleshooting tecnico quando o servico esta suspenso por inadimplencia.

## 8. Implicacoes para o desenho da integracao Evo CRM

### Entidades minimas para o modelo de contexto

- `hubsoft_cliente`: `id_cliente`, `codigo_cliente`, nome/razao social, CPF/CNPJ mascarado, contatos.
- `hubsoft_cliente_servico`: `id_cliente_servico`, plano, status, endereco, tecnologia, identificadores tecnicos, contrato vinculado.
- `hubsoft_plano`: nome, grupo, tecnologia, download/upload, preco, descontos, taxa de instalacao, contratos, pacotes.
- `hubsoft_fatura`: id, valor, vencimento, status, codigo/link boleto, PIX copia e cola/QR, data pagamento, composicao quando necessaria.
- `hubsoft_protocolo`: numero, setor, canal, mensagens, OS/checklists relacionados, status.
- `hubsoft_desbloqueio_confianca`: elegibilidade, dias, historico, status, regra/politica.

### Guardrails por setor

- **Financeiro:** exigir identidade validada antes de detalhes de debito; sempre consultar elegibilidade antes de desbloquear; registrar protocolo.
- **Suporte:** checar status financeiro antes de diagnostico longo; nao executar acao tecnica destrutiva sem confirmacao; abrir OS quando diagnostico for inconclusivo.
- **Vendas:** validar cobertura e plano vigente; explicitar fidelidade/taxa; registrar aceite; escalar negociacoes fora da regra.

### Perguntas que a fase tecnica deve validar

- Quais endpoints REST exatos do tenant retornam faturas, PIX, boleto e desbloqueio em confianca?
- O provedor tem GraphQL habilitado para o usuario OAuth da integracao?
- O HubSoft do cliente expõe diagnosticos tecnicos suficientes ou sera preciso integrar OLT/Radius/NMS separadamente?
- Qual e a politica configurada de desbloqueio em confianca: quantidade, intervalo, dias e bloqueios impeditivos?
- Como criar/vincular protocolo e mensagens do atendimento via API?
- Como o tenant diferencia planos fibra, planos moveis, pacotes e rede neutra?

## 9. Conclusao

O dominio ISP brasileiro exige que o Evo CRM opere como uma camada de atendimento contextual, nao apenas como chatbot. A integracao com HubSoft deve priorizar identificacao segura, selecao correta de `cliente_servico`, leitura de estado financeiro, leitura de plano/contrato, registro de protocolo e escalonamento disciplinado.

O melhor primeiro recorte para MVP e financeiro assistido: identificar cliente, listar faturas pendentes, enviar PIX/boleto, consultar status e oferecer desbloqueio em confianca somente quando o HubSoft declarar elegivel. Suporte e vendas devem vir em seguida, porque dependem de maior variabilidade de rede, cobertura, planos e processos internos do provedor.
