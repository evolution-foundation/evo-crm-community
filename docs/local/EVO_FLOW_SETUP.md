# Evo-Flow Setup & Deployment

Este documento contém as instruções para subir a stack do `evo-flow` (que gerencia as Jornadas Automatizadas e Campanhas) tanto no ambiente de desenvolvimento local quanto em produção utilizando Swarm/Portainer.

O `evo-flow` requer um conjunto próprio de serviços auxiliares que rodam em paralelo ao core do CRM:
- **Temporal** (Orquestrador de workflows)
- **ClickHouse** (Banco colunar para analytics/eventos)
- **Kafka / Zookeeper** (Fila de mensageria para streaming de eventos)

---

## 1. Ambiente Local (Desenvolvimento)

O ambiente local do orquestrador foi configurado em uma stack docker-compose separada para facilitar a manutenção e não sobrecarregar o `docker-compose.yml` principal caso você não vá trabalhar com jornadas na sessão.

### Passo a passo para rodar localmente:

1. Certifique-se de que a rede padrão e os serviços base (PostgreSQL e Redis) estejam rodando, pois o `evo-flow` se conecta a eles:
   ```bash
   docker-compose up -d postgres redis
   ```
2. Inicialize a stack do `evo-flow`:
   ```bash
   docker-compose -f docker-compose.evo-flow.yml up -d
   ```
3. Verifique os logs para garantir que o Temporal iniciou com sucesso e o NestJS conectou aos serviços:
   ```bash
   docker logs --tail 100 -f evo-flow
   ```
   *(Aguarde até visualizar a mensagem de sucesso que o Kafka e o banco ClickHouse foram inicializados).*

4. **Rodar Migrations do Flow:**  
   Se for a primeira vez rodando o container localmente, você precisa criar a tabela de `journeys` no PostgreSQL:
   ```bash
   docker exec evo-flow npx typeorm migration:run -d dist/database/ormconfig.js
   ```

---

## 2. Produção / VPS com Portainer (Docker Swarm)

Para produção, o ideal é criar uma **Stack separada** no Portainer especificamente para o motor de campanhas (`evo-campaign-stack`), para que possa escalar independentemente do monolito principal.

### Passo a passo no Portainer:

1. Acesse seu painel do **Portainer** > **Stacks** > **Add stack**.
2. Nomeie a stack como: `evo-campaign`
3. Cole o arquivo Compose abaixo no web editor. Repare que ele se conecta à rede pública (`network_swarm_public`) e aos serviços do Postgres/Redis que você já definiu na sua VPS.

### Exemplo de Compose para o Portainer:

```yaml
version: "3.8"

services:
  clickhouse:
    image: clickhouse/clickhouse-server:latest
    environment:
      - CLICKHOUSE_DB=evo_campaign
      - CLICKHOUSE_USER=default
      - CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1
    networks:
      - network_swarm_public
    deploy:
      replicas: 1

  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    networks:
      - network_swarm_public
    deploy:
      replicas: 1

  kafka:
    image: confluentinc/cp-kafka:7.4.0
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://kafka:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    networks:
      - network_swarm_public
    deploy:
      replicas: 1

  temporal:
    image: temporalio/auto-setup:latest
    environment:
      - DB=postgres12
      - DB_PORT=5432
      # Aponte para o serviço de Postgres existente no Swarm
      - POSTGRES_USER=evo_user
      - POSTGRES_PWD=EvoPass2026aB0A
      - POSTGRES_SEEDS=evo-crm-db_postgres
      - DYNAMIC_CONFIG_FILE_PATH=/etc/temporal/config/dynamicconfig/development-sql.yaml
    networks:
      - network_swarm_public
    deploy:
      replicas: 1

  evo-flow:
    # Substitua a imagem abaixo pela sua imagem publicada no seu Docker Hub (ex: lc1868/evo-flow:latest)
    image: lc1868/evo-flow:latest 
    environment:
      - RUN_MODE=single
      - PORT=3334
      - QUEUE_MODE=kafka
      - WRITE_MODE=kafka
      # Conexão com o Postgres da VPS
      - POSTGRES_DB_HOST=evo-crm-db_postgres
      - POSTGRES_DB_PORT=5432
      - POSTGRES_DB_USERNAME=evo_user
      - POSTGRES_DB_PASSWORD=EvoPass2026aB0A
      - POSTGRES_DB_DATABASE=evo_community
      # Clickhouse local da stack
      - CLICKHOUSE_HOST=clickhouse
      - CLICKHOUSE_PORT=8123
      - CLICKHOUSE_DATABASE=evo_campaign
      - CLICKHOUSE_USERNAME=default
      - CLICKHOUSE_PASSWORD=
      # Conexão com Redis da VPS
      - REDIS_HOST=evo-crm-redis_cache
      - REDIS_PORT=6379
      - REDIS_PASSWORD=
      - REDIS_DB=0
      - KAFKA_BROKERS=kafka:29092
      - EVOAI_CRM_BASE_URL=http://evo_crm:3000
      - EVO_AUTH_SERVICE_URL=http://evo_auth:3001
      - EVOAI_CRM_API_TOKEN=evo_token_3a1b4c5d6e7f8g9h0i1j2k3l
      - TEMPORAL_ADDRESS=temporal:7233
    networks:
      - network_swarm_public
    deploy:
      replicas: 1

networks:
  network_swarm_public:
    external: true
```

### 4. Publicar e Configurar Gateway

1. Certifique-se de que construiu e publicou a imagem do `evo-flow` usando o seu DockerHub (`lc1868/evo-flow:latest`) seguindo o procedimento descrito no `AGENTS.md`.
2. Após o deploy no Portainer, assim que o container `evo-flow` ficar com o status *Running*, acesse o console dele no Portainer e rode o comando de migrations uma única vez para provisionar as tabelas no DB de produção:
   ```bash
   npx typeorm migration:run -d dist/database/ormconfig.js
   ```
3. Lembre-se de adicionar a rota do `evo-flow` (porta 3334) no API Gateway Nginx da stack principal caso queira expor externamente o endpoint de tracking/analytics (opcional se não usar integrações front-end de captação abertas).

---
