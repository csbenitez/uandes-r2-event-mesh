<#
.SYNOPSIS
    Despliega y configura la observabilidad de Azure Application Insights para el Event Mesh de Voltera en AKS.
.DESCRIPTION
    1. Obtiene o recibe la cadena de conexión de Application Insights.
    2. Crea el Secret appinsights-secret en istio-system.
    3. Configura Istio meshConfig para registrar el tracer Zipkin hacia otel-collector.
    4. Aplica el Deployment del OpenTelemetry Collector y el config-tracing de Knative Eventing.
    5. Actualiza los microservicios billing-service y payment-service con propagación W3C.
.PARAMETER ConnectionString
    Opcional. Cadena de conexión de Azure Application Insights. Si se omite, se lee de Terraform.
.PARAMETER Context
    Contexto de kubectl (por defecto "voltera-dev-aks").
#>

[CmdletBinding()]
param(
    [string]$ConnectionString = "",
    [string]$Context = "voltera-dev-aks"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path "$PSScriptRoot\..\.."
$tfDevDir = "$repoRoot\infra\azure-terraform\environments\dev"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Despliegue de Observabilidad FinOps: Application Insights" -ForegroundColor Cyan
Write-Host "  Contexto Kubernetes: $Context                            " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Obtener Connection String si no se suministró
if (-not $ConnectionString) {
    Write-Host "[1/6] Obteniendo Connection String desde Terraform outputs..." -ForegroundColor Yellow
    if (Test-Path $tfDevDir) {
        Push-Location $tfDevDir
        try {
            $ConnectionString = (terraform output -raw app_insights_connection_string 2>$null).Trim()
        } finally {
            Pop-Location
        }
    }
}

if (-not $ConnectionString -or $ConnectionString -notmatch "InstrumentationKey=") {
    Write-Error "No se pudo obtener una cadena de conexión válida de Application Insights. Proporciónala con -ConnectionString."
}

Write-Host "  -> Connection String obtenido correctamente (Key: $(($ConnectionString -split ';')[0]))." -ForegroundColor Green

# 2. Configurar Secret en istio-system
Write-Host "`n[2/6] Creando/Actualizando Secret 'appinsights-secret' en istio-system..." -ForegroundColor Yellow
$secretYaml = kubectl --context $Context create secret generic appinsights-secret `
    -n istio-system `
    --from-literal=connection-string="$ConnectionString" `
    --dry-run=client -o yaml

$secretYaml | kubectl --context $Context apply -f -
if ($LASTEXITCODE -ne 0) { Write-Error "Error creando secret en istio-system." }
Write-Host "  -> Secret appinsights-secret configurado exitosamente." -ForegroundColor Green

# 3. Parchear ConfigMap de Istio para habilitar Zipkin extension provider
Write-Host "`n[3/6] Configurando proveedores de trazas en Istio meshConfig..." -ForegroundColor Yellow

$currentMesh = kubectl --context $Context get configmap istio -n istio-system -o jsonpath="{.data.mesh}"
if ($currentMesh -notmatch "zipkin-collector") {
    $meshPatch = @'
data:
  mesh: |-
    defaultConfig:
      discoveryAddress: istiod.istio-system.svc:15012
      tracing:
        zipkin:
          address: otel-collector.istio-system.svc.cluster.local:9411
        sampling: 100.0
    defaultProviders:
      metrics:
      - prometheus
    extensionProviders:
    - name: "zipkin-collector"
      zipkin:
        service: "otel-collector.istio-system.svc.cluster.local"
        port: 9411
        maxPathLength: 256
    enablePrometheusMerge: true
    rootNamespace: istio-system
    trustDomain: cluster.local
'@
    $tempFile = New-TemporaryFile
    $meshPatch | Out-File -FilePath $tempFile.FullName -Encoding utf8
    kubectl --context $Context patch configmap istio -n istio-system --type merge --patch-file $tempFile.FullName
    Remove-Item $tempFile.FullName
    Write-Host "  -> ConfigMap de Istio actualizado con provider 'zipkin-collector'." -ForegroundColor Green
} else {
    Write-Host "  -> Provider 'zipkin-collector' ya configurado en Istio." -ForegroundColor Gray
}

# 4. Desplegar OpenTelemetry Collector y Knative config-tracing
Write-Host "`n[4/6] Aplicando manifests de OpenTelemetry Collector y Knative Eventing Tracing..." -ForegroundColor Yellow
$otelManifest = "$PSScriptRoot\otel-collector.yaml"
kubectl --context $Context apply -f $otelManifest
if ($LASTEXITCODE -ne 0) { Write-Error "Error aplicando otel-collector.yaml." }
Write-Host "  -> Recursos de OpenTelemetry Collector y Knative Tracing aplicados." -ForegroundColor Green

# 5. Aplicar microservicios instrumentados en namespace voltera
Write-Host "`n[5/6] Aplicando microservicios de facturación y pagos instrumentados..." -ForegroundColor Yellow
$billingManifest = "$repoRoot\k8s\billing.yaml"
$paymentManifest = "$repoRoot\k8s\payment.yaml"

kubectl --context $Context apply -f $billingManifest
kubectl --context $Context apply -f $paymentManifest

# 6. Reiniciar pods para aplicar configuración de trazas
Write-Host "`n[6/6] Reiniciando componentes para cargar trazas distribuidas..." -ForegroundColor Yellow
kubectl --context $Context rollout restart deployment/mt-broker-ingress -n knative-eventing 2>$null
kubectl --context $Context rollout restart deployment/mt-broker-filter -n knative-eventing 2>$null
kubectl --context $Context rollout restart deployment/imc-dispatcher -n knative-eventing 2>$null
kubectl --context $Context rollout restart deployment/billing-service -n voltera
kubectl --context $Context rollout restart deployment/payment-service -n voltera

Write-Host "Esperando a que otel-collector esté en estado Running..." -ForegroundColor Gray
kubectl --context $Context rollout status deployment/otel-collector -n istio-system --timeout=60s

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  ¡Observabilidad de Application Insights configurada!    " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Para verificar en vivo los spans recibidos ejecuta:" -ForegroundColor Cyan
Write-Host "  kubectl --context $Context logs -n istio-system -l app=otel-collector -f --tail=30" -ForegroundColor White
Write-Host "Para enviar eventos de prueba ejecuta:" -ForegroundColor Cyan
Write-Host "  k6 run tests/01_smoke_test.js -e TARGET_URL='https://voltera-dev-mesh.eastus2.cloudapp.azure.com/events' -e COUNT=3" -ForegroundColor White
