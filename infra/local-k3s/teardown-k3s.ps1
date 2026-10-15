<#
.SYNOPSIS
    Pausa o elimina el clúster local K3s para liberar memoria en la máquina local.
.PARAMETER Delete
    Si se especifica, destruye completamente el clúster en vez de sólo detenerlo.
#>
[CmdletBinding()]
param(
    [string]$ClusterName = "voltera-onprem",
    [switch]$Delete
)

$ErrorActionPreference = "Stop"

$wingetPath = "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
if ((Test-Path $wingetPath) -and ($env:Path -notlike "*$wingetPath*")) {
    $env:Path = "$wingetPath;$env:Path"
}

if ($Delete) {
    Write-Host "Eliminando clúster k3d '$ClusterName'..." -ForegroundColor Red
    & k3d cluster delete $ClusterName
    Write-Host "Clúster eliminado." -ForegroundColor Green
} else {
    Write-Host "Pausando clúster k3d '$ClusterName' (cero uso de RAM/CPU)..." -ForegroundColor Yellow
    & k3d cluster stop $ClusterName
    Write-Host "Clúster pausado. Puedes reanudarlo ejecutando 'setup-k3s.ps1'." -ForegroundColor Green
}
