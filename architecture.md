# Decisões arquiteturais — primeiro marco

## Por que Debezium

O conector lê a logical replication stream do PostgreSQL (`pgoutput`) e transforma alterações de linhas em change events. O primeiro start executa snapshot inicial; depois acompanha alterações committed no WAL.

## Por que tópicos por tabela

O prefixo `payments` e o schema `public` produzem tópicos `payments.public.<tabela>`. Isso mantém a origem rastreável e permite configurar contratos e consumidores por entidade.

## Por que `ExtractNewRecordState`

O SMT simplifica o envelope Debezium para o estado da linha, o que facilita a primeira leitura com Flink SQL. Para DELETE, a configuração mantém tombstones. A semântica do evento é documentada no README.

## Por que a tabela de teste separada

`cdc_probe` comprova INSERT/UPDATE/DELETE sem atualizar ou remover transações financeiras que serão usadas para detecção de frequência. O pipeline de fraude trata pagamentos como eventos imutáveis.

## Limitações conscientes

- Broker único, sem alta disponibilidade.
- Rede local sem autenticação TLS/SASL.
- Serializer JSON no CDC; Avro é apenas um contrato registrado/testado nesta fase.
- Sem Flink ainda; a regra de fraude será implementada após comprovar a ingestão.
- Não usar em produção.
