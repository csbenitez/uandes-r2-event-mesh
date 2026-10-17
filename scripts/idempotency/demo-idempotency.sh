#!/bin/bash
# Experimento de Idempotencia - Universidad de los Andes ARTI4208
# Demo completo: limpieza + test + validación
# Uso: ./scripts/idempotency/demo-idempotency.sh

# Detectar directorio root del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

NAMESPACE="voltera"
TARGET_URL="${TARGET_URL:-http://localhost:8090/events}"
TOTAL="${TOTAL:-1000}"

echo "=================================="
echo "DEMO IDEMPOTENCIA - $TOTAL EVENTOS"
echo "=================================="
echo ""

# Verificar que hay un port-forward activo o crear uno
echo "[INFO] Verificando port-forward..."
if ! curl -s http://localhost:8090/health > /dev/null 2>&1; then
    echo "      Iniciando port-forward en background..."
    kubectl port-forward -n $NAMESPACE svc/match-processor 8090:8080 > /dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    
    # Esperar hasta que esté listo (máximo 15 segundos)
    READY=false
    for i in {1..15}; do
        if curl -s http://localhost:8090/health > /dev/null 2>&1; then
            # Verificar 3 veces más para estar seguros
            sleep 1
            if curl -s http://localhost:8090/health > /dev/null 2>&1; then
                sleep 1
                if curl -s http://localhost:8090/health > /dev/null 2>&1; then
                    READY=true
                    break
                fi
            fi
        fi
        echo "      Esperando port-forward... ($i/15)"
        sleep 1
    done
    
    if [ "$READY" = false ]; then
        echo "ERROR: Port-forward no responde después de 15 segundos"
        kill $PORT_FORWARD_PID 2>/dev/null
        exit 1
    fi
    
    echo "✓ Port-forward activo y estable (PID: $PORT_FORWARD_PID)"
    sleep 2  # Pausa adicional para estabilidad
else
    echo "✓ Port-forward ya está activo"
    PORT_FORWARD_PID=""
fi
echo ""

# Limpiar DB
echo "[1/3] Limpiando base de datos..."
POSTGRES_POD=$(kubectl get pod -n $NAMESPACE -l app=postgres-matches -o jsonpath='{.items[0].metadata.name}')
REDIS_POD=$(kubectl get pod -n $NAMESPACE -l app=redis-idempotency -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U voltera -d voltera_matches -c "TRUNCATE matches, processed_events;" 2>/dev/null
kubectl exec -n $NAMESPACE $REDIS_POD -- redis-cli FLUSHDB 2>/dev/null
echo "OK"
echo ""

# Estado inicial
echo "[2/3] Estado inicial:"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U voltera -d voltera_matches -c "SELECT COUNT(*) FROM matches;"
echo ""

# Ejecutar k6
echo "[3/3] Ejecutando k6 (1000 eventos, 10% duplicados)..."
echo "---------------------------------------------------"
k6 run "$PROJECT_ROOT/tests/04_idempotency_test.js" -e TARGET_URL=$TARGET_URL -e TOTAL=$TOTAL
echo "---------------------------------------------------"
echo ""

# Resultados
echo "RESULTADOS:"
echo "==========="
echo ""
echo "1. Buscar duplicados en tabla 'matches' (debe estar VACÍO):"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U voltera -d voltera_matches -c "
SELECT match_id, COUNT(*) as count 
FROM matches 
GROUP BY match_id 
HAVING COUNT(*) > 1;
"

echo ""
echo "2. Resumen:"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U voltera -d voltera_matches -c "
SELECT 
    'Únicos procesados' as metrica, 
    COUNT(DISTINCT match_id)::text as valor
FROM matches
UNION ALL
SELECT 
    'Intentos totales', 
    COUNT(*)::text
FROM processed_events
UNION ALL
SELECT 
    'En tabla matches', 
    COUNT(*)::text
FROM matches;
"

echo ""
echo "=================================="
echo "ESPERADO: 900 únicos / 1000 total"
echo "=================================="

# Cleanup: matar el port-forward si lo iniciamos nosotros
if [ -n "$PORT_FORWARD_PID" ]; then
    echo ""
    echo "[CLEANUP] Deteniendo port-forward (PID: $PORT_FORWARD_PID)..."
    kill $PORT_FORWARD_PID 2>/dev/null
fi
