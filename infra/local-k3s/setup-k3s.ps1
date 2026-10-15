<#
.SYNOPSIS
    Aprovisiona o inicia el clúster local K3s con k3d en Docker para simular la región On-Premise.
#>
[CmdletBinding()]
param(
    [string]$ClusterName = "voltera-onprem",
    [int]$HttpPort = 8090,
    [int]$HttpsPort = 8443,
    [int]$ApiPort = 6550
)

$ErrorActionPreference = "Stop"

# Asegurar que herramientas instaladas con winget estén en PATH
$wingetPath = "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
if ((Test-Path $wingetPath) -and ($env:Path -notlike "*$wingetPath*")) {
    $env:Path = "$wingetPath;$env:Path"
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Setup Región On-Premise: K3s Local ($ClusterName)      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verificar Docker
try {
    & docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Docker no está corriendo." }
    Write-Host "[1/4] Docker Desktop verificado y activo." -ForegroundColor Green
} catch {
    Write-Error "Docker Desktop debe estar en ejecución antes de crear el clúster K3s."
}

# 2. Verificar k3d
if (-not (Get-Command k3d -ErrorAction SilentlyContinue)) {
    Write-Error "k3d no se encuentra en el PATH. Instálalo con 'winget install k3d.k3d'."
}
Write-Host "[2/4] Binario k3d disponible." -ForegroundColor Green

# 3. Comprobar si el clúster ya existe
$existingClusters = & k3d cluster list -o json 2>$null | ConvertFrom-Json
$clusterExists = $false
$clusterRunning = $false

if ($existingClusters) {
    foreach ($c in $existingClusters) {
        if ($c.name -eq $ClusterName) {
            $clusterExists = $true
            if ($c.serversRunning -gt 0) {
                $clusterRunning = $true
            }
            break
        }
    }
}

if ($clusterRunning) {
    Write-Host "[3/4] El clúster '$ClusterName' ya existe y está activo." -ForegroundColor Green
} elseif ($clusterExists) {
    Write-Host "[3/4] Iniciando clúster '$ClusterName' detenido..." -ForegroundColor Yellow
    & k3d cluster start $ClusterName
} else {
    Write-Host "[3/4] Creando nuevo clúster k3d '$ClusterName'..." -ForegroundColor Yellow
    Write-Host "      - Traefik deshabilitado (Istio Ingress tomará el control de puertos)" -ForegroundColor Gray
    Write-Host "      - Mapeo de puertos: $HttpPort -> 80 (HTTP), $HttpsPort -> 443 (HTTPS), API -> $ApiPort" -ForegroundColor Gray

    & k3d cluster create $ClusterName `
        --api-port $ApiPort `
        -p "${HttpPort}:80@loadbalancer" `
        -p "${HttpsPort}:443@loadbalancer" `
        --k3s-arg "--disable=traefik@server:0" `
        --wait

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Fallo al crear el clúster k3d."
    }
}

# 4. Configurar contexto de kubectl
Write-Host "[4/4] Cambiando contexto de kubectl a 'k3d-$ClusterName'..." -ForegroundColor Green
& kubectl config use-context "k3d-$ClusterName"
& kubectl cluster-info

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  ¡Clúster On-Premise K3s listo y activo!                " -ForegroundColor Green
Write-Host "  Siguiente paso: instalar la capa de Add-ons (Istio + Knative):" -ForegroundColor Cyan
Write-Host "    pwsh $PSScriptRoot\..\addons\install.ps1 -PublicIp 127.0.0.1" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
