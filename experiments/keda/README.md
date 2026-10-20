# Voltera · Entrega 3 · Starter local

Starter para validar **EDA + Kafka + CQRS + transferencia de estado + Transactional Outbox**, preparado para evolucionar a **Kubernetes local + KEDA + Event Mesh**.

## 1. Alineación con los Bounded Contexts

| Bounded Context | Aggregate Root | Componente inicial |
|---|---|---|
| Medición y Telemetría Energética | Medición Energética | `Voltera.Metering.Worker` |
| Balance P2P | Balance Energético | `Voltera.Balance.Worker` |
| Match Energético | Match Energético | `Voltera.Matching.Worker` |

Componentes de soporte:

- `Voltera.AmiSimulator`: simula `LecturaMedidorRecibida`.
- `Voltera.PriceSimulator`: publica `PrecioKWhActualizado`.
- `Voltera.MarketProjector.Worker`: lado de lectura CQRS → Redis.
- `Voltera.Contracts`: contratos de eventos.
- `docs/asyncapi.yaml`: Event API / AsyncAPI.

## 2. Topics Kafka

| Topic | Evento(s) | Consumer group principal |
|---|---|---|
| `meter-declarations` | `LecturaMedidorRecibida` | `metering-service` |
| `energy-measurements` | `MedicionEnergeticaRegistrada` | `energy-balance-service` |
| `energy-positions` | `ExcedenteEnergeticoDetectado`, `DemandaEnergeticaDetectada` | `market-projector` |
| `kwh-prices` | `PrecioKWhActualizado` | `market-projector` |
| `matching-parameters` | `ParametrosMatchingActualizados` | evolución del motor |
| `energy-matched` | `MatchEnergeticoConfirmado`, `MatchEnergeticoRechazado` | fuera de alcance / Event Mesh |

> En Kafka, `meter-declarations` es un **topic**. El comportamiento tipo Queue se logra con el **consumer group `metering-service`**: una partición es atendida por una instancia del grupo a la vez. Esto permite escalar con KEDA usando consumer lag.

## 3. Requisitos locales

- Visual Studio 2022 (17.8+) con .NET 8 SDK.
- Docker Desktop.
- Git opcional.

Para KEDA posteriormente:

- `kubectl`
- Minikube (recomendado para la práctica) o Kind/k3d.
- Helm.

## 4. Primer arranque

Desde PowerShell, en la raíz:

```powershell
docker compose up -d
```

Servicios:

- Kafka: `localhost:29092`
- Kafka UI: http://localhost:8080
- PostgreSQL: `localhost:5432` (`voltera/voltera`)
- Redis: `localhost:6379`

Valida:

```powershell
.\scripts\status.ps1
```

## 5. Abrir en Visual Studio

Abre:

`Voltera.Entrega3.sln`

Configura **Multiple startup projects** para iniciar inicialmente:

1. `Voltera.Metering.Worker`
2. `Voltera.Balance.Worker`
3. `Voltera.MarketProjector.Worker`
4. `Voltera.Matching.Worker`

Después ejecuta los simuladores desde terminal.

### Precio

```powershell
dotnet run --project .\src\Voltera.PriceSimulator -- 20 5000
```

### Lecturas AMI

```powershell
dotnet run --project .\src\Voltera.AmiSimulator -- 100 100
```

Flujo esperado:

```text
AMI Simulator
   -> meter-declarations
   -> metering-service
   -> energy-measurements
   -> energy-balance-service
   -> energy-positions
   -> market-projector
   -> Redis Read Model
   -> matching-engine
   -> PostgreSQL matches + outbox
   -> energy-matched
```

## 6. Qué observar

Kafka UI (`localhost:8080`):

- mensajes por topic,
- particiones,
- consumer groups,
- lag.

PostgreSQL:

```sql
select * from matches order by created_at desc;
select * from outbox order by created_at desc;
```

Redis:

- `voltera:offers`
- `voltera:demands`
- `voltera:price:current`
- `voltera:processed-events`

## 7. Transferencia de estado

`MedicionEnergeticaRegistrada` transporta consumo, generación, participante, medidor, zona y ubicación. El BC Balance puede calcular su posición **sin llamar síncronamente al BC productor**.

`ExcedenteEnergeticoDetectado` y `DemandaEnergeticaDetectada` transportan el estado requerido para proyectar y hacer matching sin consultar al servicio Balance.

## 8. CQRS

- **Write / dominio:** eventos y matches persistidos en PostgreSQL.
- **Read Model:** Redis actualizado por `market-projector`.
- `matching-engine` consulta Redis por ventana para obtener ofertas/demandas y precio.

## 9. Transactional Outbox

`matching-engine` guarda en la misma transacción PostgreSQL:

1. `matches`
2. `outbox`

Luego publica `MatchEnergeticoConfirmado` en `energy-matched` y marca `published_at`.

## 10. KEDA (siguiente fase)

Se incluye `k8s/keda/metering-scaledobject.yaml`.

Objetivo experimental:

- Topic: `meter-declarations`
- Consumer group: `metering-service`
- Lag threshold: `100`
- Réplicas: `0..10`

La prueba será publicar 1.000 mensajes y medir:

- tiempo hasta escalar,
- réplicas activas,
- reducción de consumer lag,
- retorno a `minReplicaCount`.

## 11. Experimentos de la rúbrica

### EDA
Apagar un consumidor durante 60 s, seguir publicando y validar que el backlog se drena al recuperarse.

### KEDA
Publicar 1.000 eventos y comprobar escalamiento por consumer lag.

### CQRS
Medir `T(write PostgreSQL) -> T(proyección Redis)`; objetivo inicial `p95 <= 2 s`.

### Transferencia de estado + idempotencia
Reenviar eventos con el mismo `eventId`. El projector usa `voltera:processed-events` para evitar efectos duplicados; los eventos transportan el estado necesario sin callback al productor.

## 12. Nota sobre Event Mesh

Este starter usa un broker Kafka local. El Event Mesh multi-región se añadirá después del flujo funcional, por ejemplo con dos clusters Kafka y replicación/bridge (p. ej. MirrorMaker 2), manteniendo `energy-matched` como evento exportable.
