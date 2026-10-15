<#
.SYNOPSIS
    Control manual rápido para encender o apagar el clúster AKS y consultar su estado FinOps.
.PARAMETER Action
    start, stop o status
#>
[CmdletBinding()]
param(
    [ValidateSet("start", "stop", "status")]
    [string]$Action = "status",

    [string]$ResourceGroup = "rg-voltera-dev",
    [string]$ClusterName = "voltera-dev-aks"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  FinOps Power Control: AKS ($ClusterName)               " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

switch ($Action) {
    "status" {
        Write-Host "Consultando estado actual de cómputo de AKS..." -ForegroundColor Yellow
        $stateJson = az aks show --resource-group $ResourceGroup --name $ClusterName --query "{powerState:powerState.code, provisioningState:provisioningState}" -o json 2>$null
        if ($LASTEXITCODE -eq 0 -and $stateJson) {
            $state = $stateJson | ConvertFrom-Json
            Write-Host "  -> Power State: $($state.powerState)" -ForegroundColor Green
            Write-Host "  -> Provisioning State: $($state.provisioningState)" -ForegroundColor Gray
            if ($state.powerState -eq "Stopped") {
                Write-Host "  [FinOps] El clúster está DETENIDO. Facturación de cómputo en $0." -ForegroundColor Cyan
            } else {
                Write-Host "  [FinOps] El clúster está CORRIENDO. Recuerda apagarlo al terminar el laboratorio." -ForegroundColor Yellow
            }
        } else {
            Write-Warning "No se pudo obtener el estado. Verifica que el clúster exista y estés autenticado en az cli."
        }
    }
    "stop" {
        Write-Host "Enviando orden de APAGADO (az aks stop) a $ClusterName..." -ForegroundColor Red
        az aks stop --resource-group $ResourceGroup --name $ClusterName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "¡Clúster AKS detenido exitosamente! El costo de cómputo ahora es $0." -ForegroundColor Green
        }
    }
    "start" {
        Write-Host "Enviando orden de ENCENDIDO (az aks start) a $ClusterName..." -ForegroundColor Green
        az aks start --resource-group $ResourceGroup --name $ClusterName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "¡Clúster AKS iniciado exitosamente! Ya puedes interactuar con kubectl." -ForegroundColor Green
        }
    }
}
