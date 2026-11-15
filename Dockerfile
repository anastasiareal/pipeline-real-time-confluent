# Flink 2.2.1 e Kafka SQL Connector 5.0.0-2.2 sao versoes compativeis.
FROM flink:2.2.1-scala_2.12-java17

# O conector SQL Kafka nao vem embutido na distribuicao padrao do Flink.
ADD https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/5.0.0-2.2/flink-sql-connector-kafka-5.0.0-2.2.jar /opt/flink/lib/flink-sql-connector-kafka.jar
