# Pipeline de pagamentos em tempo real — ambiente local

> Primeiro marco do projeto DIO: PostgreSQL → Debezium CDC → Kafka, com Schema Registry para praticar contratos. O processamento Flink será adicionado depois que a captura CDC estiver comprovada.

## 1. Objetivo

Este repositório inicia uma implementação local e sem cobrança de nuvem. O foco deste marco é provar que o PostgreSQL publica mudanças de linha via WAL/logical replication, que o Debezium captura `INSERT`, `UPDATE` e `DELETE`, e que os eventos chegam aos tópicos Kafka.

**Importante:** Kafka, Debezium, PostgreSQL e Schema Registry locais são substitutos de desenvolvimento. Eles não são evidência de uma execução no Confluent Cloud. A migração para Confluent Cloud será uma etapa posterior.

## 2. Arquitetura deste marco

```text
PostgreSQL 17 (wal_level=logical)
        |
        | WAL / logical replication (pgoutput)
        v
Debezium PostgreSQL Connector 3.7
        |
        | Kafka Connect + SMT ExtractNewRecordState
        v
Kafka (KRaft, broker único)
        |
        +--> payments.public.accounts
        +--> payments.public.transactions
        +--> payments.public.cdc_probe

Confluent Schema Registry local (contratos Avro de exemplo)
```

O Flink ainda não roda neste primeiro marco. A separação é intencional: primeiro validamos a ingestão e o contrato; depois adicionamos processamento e detecção de fraude.

## 3. Pré-requisitos

- Docker Desktop instalado e aberto.
- Docker Compose v2 (`docker compose version`).
- Windows: Docker Desktop com backend WSL 2 recomendado; execute os comandos no PowerShell, na pasta do projeto.
- Conexão com a internet para baixar as imagens na primeira execução.
- Espaço em disco e memória disponíveis. O primeiro download pode ser grande.

Documentação oficial: [Confluent Platform local quickstart](https://docs.confluent.io/platform/current/get-started/platform-quickstart.html) e [Debezium PostgreSQL connector](https://debezium.io/documentation/reference/3.7/connectors/postgresql.html).

## 4. Configuração inicial (Windows PowerShell)

Na pasta deste repositório:

```powershell
Copy-Item .env.example .env
notepad .env
```

Ajuste `POSTGRES_PASSWORD` para uma senha local. O arquivo `.env` está no `.gitignore` e não deve ser enviado ao GitHub.

Suba os serviços:

```powershell
docker compose up -d
```

Confira o estado:

```powershell
docker compose ps
```

Espere o PostgreSQL ficar `healthy`. Os outros serviços podem levar mais alguns instantes.

## 5. Criar o conector CDC

O script lê `POSTGRES_PASSWORD` de `.env` e injeta a senha somente na chamada ao Kafka Connect. A senha não fica no arquivo JSON versionado.

```powershell
.\scripts\register-connector.ps1
```

O status esperado do connector é `RUNNING` e a task deve aparecer como `RUNNING`.

Verifique manualmente pela API REST:

```powershell
Invoke-RestMethod http://localhost:8083/connectors/payments-postgres-cdc/status | ConvertTo-Json -Depth 10
```

## 6. Provar INSERT, UPDATE e DELETE

Execute as operações na tabela auxiliar `cdc_probe`:

```powershell
.\scripts\test-cdc.ps1
```

Leia os eventos:

```powershell
.\scripts\read-topic.ps1 -Topic payments.public.cdc_probe
```

Você deve observar a chave do registro e os valores publicados. Com `ExtractNewRecordState`, INSERT e UPDATE chegam como estado achatado. DELETE é mantido como tombstone (valor `null`) para que consumidores que mantêm estado por chave possam remover o registro.

Também confira os tópicos das tabelas de negócio:

```powershell
.\scripts\read-topic.ps1 -Topic payments.public.transactions
.\scripts\read-topic.ps1 -Topic payments.public.accounts
```

Os dados iniciais são enviados por snapshot (`snapshot.mode=initial`), portanto podem aparecer como eventos de leitura inicial (`op=r`) no metadata do conector, dependendo do formato configurado.

## 7. Testar Schema Registry

Execute:

```powershell
.\scripts\register-schemas.ps1
```

O script define compatibilidade `BACKWARD` e registra duas versões do contrato Avro. A versão 2 adiciona `merchant_category` como campo opcional com valor padrão `null`.

Verifique os subjects:

```powershell
Invoke-RestMethod http://localhost:8081/subjects
```

**Limite conhecido deste marco:** os eventos do conector CDC são serializados em JSON para simplificar a primeira integração com Kafka Connect e Flink SQL. Os schemas Avro são registrados e testados no Schema Registry, mas ainda não são os serializers dos tópicos CDC. A integração Avro/Schema Registry será feita em uma etapa posterior.

## 8. Dados de demonstração

O arquivo `postgres/init.sql` cria:

- `accounts`: dimensão de contas e nível de risco;
- `transactions`: eventos sintéticos de pagamento;
- `cdc_probe`: tabela auxiliar para comprovar INSERT, UPDATE e DELETE sem alterar eventos de pagamento.

O cartão `CARD-ALPHA` tem três pagamentos em 20 segundos. O cartão `CARD-BETA` tem apenas dois. Esses dados serão usados nos testes da regra de fraude no Flink.

A tabela `transactions` é tratada como append-only para a regra de fraude: uma linha nova equivale a um evento de pagamento. Correções e cancelamentos não devem ser contabilizados como novas compras; em um projeto mais completo, devem ser representados por eventos de domínio separados.

## 9. Diagnóstico rápido

```powershell
docker compose logs --tail 100 postgres
docker compose logs --tail 100 kafka
docker compose logs --tail 100 connect
docker compose logs --tail 100 schema-registry
```

Verificar a replicação lógica no PostgreSQL:

```powershell
docker compose exec postgres psql -U postgres -d payments -c "SHOW wal_level;"
docker compose exec postgres psql -U postgres -d payments -c "SELECT slot_name, plugin, slot_type, active, confirmed_flush_lsn FROM pg_replication_slots;"
docker compose exec postgres psql -U postgres -d payments -c "SELECT pubname, schemaname, tablename FROM pg_publication_tables ORDER BY 1,2,3;"
```

Esperado: `wal_level=logical`, replication slot ativo após o conector iniciar, e publicação cobrindo as tabelas incluídas.

Se a task do conector falhar, confira primeiro o log do Connect e o status detalhado da task. Não exclua volumes nem replication slots como primeira tentativa: isso pode apagar evidências e causar novo snapshot.

## 10. Parar e limpar

Parar os containers, preservando os dados:

```powershell
docker compose down
```

Apagar containers **e os volumes persistentes** (isso remove os dados locais do banco e do Kafka):

```powershell
docker compose down -v
```

Use `down -v` somente quando tiver certeza de que não precisa mais dos dados e das evidências.

## 11. Evidências para o README da entrega

Salve capturas de tela/saídas reais em `evidence/` depois da execução. Não preencha resultados que não foram executados.

- [ ] `docker compose ps` com os serviços ativos;
- [ ] status do conector com `connector=RUNNING` e `task=RUNNING`;
- [ ] evento de INSERT no tópico `cdc_probe`;
- [ ] evento de UPDATE no tópico `cdc_probe`;
- [ ] tombstone de DELETE no tópico `cdc_probe`;
- [ ] subjects e versões do Schema Registry;
- [ ] resultado das consultas de `wal_level`, replication slot e publication.

## 12. Próximas etapas

1. Adicionar Flink SQL com conector Kafka compatível com a versão do Flink.
2. Criar uma fonte append-only de transações e enriquecer com a dimensão de contas.
3. Implementar a detecção de três transações do mesmo cartão em uma janela de 60 segundos.
4. Publicar alertas em `payments.fraud-alerts` e testar casos positivos/negativos.
5. Acrescentar métricas, reconciliação de contagens e custos locais (consumo de CPU/memória/disco) e preparar a migração para Confluent Cloud.

## 13. Licenças e uso

Este repositório é um ambiente didático local. Consulte as licenças e políticas de uso das imagens/conectores antes de uso comercial ou produção. Não utilize dados reais de cartões ou credenciais reais.
