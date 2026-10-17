#!/bin/bash
# Experimento de Idempotencia - Universidad de los Andes ARTI4208
# Script de despliegue de infraestructura
# Uso: ./scripts/idempotency/deploy-idempotency-lab.sh

set -e

# Detectar directorio root del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "================================================================"
echo "   Despliegue del Experimento de Idempotencia"
echo "   Material ARTI4208 - Universidad de los Andes"
echo "================================================================"
echo ""

# Verificar kubectl
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] kubectl no está instalado"
    exit 1
fi

# Verificar namespace voltera
echo "[INFO] Verificando namespace 'voltera'..."
if ! kubectl get namespace voltera &> /dev/null; then
    echo "[INFO] Namespace 'voltera' no existe, creando..."
    kubectl create namespace voltera
    kubectl label namespace voltera istio-injection=enabled --overwrite
fi

echo "[OK] Namespace voltera OK"
echo ""

# Paso 1: Desplegar Redis
echo "[1/5] Desplegando Redis (caché de idempotencia)..."
kubectl apply -f "$PROJECT_ROOT/k8s/redis-idempotency.yaml"
echo "[OK] Redis desplegado"
echo ""

# Paso 2: Desplegar PostgreSQL
echo "[2/5] Desplegando PostgreSQL (persistencia)..."
kubectl apply -f "$PROJECT_ROOT/k8s/postgres-matches.yaml"
echo "[OK] PostgreSQL desplegado"
echo ""

# Esperar a que estén ready
echo "[INFO] Esperando a que Redis y PostgreSQL estén listos..."
kubectl wait --for=condition=ready pod -l app=redis-idempotency -n voltera --timeout=120s
kubectl wait --for=condition=ready pod -l app=postgres-matches -n voltera --timeout=120s
echo "[OK] Redis y PostgreSQL están listos"
echo ""

# Paso 3: Construir imagen del match-processor
echo "[3/5] Construyendo imagen Docker de match-processor..."
cd "$PROJECT_ROOT/src/services/match-processor"

# Verificar si estamos en Docker Desktop o Minikube
if docker context inspect 2>/dev/null | grep -q "desktop-linux"; then
    echo "[INFO] Usando Docker Desktop..."
    docker build -t match-processor:latest .
elif command -v minikube &> /dev/null && minikube status &> /dev/null; then
    echo "[INFO] Usando Minikube..."
    eval $(minikube docker-env)
    docker build -t match-processor:latest .
else
    echo "[INFO] Construyendo imagen Docker estándar..."
    docker build -t match-processor:latest .
fi

cd "$PROJECT_ROOT"
echo "[OK] Imagen construida"
echo ""

# Paso 4: Desplegar match-processor
echo "[4/5] Desplegando match-processor..."
kubectl apply -f "$PROJECT_ROOT/k8s/match-processor.yaml" 2>&1 | grep -v "resource mapping not found" || true
echo "[OK] Match-processor desplegado (Knative/KEDA opcionales ignorados)"
echo ""

# Esperar a que esté ready
echo "[INFO] Esperando a que match-processor esté listo..."
kubectl wait --for=condition=ready pod -l app=match-processor -n voltera --timeout=120s
echo "[OK] Match-processor está listo"
echo ""

# Paso 5: Verificar estado
echo "[5/5] Verificando estado de los componentes..."
echo ""

echo "Pods en namespace voltera:"
kubectl get pods -n voltera -l 'app in (redis-idempotency,postgres-matches,match-processor)'
echo ""

echo "Servicios:"
kubectl get svc -n voltera -l 'app in (redis-idempotency,postgres-matches,match-processor)'
echo ""

echo "Knative Trigger:"
kubectl get trigger trigger-match-processor -n voltera 2>/dev/null || echo "[INFO] Trigger no encontrado (verificar Knative Eventing)"
echo ""

# Información de conexión
echo "================================================================"
echo "   DESPLIEGUE COMPLETADO"
echo "================================================================"
echo ""
echo "Endpoint del servicio:"
echo "   kubectl port-forward -n voltera svc/match-processor 8080:8080"
echo ""
echo "Métricas Prometheus:"
echo "   curl http://localhost:8080/metrics"
echo ""
echo "Health Check:"
echo "   curl http://localhost:8080/health"
echo ""
echo "Ejecutar demo de idempotencia:"
echo "   ./scripts/idempotency/demo-idempotency.sh"
echo ""
