$ErrorActionPreference = "Stop"

Write-Host "=== Construyendo metering-service ==="

minikube image build `
  -t voltera/metering-service:local `
  -f .\src\Voltera.Metering.Worker\Dockerfile .

Write-Host "`n=== Construyendo AMI Simulator ==="

minikube image build `
  -t voltera/ami-simulator:local `
  -f .\src\Voltera.AmiSimulator\Dockerfile .

Write-Host "`n=== Desplegando Metering ==="

kubectl apply -f .\k8s\base\metering-deployment.yaml
kubectl apply -f .\k8s\keda\metering-scaledobject.yaml

Write-Host "`n=== LISTO ==="

kubectl get scaledobject -n voltera
kubectl get deployment metering-service -n voltera
