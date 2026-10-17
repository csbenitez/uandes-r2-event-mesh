# Experimento de Idempotencia - Motor de Emparejamiento P2P

## Objetivo del Experimento

Implementar y demostrar **idempotencia** en una arquitectura dirigida por eventos según los principios del material de UniAndes ARTI4208, bajo el estímulo:

**Estímulo**: Reenviar 10% de señales y matches con el mismo `matchId`

**Criterios de Éxito**:
- Un solo efecto por `matchId`
- Sin matches duplicados en estado final
- El consumidor completa el procesamiento sin consultar síncronamente al productor

---

## Arquitectura del Experimento

```
┌────────────────────────────────────────────────────────────────┐
│          EXPERIMENTO DE IDEMPOTENCIA - ARQUITECTURA            │
└────────────────────────────────────────────────────────────────┘

┌─────────────────┐         ┌──────────────────────┐
│  Test Generator │         │ Knative Cloud Broker │
│  (10% duplicado)│────────>│   (Event Mesh)       │
│  k6 + script    │         └──────────┬───────────┘
└─────────────────┘                    │
                                       │ Filter: com.voltera.match.created
                                       ▼
                         ┌──────────────────────────────────┐
                         │   match-processor Service        │
                         │   • Deduplicación por matchId    │
                         │   • Caché Redis (24h TTL)        │
                         │   • Registro atómico PostgreSQL  │
                         │   • Métricas Prometheus          │
                         └──────────────────────────────────┘
                                       │
                                       ▼
                         ┌──────────────────────────────────┐
                         │    PostgreSQL Database           │
                         │    • matches (UNIQUE matchId)    │
                         │    • processed_events            │
                         └──────────────────────────────────┘
```

---

## Diseño de Idempotencia según Material UniAndes

### Dos Reglas de Oro

**1. Clave estable del negocio**
```
MAL:  key = uuid.New()              // Siempre "único"
MAL:  key = kafkaOffset             // Cambia con rebalanceos
BIEN: key = event.MatchID           // Del dominio de negocio
BIEN: key = SHA256(meter + period)  // Derivado del hecho
```

**2. Registro atómico (efecto + clave en misma transacción)**
```go
tx.Begin()
    // 1. Verificar si ya procesado
    exists := checkIdempotency(tx, matchID)
    if exists {
        return nil // Idempotente
    }
    
    // 2. Aplicar efecto de negocio
    insertMatch(tx, matchData)
    
    // 3. Registrar clave en MISMA transacción
    markProcessed(tx, matchID)
tx.Commit()
```

---

## Implementación

### Infraestructura Requerida

1. **Redis** (caché de idempotencia)
   - Política LRU con 256MB
   - TTL 24 horas por clave

2. **PostgreSQL** (persistencia)
   - Tabla `matches` con constraint UNIQUE en `match_id`
   - Tabla `processed_events` para registro de idempotencia
   - Índice en `processed_at` para limpieza periódica

3. **match-processor** (servicio Go)
   - Implementa las dos reglas de idempotencia
   - Expone métricas Prometheus
   - Health checks para Kubernetes

Ver manifiestos completos en `k8s/`:
- `redis-idempotency.yaml`
- `postgres-matches.yaml`
- `match-processor.yaml`

### Flujo de Procesamiento

```
1. Recibir evento con matchId
2. Verificar en Redis: ¿ya procesado?
   └→ SÍ: return nil (idempotente)
3. Si NO, iniciar transacción PostgreSQL
4. Insertar marca en processed_events (ON CONFLICT DO NOTHING)
5. Si insert exitoso:
   a. Insertar en matches
   b. Commit transacción
   c. Actualizar cache Redis
6. Si conflict: otro proceso ya lo procesó, return nil
```

### Métricas Implementadas

```
matches_received_total              (Counter)
matches_unique_processed            (Counter)
matches_duplicates_detected         (Counter)
idempotency_cache_hits              (Counter)
idempotency_check_duration_seconds  (Histogram)
```

---

## Ejecución

### Despliegue

```bash
# 1. Validar prerequisitos
./scripts/validate-setup.sh

# 2. Desplegar infraestructura
./scripts/deploy-idempotency-lab.sh
```

### Ejecutar Demo

```bash
./scripts/idempotency/demo-idempotency.sh
```

**Resultado esperado**: 900 únicos procesados de 1000 enviados, 0 duplicados en DB.

Para más detalles sobre los scripts, consulta: `../scripts/README.md`

---

## Validación de Resultados

### Query: Buscar duplicados
```sql
SELECT match_id, COUNT(*) as count 
FROM matches 
GROUP BY match_id 
HAVING COUNT(*) > 1;
```

**Resultado esperado**: 0 rows (sin duplicados)

### Query: Resumen de procesamiento
```sql
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
```

**Resultado esperado**:
- Únicos procesados: 900
- Intentos totales: 1000
- En tabla matches: 900

---

## Referencias

- Material UniAndes ARTI4208: Patrones de idempotencia en EDA
- CloudEvents v1.0 Specification
- Knative Eventing: Reply Pattern
- Martin Fowler: Idempotent Receiver Pattern

---

**Autor**: Experimento ARTI4208  
**Fecha**: Octubre 2026  
**Versión**: 1.0
