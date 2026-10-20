$ErrorActionPreference = "Stop"

Write-Host "======================================"
Write-Host " VOLTERA - SETUP LABORATORIO KEDA"
Write-Host "======================================"

Write-Host "`n[1/7] Iniciando Minikube..."
minikube start --driver=docker --cpus=4 --memory=6144

Write-Host "`n[2/7] Configurando repositorios Helm..."
helm repo add kedacore https://kedacore.github.io/charts 2>$null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>$null
helm repo update

Write-Host "`n[3/7] Creando namespace voltera..."
kubectl create namespace voltera --dry-run=client -o yaml | kubectl apply -f -

Write-Host "`n[4/7] Instalando KEDA..."
helm upgrade --install keda kedacore/keda `
  --namespace keda `
  --create-namespace

Write-Host "`n[5/7] Desplegando Kafka..."
kubectl apply -f .\k8s\base\kafka.yaml

kubectl rollout status deployment/kafka `
  -n voltera `
  --timeout=180s

Write-Host "`nCreando topics..."
kubectl delete job kafka-init -n voltera --ignore-not-found
kubectl apply -f .\k8s\base\kafka-init.yaml

Write-Host "`n[6/7] Instalando Prometheus y Grafana..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  -f .\k8s\monitoring\kube-prometheus-stack-values.yaml

Write-Host "`nEsperando Grafana..."
kubectl rollout status deployment/monitoring-grafana `
  -n monitoring `
  --timeout=300s

Write-Host "`nInstalando Kafka Exporter..."
helm upgrade --install kafka-exporter prometheus-community/prometheus-kafka-exporter `
  --namespace monitoring `
  -f .\k8s\monitoring\kafka-exporter-values.yaml

Write-Host "`nHabilitando metricas KEDA..."
helm upgrade keda kedacore/keda `
  --namespace keda `
  --reuse-values `
  --set prometheus.operator.enabled=true `
  --set prometheus.operator.serviceMonitor.enabled=true `
  --set prometheus.operator.serviceMonitor.interval=5s `
  --set prometheus.operator.serviceMonitor.additionalLabels.release=monitoring

Write-Host "`n[7/7] Instalando dashboard Grafana..."
kubectl apply -f .\k8s\monitoring\voltera-keda-dashboard.yaml

Write-Host "`n======================================"
Write-Host " INFRAESTRUCTURA BASE LISTA"
Write-Host "======================================"
