param(
    [int]$TimeoutSeconds = 240,
    [int]$SampleSeconds = 2
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$jobYaml = Join-Path $root "k8s\base\ami-job.yaml"
if (-not (Test-Path $jobYaml)) {
    Write-Host "No se encontró: $jobYaml" -ForegroundColor Red
    exit 1
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$out = Join-Path $PSScriptRoot "keda-experiment-$stamp.csv"

kubectl delete job ami-load-test -n voltera --ignore-not-found | Out-Null
Start-Sleep -Seconds 2

$initial = kubectl get deployment metering-service -n voltera -o jsonpath='{.status.availableReplicas}' 2>$null
if ([string]::IsNullOrWhiteSpace($initial)) { $initial = 0 }
Write-Host "Réplicas iniciales: $initial"

$t0 = Get-Date
kubectl apply -f $jobYaml | Out-Host
Write-Host "T0 carga AMI: $($t0.ToString('HH:mm:ss.fff'))" -ForegroundColor Green

$rows = New-Object System.Collections.Generic.List[object]
$firstScale = $null
$lagZero = $null
$backToZero = $null
$maxReplicas = 0
$hadScale = $false

while (((Get-Date) - $t0).TotalSeconds -lt $TimeoutSeconds) {
    $now = Get-Date
    $elapsed = [math]::Round(($now - $t0).TotalSeconds, 1)

    $rep = kubectl get deployment metering-service -n voltera -o jsonpath='{.status.availableReplicas}' 2>$null
    if ([string]::IsNullOrWhiteSpace($rep)) { $rep = 0 }
    $rep = [int]$rep

    if ($rep -gt $maxReplicas) { $maxReplicas = $rep }
    if ($rep -gt 0 -and -not $hadScale) {
        $hadScale = $true
        $firstScale = $now
        Write-Host "Primer pod disponible a +$elapsed s" -ForegroundColor Cyan
    }

    $desired = kubectl get hpa keda-hpa-metering-service-scaler -n voltera -o jsonpath='{.status.desiredReplicas}' 2>$null
    if ([string]::IsNullOrWhiteSpace($desired)) { $desired = 0 }

    $active = kubectl get scaledobject metering-service-scaler -n voltera -o jsonpath='{.status.conditions[?(@.type=="Active")].status}' 2>$null
    if ([string]::IsNullOrWhiteSpace($active)) { $active = "Unknown" }

    $lag = $null
    $cg = kubectl exec -n voltera deployment/kafka -- /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server kafka:9092 --describe --group metering-service 2>$null
    $lags = @()
    foreach ($line in $cg) {
        if ($line -match '^metering-service\s+') {
            $parts = ($line -split '\s+') | Where-Object { $_ -ne "" }
            if ($parts.Count -ge 6 -and $parts[5] -match '^\d+$') {
                $lags += [int64]$parts[5]
            }
        }
    }

    if ($lags.Count -gt 0) {
        $lag = ($lags | Measure-Object -Sum).Sum
        if ($hadScale -and $lag -eq 0 -and $null -eq $lagZero) {
            $lagZero = $now
            Write-Host "Lag llegó a 0 a +$elapsed s" -ForegroundColor Green
        }
    }

    $job = kubectl get job ami-load-test -n voltera -o jsonpath='{.status.succeeded}' 2>$null
    if ([string]::IsNullOrWhiteSpace($job)) { $job = 0 }

    $rows.Add([pscustomobject]@{
        timestamp = $now.ToString("o")
        elapsed_s = $elapsed
        available_replicas = $rep
        desired_replicas = [int]$desired
        keda_active = $active
        consumer_lag = if ($null -eq $lag) { "" } else { $lag }
        ami_job_succeeded = [int]$job
    })

    Write-Host ("+{0,6}s | pods={1} desired={2} | KEDA={3} | lag={4}" -f $elapsed,$rep,$desired,$active,($(if($null -eq $lag){"NA"}else{$lag})))

    if ($hadScale -and $null -ne $lagZero -and $rep -eq 0) {
        $backToZero = $now
        break
    }

    Start-Sleep -Seconds $SampleSeconds
}

$rows | Export-Csv -Path $out -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "=== RESULTADO ===" -ForegroundColor Cyan
Write-Host "Máximo de réplicas: $maxReplicas"
if ($null -ne $firstScale) {
    $t = [math]::Round(($firstScale - $t0).TotalSeconds, 1)
    Write-Host "Tiempo a primera réplica: $t s"
    Write-Host "Criterio <= 60 s: $(if($t -le 60){'CUMPLE'}else{'NO CUMPLE'})"
}
if ($null -ne $lagZero) {
    Write-Host "Tiempo hasta lag=0: $([math]::Round(($lagZero-$t0).TotalSeconds,1)) s"
}
if ($null -ne $backToZero) {
    Write-Host "Tiempo hasta volver a 0: $([math]::Round(($backToZero-$t0).TotalSeconds,1)) s"
} else {
    Write-Host "No se observó regreso a 0 dentro del timeout."
}
Write-Host "CSV: $out"
