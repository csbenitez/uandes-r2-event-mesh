<#
.SYNOPSIS
    Punto de entrada unificado para la gestión y ciclo de vida de la infraestructura de Voltera.
.DESCRIPTION
    Simplifica la interacción con los entornos Cloud (Azure AKS) y Edge (K3s Local),
    así como la instalación de la capa común de Add-ons (Istio, Knative, KEDA).
.EXAMPLE
    # Iniciar clúster local K3s
    .\infra\manage.ps1 local start

    # Instalar Add-ons en el clúster local
    .\infra\manage.ps1 local addons

    # Consultar estado FinOps de Azure AKS
    .\infra\manage.ps1 azure status

    # Encender / Apagar clúster AKS en Azure
    .\infra\manage.ps1 azure start
    .\infra\manage.ps1 azure stop

    # Conectar kubectl al clúster de Azure
    .\infra\manage.ps1 azure connect
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("local", "azure", "addons", "help")]
    [string]$Target = "help",

    [Parameter(Position = 1)]
    [string]$Action = "status",

    [string]$ResourceGroup = "rg-voltera-dev",
    [string]$ClusterName = "voltera-dev-aks",
    [string]$PublicIp = ""
)

$ErrorActionPreference = "Stop"

function Show-Help {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  VOLTERA INFRASTRUCTURE MANAGER (CLI Unificado)                 " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Uso: .\infra\manage.ps1 <Target> <Action> [Opciones]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🎯 Entornos (Target):" -ForegroundColor Green
    Write-Host "  local       Gestiona el clúster local K3s (k3d en Docker Desktop)"
    Write-Host "  azure       Gestiona el clúster Azure AKS, Terraform y FinOps"
    Write-Host "  addons      Gestiona el stack de addons (Istio, Knative, KEDA)"
    Write-Host ""
    Write-Host "⚡ Acciones para 'local':" -ForegroundColor Green
    Write-Host "  start       Inicia o aprovisiona el clúster k3d (setup-k3s.ps1)"
    Write-Host "  stop        Pausa el clúster para liberar CPU/RAM (teardown-k3s.ps1)"
    Write-Host "  delete      Elimina el clúster k3d completamente"
    Write-Host "  status      Muestra el estado de contenedores y nodos k3s"
    Write-Host "  addons      Instala Istio, Knative y KEDA en el clúster local"
    Write-Host ""
    Write-Host "⚡ Acciones para 'azure':" -ForegroundColor Green
    Write-Host "  status      Consulta el PowerState (Running/Stopped) de AKS"
    Write-Host "  start       Enciende las VMs de AKS para reanudar desarrollo"
    Write-Host "  stop        Suspende el cómputo de AKS (Costo en $0 USD)"
    Write-Host "  connect     Descarga credenciales a kubectl (az aks get-credentials)"
    Write-Host "  plan        Ejecuta terraform plan en environments/dev"
    Write-Host "  apply       Ejecuta terraform apply en environments/dev"
    Write-Host "  addons      Instala Istio, Knative y KEDA en Azure AKS"
    Write-Host ""
    Write-Host "💡 Ejemplos Rápidos:" -ForegroundColor Cyan
    Write-Host "  pwsh .\infra\manage.ps1 local start"
    Write-Host "  pwsh .\infra\manage.ps1 local addons"
    Write-Host "  pwsh .\infra\manage.ps1 azure status"
    Write-Host "  pwsh .\infra\manage.ps1 azure stop"
    Write-Host "=================================================================" -ForegroundColor Cyan
}

if ($Target -eq "help" -or -not $Target) {
    Show-Help
    exit 0
}

$infraRoot = $PSScriptRoot

switch ($Target) {
    "local" {
        switch ($Action.ToLower()) {
            "start" {
                & "$infraRoot\local-k3s\setup-k3s.ps1"
            }
            "stop" {
                & "$infraRoot\local-k3s\teardown-k3s.ps1"
            }
            "delete" {
                & "$infraRoot\local-k3s\teardown-k3s.ps1" -Delete
            }
            "status" {
                Write-Host "--- Clústeres k3d ---" -ForegroundColor Cyan
                & k3d cluster list
                Write-Host "`n--- Contexto kubectl actual ---" -ForegroundColor Cyan
                & kubectl cluster-info
            }
            "addons" {
                $ip = if ($PublicIp) { $PublicIp } else { "127.0.0.1" }
                & "$infraRoot\addons\install.ps1" -Target local -PublicIp $ip
            }
            default {
                Write-Warning "Acción desconocida '$Action' para target local. Acciones válidas: start, stop, delete, status, addons."
            }
        }
    }

    "azure" {
        switch ($Action.ToLower()) {
            "status" {
                & "$infraRoot\azure-terraform\scripts\aks-power.ps1" -Action status -ResourceGroup $ResourceGroup -ClusterName $ClusterName
            }
            "start" {
                & "$infraRoot\azure-terraform\scripts\aks-power.ps1" -Action start -ResourceGroup $ResourceGroup -ClusterName $ClusterName
            }
            "stop" {
                & "$infraRoot\azure-terraform\scripts\aks-power.ps1" -Action stop -ResourceGroup $ResourceGroup -ClusterName $ClusterName
            }
            "connect" {
                Write-Host "Obteniendo credenciales de AKS para kubectl..." -ForegroundColor Cyan
                & az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing
                & kubectl get nodes
            }
            "plan" {
                Push-Location "$infraRoot\azure-terraform\environments\dev"
                try {
                    & terraform plan
                } finally {
                    Pop-Location
                }
            }
            "apply" {
                Push-Location "$infraRoot\azure-terraform\environments\dev"
                try {
                    & terraform apply
                } finally {
                    Pop-Location
                }
            }
            "addons" {
                $params = @{ Target = "azure" }
                if ($PublicIp) { $params["PublicIp"] = $PublicIp }
                & "$infraRoot\addons\install.ps1" @params
            }
            default {
                Write-Warning "Acción desconocida '$Action' para target azure. Acciones válidas: status, start, stop, connect, plan, apply, addons."
            }
        }
    }

    "addons" {
        $clusterTarget = if ($Action -match "azure|local") { $Action } else { "local" }
        $params = @{ Target = $clusterTarget }
        if ($PublicIp) { $params["PublicIp"] = $PublicIp }
        & "$infraRoot\addons\install.ps1" @params
    }
}
