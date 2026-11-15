-- Primeiro teste do SQL Client. Este SELECT simples valida a sessao Flink SQL.
SET 'execution.runtime-mode' = 'batch';
SET 'sql-client.execution.result-mode' = 'tableau';

SELECT 'Flink SQL conectado' AS status;
