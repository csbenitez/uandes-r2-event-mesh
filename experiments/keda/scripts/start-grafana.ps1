$secret = kubectl get secret monitoring-grafana `
  -n monitoring `
  -o jsonpath="{.data.admin-password}"

$password = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($secret)
)

Write-Host ""
Write-Host "======================================"
Write-Host " GRAFANA"
Write-Host "======================================"
Write-Host "URL:      http://127.0.0.1:3000"
Write-Host "Usuario:  admin"
Write-Host "Password: $password"
Write-Host ""
Write-Host "Dashboard:"
Write-Host "Voltera - Experimento KEDA"
Write-Host ""
Write-Host "Deje esta terminal abierta."
Write-Host "======================================"

kubectl port-forward svc/monitoring-grafana `
  -n monitoring `
  3000:80
