param(
    [string]$Topic = "payments.public.cdc_probe"
)
$ErrorActionPreference = "Stop"
Write-Host "Lendo tópico $Topic desde o início. Pressione Ctrl+C para interromper."
docker compose exec kafka /kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic $Topic --from-beginning --property print.key=true --property print.value=true
