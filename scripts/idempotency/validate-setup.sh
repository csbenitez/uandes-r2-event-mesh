#!/bin/bash
# Experimento de Idempotencia - Universidad de los Andes ARTI4208
# Validación de prerequisitos
# Ejecuta ANTES de deploy-idempotency-lab.sh

# Detectar directorio root del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "================================================================"
echo "   Validación de Prerequisitos - Experimento Idempotencia"
echo "================================================================"
echo ""

ERRORS=0

# Función para verificar comando
check_command() {
    if command -v $1 &> /dev/null; then
        echo "[OK] $1 instalado: $(command -v $1)"
    else
        echo "[ERROR] $1 NO instalado"
        ERRORS=$((ERRORS + 1))
    fi
}

# Verificar comandos básicos
echo "Verificando comandos necesarios:"
check_command kubectl
check_command docker
check_command k6
echo ""

# Verificar kubectl context
echo "Verificando contexto de kubectl:"
if kubectl config current-context &> /dev/null; then
    CONTEXT=$(kubectl config current-context)
    echo "[OK] Contexto activo: $CONTEXT"
else
    echo "[ERROR] No hay contexto de kubectl configurado"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Verificar conexión a cluster
echo "Verificando conexión al cluster:"
if kubectl cluster-info &> /dev/null; then
    echo "[OK] Cluster accesible"
    kubectl version --short 2>/dev/null || kubectl version 2>&1 | head -2
else
    echo "[ERROR] No se puede conectar al cluster"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Verificar Docker
echo "Verificando Docker:"
if docker info &> /dev/null; then
    echo "[OK] Docker daemon corriendo"
else
    echo "[ERROR] Docker daemon no accesible"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Verificar archivos necesarios
echo "Verificando archivos del experimento:"
FILES=(
    "$PROJECT_ROOT/src/services/match-processor/main.go"
    "$PROJECT_ROOT/src/services/match-processor/Dockerfile"
    "$PROJECT_ROOT/src/services/match-processor/go.mod"
    "$PROJECT_ROOT/k8s/redis-idempotency.yaml"
    "$PROJECT_ROOT/k8s/postgres-matches.yaml"
    "$PROJECT_ROOT/k8s/match-processor.yaml"
    "$PROJECT_ROOT/tests/04_idempotency_test.js"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "[OK] $file"
    else
        echo "[ERROR] $file NO encontrado"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Resultado final
echo "================================================================"
if [ $ERRORS -eq 0 ]; then
    echo "[OK] TODAS LAS VALIDACIONES PASARON"
    echo ""
    echo "Puedes continuar con:"
    echo "  ./scripts/idempotency/deploy-idempotency-lab.sh"
    exit 0
else
    echo "[ERROR] $ERRORS ERROR(S) ENCONTRADO(S)"
    echo ""
    echo "Por favor corrige los errores antes de continuar"
    exit 1
fi
