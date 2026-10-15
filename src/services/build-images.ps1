<#
.SYNOPSIS
    Compila las imagenes de Docker para los microservicios de Voltera.
.PARAMETER Registry
    Prefijo de registro o namespace (por defecto: "voltera").
.PARAMETER Tag
    Tag de imagen a generar (por defecto: "latest").
.PARAMETER IncludeMock
    Si se especifica, compila tambien la imagen de mock-onprem.
#>
[CmdletBinding()]
param(
    [string]$Registry = "voltera",
    [string]$Tag = "latest",
    [switch]$IncludeMock
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Compilador de Contenedores de Servicios Voltera         " -ForegroundColor Cyan
Write-Host "  Registry: $Registry | Tag: $Tag                        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verificar Docker
try {
    & docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Docker daemon no esta respondiendo." }
    Write-Host "[OK] Docker daemon activo." -ForegroundColor Green
} catch {
    Write-Error "Docker debe estar en ejecucion para compilar las imagenes."
}

$servicesRoot = $PSScriptRoot
$projectRoot = Resolve-Path "$servicesRoot\..\.."

# 2. Billing Service
Write-Host "`n[1/2] Compilando billing-service..." -ForegroundColor Yellow
$billingTag = "$Registry/billing-service:$Tag"
& docker build -t $billingTag "$servicesRoot\billing-service"
if ($LASTEXITCODE -ne 0) { Write-Error "Fallo compilando $billingTag" }
Write-Host "  -> Imagen creada: $billingTag" -ForegroundColor Green

# 3. Payment Service
Write-Host "`n[2/2] Compilando payment-service..." -ForegroundColor Yellow
$paymentTag = "$Registry/payment-service:$Tag"
& docker build -t $paymentTag "$servicesRoot\payment-service"
if ($LASTEXITCODE -ne 0) { Write-Error "Fallo compilando $paymentTag" }
Write-Host "  -> Imagen creada: $paymentTag" -ForegroundColor Green

# 4. Mock OnPrem (opcional)
if ($IncludeMock) {
    Write-Host "`n[3/3] Compilando mock-onprem (ami-mock)..." -ForegroundColor Yellow
    $mockTag = "$Registry/ami-mock:$Tag"
    & docker build -t $mockTag "$projectRoot\mock-onprem"
    if ($LASTEXITCODE -ne 0) { Write-Error "Fallo compilando $mockTag" }
    Write-Host "  -> Imagen creada: $mockTag" -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  Todas las imagenes se compilaron exitosamente.          " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
