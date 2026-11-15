$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root ".env"
if (-not (Test-Path $envFile)) { throw "Arquivo .env não encontrado. Copie .env.example para .env e ajuste a senha local." }

$passwordLine = Get-Content $envFile | Where-Object { $_ -match '^\s*POSTGRES_PASSWORD=' } | Select-Object -First 1
if (-not $passwordLine) { throw "POSTGRES_PASSWORD não encontrada no .env." }
$password = ($passwordLine -replace '^\s*POSTGRES_PASSWORD=', '').Trim().Trim('"').Trim("'")
if ([string]::IsNullOrWhiteSpace($password)) { throw "POSTGRES_PASSWORD está vazia no .env." }

$connectorPath = Join-Path $root "connect/postgres-connector.json"
$payload = Get-Content $connectorPath -Raw | ConvertFrom-Json
$payload.config.'database.password' = $password
$connectorName = $payload.name
$baseUrl = "http://localhost:8083"

Write-Host "Aguardando Kafka Connect em $baseUrl ..."
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    try { Invoke-RestMethod -Uri "$baseUrl/connectors" -Method Get | Out-Null; $ready = $true; break }
    catch { Start-Sleep -Seconds 3 }
}
if (-not $ready) { throw "Kafka Connect não respondeu. Verifique: docker compose logs connect" }

try {
    Invoke-RestMethod -Uri "$baseUrl/connectors/$connectorName" -Method Get | Out-Null
    $body = $payload.config | ConvertTo-Json -Depth 20
    Invoke-RestMethod -Uri "$baseUrl/connectors/$connectorName/config" -Method Put -ContentType "application/json" -Body $body | Out-Null
    Write-Host "Configuração do conector atualizada: $connectorName"
} catch {
    if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
        $body = $payload | ConvertTo-Json -Depth 20
        Invoke-RestMethod -Uri "$baseUrl/connectors" -Method Post -ContentType "application/json" -Body $body | Out-Null
        Write-Host "Conector criado: $connectorName"
    } else { throw }
}
Invoke-RestMethod -Uri "$baseUrl/connectors/$connectorName/status" -Method Get | ConvertTo-Json -Depth 10
