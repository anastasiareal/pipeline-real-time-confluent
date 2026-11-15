$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$base = "http://localhost:8081"
$subject = "payments-transactions-value"
$contentType = "application/vnd.schemaregistry.v1+json"

# Aguarda o Schema Registry ficar disponível.
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    try { Invoke-RestMethod -Uri "$base/subjects" -Method Get | Out-Null; $ready = $true; break }
    catch { Start-Sleep -Seconds 3 }
}
if (-not $ready) { throw "Schema Registry não respondeu. Verifique: docker compose logs schema-registry" }

Invoke-RestMethod -Uri "$base/config/$subject" -Method Put -ContentType $contentType -Body '{"compatibility":"BACKWARD"}' | Out-Null
foreach ($version in @("v1", "v2")) {
    $schemaPath = Join-Path $root "schemas/transaction-$version.avsc"
    $schemaText = Get-Content $schemaPath -Raw
    $body = @{ schema = $schemaText; schemaType = "AVRO" } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Uri "$base/subjects/$subject/versions" -Method Post -ContentType $contentType -Body $body
    Write-Host "Registrado $version do subject $subject. ID do schema: $($response.id)"
}
Write-Host "Compatibilidade BACKWARD validada ao registrar o campo opcional merchant_category com default null."
Write-Host "NOTA: neste primeiro corte, Kafka Connect publica os tópicos CDC em JSON. Os schemas Avro são um exercício de contrato no Registry, ainda não são o serializer dos tópicos CDC."
