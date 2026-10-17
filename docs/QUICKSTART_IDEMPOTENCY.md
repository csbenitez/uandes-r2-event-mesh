# Quick Start - Experimento de Idempotencia

## Instalación Rápida

### 1. Prerrequisitos

```bash
# Verificar instalación
kubectl version --client
k6 version
docker --version

# Instalar herramientas adicionales
sudo apt update
sudo apt install -y postgresql-client redis-tools watch
```

### 2. Desplegar Infraestructura

```bash
cd uandes-r2-event-mesh

# Dar permisos a scripts (en WSL2/Linux)
chmod +x scripts/idempotency/*.sh

# Desplegar todo el experimento
./scripts/idempotency/deploy-idempotency-lab.sh
```

**Tiempo estimado**: 3-5 minutos

### 3. Verificar Despliegue

```bash
# Verificar pods
kubectl get pods -n voltera

# Deberías ver:
# - redis-idempotency-xxx       Running
# - postgres-matches-xxx        Running
# - match-processor-xxx         Running
```

### 4. Ejecutar Demo de Idempotencia

```bash
# Ejecutar demo completo (limpia DB + test + validación)
./scripts/idempotency/demo-idempotency.sh
```

**Resultado esperado**: 900 únicos procesados de 1000 enviados, 0 duplicados en DB

---

## Validación Manual

### Ver logs en tiempo real

```bash
kubectl logs -f -n voltera -l app=match-processor
```

### Consultar duplicados en DB

```bash
POSTGRES_POD=$(kubectl get pod -n voltera -l app=postgres-matches -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n voltera $POSTGRES_POD -- psql -U voltera -d voltera_matches -c "
SELECT 
    match_id, 
    COUNT(*) as count 
FROM matches 
GROUP BY match_id 
HAVING COUNT(*) > 1;
"
```

**Resultado esperado**: `0 rows` (sin duplicados)

### Ver estadísticas

```bash
kubectl exec -n voltera $POSTGRES_POD -- psql -U voltera -d voltera_matches -c "
SELECT 
    'Únicos procesados: ' || COUNT(DISTINCT match_id) as stat
FROM matches
UNION ALL
SELECT 
    'Intentos totales: ' || COUNT(*) as stat
FROM processed_events
UNION ALL
SELECT 
    'Efectividad: ' || ROUND(100.0 * COUNT(DISTINCT m.match_id) / (SELECT COUNT(*) FROM processed_events), 1) || '%' as stat
FROM matches m;
"
```

**Resultado esperado**:
```
Únicos procesados: 900
Intentos totales: 1000
Efectividad: 90.0%
```

---

## Troubleshooting

### Pod no inicia

```bash
# Ver detalles del pod
kubectl describe pod -n voltera -l app=match-processor

# Ver logs
kubectl logs -n voltera -l app=match-processor
```

### Imagen Docker no encontrada

```bash
# Reconstruir imagen
cd src/services/match-processor
docker build -t match-processor:latest .
cd ../../..

# Reiniciar deployment
kubectl rollout restart deployment/match-processor -n voltera
```

### Redis o PostgreSQL no conectan

```bash
# Verificar servicios
kubectl get svc -n voltera

# Probar conexión manual
kubectl exec -n voltera -it $(kubectl get pod -n voltera -l app=redis-idempotency -o jsonpath='{.items[0].metadata.name}') -- redis-cli PING

kubectl exec -n voltera -it $(kubectl get pod -n voltera -l app=postgres-matches -o jsonpath='{.items[0].metadata.name}') -- psql -U voltera -d voltera_matches -c "SELECT 1;"
```

---

## Limpieza

### Limpiar solo datos (mantener infraestructura)

```bash
POSTGRES_POD=$(kubectl get pod -n voltera -l app=postgres-matches -o jsonpath='{.items[0].metadata.name}')
REDIS_POD=$(kubectl get pod -n voltera -l app=redis-idempotency -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n voltera $POSTGRES_POD -- psql -U voltera -d voltera_matches -c "TRUNCATE matches, processed_events;"
kubectl exec -n voltera $REDIS_POD -- redis-cli FLUSHDB
```

### Eliminar todo el experimento

```bash
kubectl delete -f k8s/match-processor.yaml
kubectl delete -f k8s/postgres-matches.yaml
kubectl delete -f k8s/redis-idempotency.yaml
```

---

## Archivos Clave

```
uandes-r2-event-mesh/
├── src/services/match-processor/
│   ├── main.go              # Implementación con idempotencia
│   ├── go.mod
│   └── Dockerfile
├── k8s/
│   ├── redis-idempotency.yaml
│   ├── postgres-matches.yaml
│   └── match-processor.yaml
├── tests/
│   └── 04_idempotency_test.js
├── scripts/idempotency/
│   ├── setup-prerequisites.sh
│   ├── validate-setup.sh
│   ├── deploy-idempotency-lab.sh
│   └── demo-idempotency.sh  # Script principal
└── docs/
    ├── IDEMPOTENCY_EXPERIMENT.md
    └── QUICKSTART_IDEMPOTENCY.md
```

---

## Soporte

Si encuentras problemas:

1. Verifica los logs: `kubectl logs -n voltera -l app=match-processor`
2. Consulta la documentación completa: `docs/IDEMPOTENCY_EXPERIMENT.md`

---

**Criterios de Éxito:**
- 1000 eventos enviados (900 únicos + 100 duplicados)
- 900 registros únicos en PostgreSQL
- 0 duplicados en la tabla matches
- Consumidor procesa autónomamente (sin consultas síncronas)
