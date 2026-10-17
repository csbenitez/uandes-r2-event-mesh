<#
.SYNOPSIS
    Instala la capa de Add-ons (Istio, Knative Serving + net-istio, Knative Eventing, KEDA).
.DESCRIPTION
    Esta capa es 100% cloud-agnostic: soporta tanto la región local (K3s con NodePort/ServiceLB)
    como la región Cloud (Azure AKS con LoadBalancer público).
.PARAMETER Target
    "local" para clúster K3s On-Premise, "azure" para AKS, o "custom".
.PARAMETER KubeconfigPath
    Ruta opcional al archivo kubeconfig específico.
.PARAMETER PublicIp
    IP pública o DNS para configurar el dominio sslip.io de Knative.
#>

[CmdletBinding()]
param(
    [ValidateSet("local", "azure", "custom")]
    [string]$Target = "local",

    [string]$KubeconfigPath = "",
    [string]$PublicIp = ""
)

$ErrorActionPreference = "Stop"

# Asegurar herramientas de winget en PATH
$wingetPath = "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
if ((Test-Path $wingetPath) -and ($env:Path -notlike "*$wingetPath*")) {
    $env:Path = "$wingetPath;$env:Path"
}

# Cargar versiones fijadas desde versions.env si existe
$versionsFile = "$PSScriptRoot\versions.env"
$istioVersion = "1.24.2"
$knativeVersion = "v1.16.0"
$kedaVersion = "2.16.0"

if (Test-Path $versionsFile) {
    Get-Content $versionsFile | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z0-9_]+)\s*=\s*["'']?([^"'']+)["'']?') {
            $key = $matches[1]
            $val = $matches[2]
            if ($key -eq "ISTIO_VERSION") { $istioVersion = $val }
            if ($key -eq "KNATIVE_VERSION") { $knativeVersion = $val }
            if ($key -eq "KEDA_VERSION") { $kedaVersion = $val }
        }
    }
}

# Normalizar prefijo de versión de Knative (v1.16.0)
$knativeTag = $knativeVersion
if (-not $knativeTag.StartsWith("v")) {
    $knativeTag = "v$knativeTag"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Instalador de Add-ons: Istio + Knative + KEDA           " -ForegroundColor Cyan
Write-Host "  Target: $Target                                         " -ForegroundColor Cyan
Write-Host "  Versiones: Istio $istioVersion | Knative $knativeTag | KEDA $kedaVersion" -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Configurar Kubeconfig
if ($KubeconfigPath -and (Test-Path $KubeconfigPath)) {
    $env:KUBECONFIG = (Resolve-Path $KubeconfigPath).Path
    Write-Host "[1/6] Usando kubeconfig específico: $env:KUBECONFIG" -ForegroundColor Green
} else {
    Write-Host "[1/6] Usando contexto activo actual de kubectl..." -ForegroundColor Green
}

& kubectl cluster-info | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "No se puede conectar al cluster de Kubernetes. Revisa que esté encendido."
}

# 2. Determinar configuración de red y dominio
$istioValuesFile = "$PSScriptRoot\istio\values.yaml"
if ($Target -eq "azure") {
    $istioValuesFile = "$PSScriptRoot\istio\aks-values.yaml"
    Write-Host "  -> Usando configuración de Azure LoadBalancer para Istio Ingress." -ForegroundColor Gray
} else {
    Write-Host "  -> Usando configuración Local/K3s para Istio Ingress." -ForegroundColor Gray
}

if (-not $PublicIp) {
    if ($Target -eq "local") {
        $PublicIp = "127.0.0.1"
    } else {
        $PublicIp = "azure.cloud"
    }
}

$knativeDomain = if ($PublicIp -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") { "$PublicIp.sslip.io" } else { "example.com" }
Write-Host "  -> Dominio configurado para Knative: $knativeDomain" -ForegroundColor Green

# 3. Instalar Istio
Write-Host "`n[2/6] Instalando Istio ($istioVersion)..." -ForegroundColor Yellow
& helm repo add istio https://istio-release.storage.googleapis.com/charts 2>$null
& helm repo update istio | Out-Null

Write-Host "  -> Instalando istio-base..." -ForegroundColor Gray
& helm upgrade --install istio-base istio/base -n istio-system --create-namespace --version $istioVersion
Write-Host "  -> Instalando istiod (Control Plane)..." -ForegroundColor Gray
& helm upgrade --install istiod istio/istiod -n istio-system --version $istioVersion --wait
Write-Host "  -> Instalando Ingress Gateway ($Target)..." -ForegroundColor Gray
& helm upgrade --install istio-ingress istio/gateway -n istio-system -f $istioValuesFile --version $istioVersion --wait

# 4. Instalar Knative Serving + net-istio
Write-Host "`n[3/6] Instalando Knative Serving ($knativeTag)..." -ForegroundColor Yellow
Write-Host "  -> Aplicando CRDs..." -ForegroundColor Gray
& kubectl apply -f "https://github.com/knative/serving/releases/download/knative-$knativeTag/serving-crds.yaml"
Write-Host "  -> Aplicando Core..." -ForegroundColor Gray
& kubectl apply -f "https://github.com/knative/serving/releases/download/knative-$knativeTag/serving-core.yaml"
Write-Host "  -> Instalando controlador net-istio..." -ForegroundColor Gray
& kubectl apply -f "https://github.com/knative-extensions/net-istio/releases/download/knative-$knativeTag/net-istio.yaml"

Write-Host "  -> Configurando red y dominio de Knative..." -ForegroundColor Gray
& kubectl apply -f "$PSScriptRoot\knative\serving-config.yaml"
& kubectl patch configmap/config-domain --namespace knative-serving --type merge --patch "{`"data`":{`"$knativeDomain`":`"`"}}"

# 5. Instalar Knative Eventing + InMemoryChannel + Broker
Write-Host "`n[4/6] Instalando Knative Eventing ($knativeTag)..." -ForegroundColor Yellow
Write-Host "  -> Aplicando Eventing CRDs..." -ForegroundColor Gray
& kubectl apply -f "https://github.com/knative/eventing/releases/download/knative-$knativeTag/eventing-crds.yaml"
Write-Host "  -> Aplicando Eventing Core..." -ForegroundColor Gray
& kubectl apply -f "https://github.com/knative/eventing/releases/download/knative-$knativeTag/eventing-core.yaml"
Write-Host "  -> Instalando canal InMemory..." -ForegroundColor Gray
& kubectl apply -f "https://github.com/knative/eventing/releases/download/knative-$knativeTag/in-memory-channel.yaml"
Write-Host "  -> Instalando Multi-Tenant Channel Broker..." -ForegroundColor Gray
& kubectl apply -f "https://github.com/knative/eventing/releases/download/knative-$knativeTag/mt-channel-broker.yaml"

Write-Host "  -> Configurando Broker por defecto..." -ForegroundColor Gray
& kubectl apply -f "$PSScriptRoot\knative\eventing-broker.yaml"

Write-Host "  -> Inyectando sidecars de Istio en Knative Data Plane (ingress, filter, dispatcher)..." -ForegroundColor Gray
$sidecarPatch = "$PSScriptRoot\knative\patch-dataplane-sidecar.yaml"
& kubectl patch deployment mt-broker-ingress -n knative-eventing --patch-file $sidecarPatch
& kubectl patch deployment mt-broker-filter -n knative-eventing --patch-file $sidecarPatch
& kubectl patch deployment imc-dispatcher -n knative-eventing --patch-file $sidecarPatch

# 6. Instalar KEDA
Write-Host "`n[5/6] Instalando KEDA ($kedaVersion)..." -ForegroundColor Yellow
& helm repo add kedacore https://kedacore.github.io/charts 2>$null
& helm repo update kedacore | Out-Null
& helm upgrade --install keda kedacore/keda -n keda --create-namespace -f "$PSScriptRoot\keda\values.yaml" --version $kedaVersion --wait

Write-Host "`n[6/6] Verificando estado de componentes..." -ForegroundColor Green
& kubectl get pods -n istio-system
& kubectl get pods -n knative-serving
& kubectl get pods -n knative-eventing
& kubectl get pods -n keda

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  ¡Plataforma instalada exitosamente en $Target!          " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
