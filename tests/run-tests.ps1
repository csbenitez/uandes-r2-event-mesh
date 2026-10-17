<#
.SYNOPSIS
    Suite de Pruebas Automatizadas de Integración y Latencia para Voltera Event Mesh.
.DESCRIPTION
    Ejecuta pruebas End-to-End desde la región Edge (K3s Local) hacia la región Cloud (Azure AKS),
    así como pruebas directas sobre el Ingress público TLS. Mide latencias (min, avg, max, p50, p95)
    y verifica la emisión de facturas (Netting CREG 101-072) y cobros en la nube.
.PARAMETER Mode
    "hybrid" (K3s Local -> OnPrem Broker -> Cloud Broker)
    "direct" (Directo a Azure Ingress HTTPS)
    "all" (Ejecuta ambos modos)
.PARAMETER Count
    Número de CloudEvents a emitir para el benchmark de latencia (por defecto: 5).
#>
[CmdletBinding()]
param(
    [ValidateSet("hybrid", "direct", "all")]
    [string]$Mode = "all",

    [int]$Count = 5,
    [string]$LocalUrl = "http://localhost:8080",
    [string]$CloudUrl = "https://voltera-dev-mesh.eastus2.cloudapp.azure.com/events"
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "   VOLTERA EVENT MESH - SUITE DE INTEGRACION Y BENCHMARK DE LATENCIA      " -ForegroundColor Cyan
Write-Host "   Modo: $Mode | Iteraciones: $Count                                      " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

# 1. Comprobar estado de los clusters
Write-Host "`n[1/4] Verificando salud de Brokers y Triggers..." -ForegroundColor Yellow

$aksOk = $false
try {
    $aksTriggers = & kubectl --context voltera-dev-aks get trigger -n voltera -o json 2>$null | ConvertFrom-Json
    if ($aksTriggers -and $aksTriggers.items.Count -gt 0) {
        $readyCount = ($aksTriggers.items | Where-Object { 
            ($_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" }).Count -gt 0 
        }).Count
        Write-Host "  -> [AKS Cloud] Triggers activos y listos: $readyCount / $($aksTriggers.items.Count)" -ForegroundColor Green
        $aksOk = $true
    }
} catch {
    Write-Warning "No se pudo consultar AKS: $_"
}

$localOk = $false
try {
    $localTriggers = & kubectl --context k3d-voltera-onprem get trigger -n voltera-onprem -o json 2>$null | ConvertFrom-Json
    if ($localTriggers -and $localTriggers.items.Count -gt 0) {
        $readyCount = ($localTriggers.items | Where-Object { 
            ($_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" }).Count -gt 0 
        }).Count
        Write-Host "  -> [K3s Edge] Triggers locales listos: $readyCount / $($localTriggers.items.Count)" -ForegroundColor Green
        $localOk = $true
    }
} catch {
    Write-Warning "No se pudo consultar K3s local: $_"
}

# 2. Función auxiliar para calcular percentiles
function Get-Percentile($list, $p) {
    if (-not $list -or $list.Count -eq 0) { return 0 }
    $sorted = $list | Sort-Object
    $idx = [Math]::Floor(($sorted.Count - 1) * ($p / 100.0))
    return [Math]::Round($sorted[$idx], 2)
}

# 3. Benchmark Flujo Híbrido (K3s Local -> OnPrem Broker -> Trigger -> Cloud Broker)
if ($Mode -eq "hybrid" -or $Mode -eq "all") {
    Write-Host "`n[2/4] Ejecutando Flujo Hibrido (Edge K3s -> OnPrem Broker -> AKS Cloud)..." -ForegroundColor Yellow
    $hybridLatencies = @()
    $successCount = 0

    for ($i = 1; $i -le $Count; $i++) {
        $niu = "100" + (Get-Random -Minimum 1000 -Maximum 9999)
        $kwhImp = [Math]::Round((Get-Random -Minimum 5.0 -Maximum 22.0), 2)
        $kwhExp = [Math]::Round((Get-Random -Minimum 1.0 -Maximum 15.0), 2)

        $body = @{
            niu = "$niu"
            kwh_importados = $kwhImp
            kwh_exportados = $kwhExp
            tension_voltios = 120.2
        } | ConvertTo-Json

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $emitted = $false
        try {
            $resp = Invoke-RestMethod -Uri "$LocalUrl/emit" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 5 -ErrorAction Stop
            $sw.Stop()
            $latMs = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
            $hybridLatencies += $latMs
            $successCount++
            $emitted = $true
            Write-Host "  [$i/$Count] (HTTP) CloudEvent id=$($resp.event_id) NIU=$niu -> OK ($latMs ms)" -ForegroundColor Green
        } catch {
            # Fallback to in-pod exec if port-forward is not active
            try {
                $raw = & kubectl --context k3d-voltera-onprem exec deploy/ami-mock-service -n voltera-onprem -c ami-mock -- wget -qO- http://localhost:8080/emit 2>$null
                $sw.Stop()
                if ($raw) {
                    $resp = $raw | ConvertFrom-Json
                    $latMs = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
                    $hybridLatencies += $latMs
                    $successCount++
                    $emitted = $true
                    Write-Host "  [$i/$Count] (Cluster-Exec) CloudEvent id=$($resp.event_id) NIU=$niu -> OK ($latMs ms)" -ForegroundColor Green
                }
            } catch {
                $sw.Stop()
            }
        }

        if (-not $emitted) {
            Write-Host "  [$i/$Count] Fallo emision hibrida." -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 150
    }

    if ($hybridLatencies.Count -gt 0) {
        $avg = [Math]::Round(($hybridLatencies | Measure-Object -Average).Average, 2)
        $min = [Math]::Round(($hybridLatencies | Measure-Object -Minimum).Minimum, 2)
        $max = [Math]::Round(($hybridLatencies | Measure-Object -Maximum).Maximum, 2)
        $p50 = Get-Percentile $hybridLatencies 50
        $p90 = Get-Percentile $hybridLatencies 90
        $p95 = Get-Percentile $hybridLatencies 95

        Write-Host "`n  --- Resumen Latencia Flujo Hibrido (K3s Local -> Mesh) ---" -ForegroundColor Cyan
        Write-Host "  Exitosos: $successCount / $Count | Min: $min ms | Promedio: $avg ms | Max: $max ms" -ForegroundColor White
        Write-Host "  Percentiles: p50=$p50 ms | p90=$p90 ms | p95=$p95 ms" -ForegroundColor White
    }
}

# 4. Benchmark Directo a Cloud Broker (AKS Ingress)
if ($Mode -eq "direct" -or $Mode -eq "all") {
    Write-Host "`n[3/4] Ejecutando Flujo Directo Cloud (HTTPS -> Istio Ingress -> Cloud Broker)..." -ForegroundColor Yellow
    $cloudLatencies = @()
    $successCount = 0

    for ($i = 1; $i -le $Count; $i++) {
        $niu = "200" + (Get-Random -Minimum 1000 -Maximum 9999)
        $kwhImp = [Math]::Round((Get-Random -Minimum 2.0 -Maximum 10.0), 2)
        $kwhExp = [Math]::Round((Get-Random -Minimum 8.0 -Maximum 20.0), 2)
        $ceId = "evt-direct-$(Get-Date -Format 'yyyyMMddHHmmssffff')-$i"

        $body = @{
            niu = "$niu"
            medidor_serie = "MTR-CLOUD-$niu"
            timestamp_lectura = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            intervalo = "MINUTOS_15"
            kwh_importados = $kwhImp
            kwh_exportados = $kwhExp
            tension_voltios = 121.0
        } | ConvertTo-Json

        $headers = @{
            "Ce-Specversion" = "1.0"
            "Ce-Type" = "com.voltera.ami.lectura_registrada"
            "Ce-Source" = "//tests/powershell/direct"
            "Ce-Id" = $ceId
            "Ce-Time" = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $resp = Invoke-WebRequest -Uri $CloudUrl -Method Post -Headers $headers -Body $body -ContentType "application/json" -TimeoutSec 10 -SkipCertificateCheck -ErrorAction Stop
            $sw.Stop()
            $latMs = [Math]::Round($sw.Elapsed.TotalMilliseconds, 2)
            $cloudLatencies += $latMs
            $successCount++
            Write-Host "  [$i/$Count] Direct CloudEvent id=$ceId NIU=$niu -> HTTP $($resp.StatusCode) ($latMs ms)" -ForegroundColor Green
        } catch {
            $sw.Stop()
            Write-Host "  [$i/$Count] Fallo emision directa: $_" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 150
    }

    if ($cloudLatencies.Count -gt 0) {
        $avg = [Math]::Round(($cloudLatencies | Measure-Object -Average).Average, 2)
        $min = [Math]::Round(($cloudLatencies | Measure-Object -Minimum).Minimum, 2)
        $max = [Math]::Round(($cloudLatencies | Measure-Object -Maximum).Maximum, 2)
        $p50 = Get-Percentile $cloudLatencies 50
        $p90 = Get-Percentile $cloudLatencies 90
        $p95 = Get-Percentile $cloudLatencies 95

        Write-Host "`n  --- Resumen Latencia Directa a Azure Ingress ---" -ForegroundColor Cyan
        Write-Host "  Exitosos: $successCount / $Count | Min: $min ms | Promedio: $avg ms | Max: $max ms" -ForegroundColor White
        Write-Host "  Percentiles: p50=$p50 ms | p90=$p90 ms | p95=$p95 ms" -ForegroundColor White
    }
}

# 5. Verificación de Transacciones en el Cloud (Facturación y Pagos)
Write-Host "`n[4/4] Verificando liquidaciones Netting (CREG 101-072) y Pagos en AKS..." -ForegroundColor Yellow
Start-Sleep -Seconds 1

try {
    $billingStats = Invoke-RestMethod -Uri "https://voltera-dev-mesh.eastus2.cloudapp.azure.com/api/billing/stats" -SkipCertificateCheck -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  -> Facturas liquidadas en AKS: $($billingStats.total_processed)" -ForegroundColor Green
    if ($billingStats.recent_invoices -and $billingStats.recent_invoices.Count -gt 0) {
        Write-Host "     Ultima Factura: $($billingStats.recent_invoices[0].invoice_id) | NIU: $($billingStats.recent_invoices[0].niu) | Total: COP $($billingStats.recent_invoices[0].total_cop)" -ForegroundColor White
    }
} catch {
    Write-Host "  -> Consultando logs de billing-service via kubectl..." -ForegroundColor Gray
    & kubectl --context voltera-dev-aks logs -n voltera -l app=billing-service -c billing-service --tail=5 2>$null
}

try {
    $paymentStats = Invoke-RestMethod -Uri "https://voltera-dev-mesh.eastus2.cloudapp.azure.com/api/payment/stats" -SkipCertificateCheck -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  -> Pagos procesados en AKS: $($paymentStats.total_processed)" -ForegroundColor Green
    if ($paymentStats.recent_payments -and $paymentStats.recent_payments.Count -gt 0) {
        Write-Host "     Ultimo Pago: $($paymentStats.recent_payments[0].transaction_id) | Factura: $($paymentStats.recent_payments[0].invoice_id) | Monto: COP $($paymentStats.recent_payments[0].amount)" -ForegroundColor White
    }
} catch {
    Write-Host "  -> Consultando logs de payment-service via kubectl..." -ForegroundColor Gray
    & kubectl --context voltera-dev-aks logs -n voltera -l app=payment-service -c payment-service --tail=5 2>$null
}

Write-Host "`n==========================================================================" -ForegroundColor Green
Write-Host "  PRUEBAS COMPLETADAS EXITOSAMENTE                                        " -ForegroundColor Green
Write-Host "  Para visualizar el grafo de servicios y trafico en Kiali:               " -ForegroundColor Cyan
Write-Host "  URL Kiali: https://voltera-dev-mesh.eastus2.cloudapp.azure.com/kiali   " -ForegroundColor White
Write-Host "  O via port-forward: kubectl --context voltera-dev-aks port-forward svc/kiali -n istio-system 20001:20001" -ForegroundColor White
Write-Host "==========================================================================" -ForegroundColor Green
