# Script para inyectar automáticamente el Dashboard de Voltera Event Mesh en el ConfigMap de Grafana
$dashboardFile = Join-Path $PSScriptRoot "voltera-eventmesh-dashboard.json"
$dashboardContent = Get-Content -Raw -Path $dashboardFile

Write-Host "Inyectando dashboard de Voltera en ConfigMap istio-grafana-dashboards (namespace istio-system)..." -ForegroundColor Cyan

# Crear o actualizar una entrada en el ConfigMap existente
$patchJson = @{
    data = @{
        "voltera-eventmesh.json" = $dashboardContent
    }
} | ConvertTo-Json -Depth 10

$tempPatch = New-TemporaryFile
$patchJson | Out-File -FilePath $tempPatch.FullName -Encoding utf8

kubectl patch configmap istio-grafana-dashboards -n istio-system --type merge --patch-file $tempPatch.FullName
Remove-Item $tempPatch.FullName

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Dashboard 'voltera-eventmesh.json' agregado exitosamente a Grafana." -ForegroundColor Green
    Write-Host "Para visualizar Grafana ejecuta:" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward svc/grafana -n istio-system 3000:3000" -ForegroundColor White
    Write-Host "Abre: http://localhost:3000 -> Dashboards -> Folder 'istio' -> 'Voltera - Event Mesh & Distributed Tracing'" -ForegroundColor White
} else {
    Write-Error "Fallo al inyectar el dashboard en el ConfigMap."
}
