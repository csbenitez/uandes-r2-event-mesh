# Especificación Técnica de PoC: Event Mesh, Bounded Contexts y Agregados para Voltera

## 1. Contexto Estratégico y Arquitectónico

**Voltera** nace en 2026 como una comercializadora digital de energía (*energytech*) sobre una arquitectura *greenfield* y *cloud-native* [118]. La plataforma opera como un orquestador digital sobre tres pilares de la transición energética en Colombia:
1. **Infraestructura de Medición Avanzada (AMI)**: Regulada por la Resolución CREG 101-001 de 2022, que establece la comunicación bidireccional y la transmisión de lecturas de energía en intervalos finos de tiempo (15 minutos a 1 hora) [1, 10].
2. **Generación Distribuida y Autogeneración a Pequeña Escala (AGPE)**: Bajo la Resolución CREG 174 de 2021 [49].
3. **Comunidades Energéticas y Autogeneración Colectiva (AC)**: Reguladas por la Resolución CREG 101 072 de 2025 y el Decreto 2236 de 2023 [39, 44].

Dado que Colombia se encuentra actualmente en la **fase de transición** (donde los Operadores de Red - OR - deben disponer diariamente los datos de lectura antes de las 8:00 a.m. a través de sus portales/APIs mientras entra en operación el GIDI) [21, 32], la arquitectura de Voltera debe soportar la heterogeneidad de fuentes de datos mediante adaptadores desacoplados (*Anti-Corruption Layers*), garantizando una postura de seguridad **Zero Trust** al tratarse de infraestructura crítica [120, 143].

---

## 2. Diseño Estratégico DDD (Domain-Driven Design)

### 2.1 Clasificación de Subdominios

```
                          ┌─────────────────────────────────────────────────────────┐
                          │                DOMINIO VOLTERA (ENERGYTECH)             │
                          └────────────────────────────┬────────────────────────────┘
                                                       │
         ┌─────────────────────────────────────────────┼─────────────────────────────────────────────┐
         ▼                                             ▼                                             ▼
┌─────────────────────────┐               ┌─────────────────────────┐                   ┌─────────────────────────┐
│   SUBDOMINIOS NÚCLEO    │               │  SUBDOMINIOS SOPORTE    │                   │   SUBDOMINIOS GENÉRICOS │
│   (Core Domains)        │               │  (Supporting Domains)   │                   │   (Generic Domains)     │
├─────────────────────────┤               ├─────────────────────────┤                   ├─────────────────────────┤
│ • Mercado P2P y         │               │ • Ingesta e Interope-   │                   │ • Gestión de Usuarios   │
│   Comunidades           │               │   rabilidad (Multi-OR / │                   │   e Identidad (IAM)     │
│ • Liquidación y Tarifa  │               │   GIDI Adapter)         │                   │ • Pasarela de Pagos     │
│   Dinámica / Netting    │               │ • Gestión DERs (IoT)    │                   │   y Dispersión BPS      │
└─────────────────────────┘               └─────────────────────────┘                   └─────────────────────────┘
```

1. **Subdominios Núcleo (*Core Domains*)** (Diferenciador competitivo de Voltera):
   * **Mercado P2P y Comunidades Energéticas**: Modela las reglas de Autogeneración Colectiva (AC), asignación del Porcentaje de Distribución de Excedentes (PDE) entre vecinos [85] y la generación de Certificados de Origen Renovable.
   * **Facturación y Liquidación Net-Metering**: Aplica las fórmulas tarifarias de permutación 1 a 1 de excedentes ($Exc_1$) y valoración de sobrantes ($Exc_2$) al costo medio de la energía ($Mc$) según la Resolución CREG 101 072 de 2025 [51, 93, 113].

2. **Subdominios de Soporte (*Supporting Domains*)**:
   * **Ingesta e Interoperabilidad de Medición (Multi-OR / GIDI Adapter)**: Normaliza las lecturas recibidas por lotes diarios de los diversos ORs o del GIDI [21, 32].
   * **Gestión de Recursos Energéticos Distribuidos (DERs / IoT)**: Telemetría directa en tiempo real vía MQTT para baterías, inversores y cargadores de vehículos eléctricos [124, 143].

3. **Subdominios Genéricos (*Generic Domains*)**:
   * **Gestión de Clientes e Identidad (IAM)**: Autenticación Zero Trust y vinculación de fronteras comerciales ($NIU$).
   * **Pagos y Dispersión Bancaria**: Integración con pasarelas de recaudo (PSE) y dispersión masiva de fondos a cuentas de prosumidores.

---

### 2.2 Mapa de Contextos (*Context Map*) y Patrones de Relación

* **Ingesta Multi-OR / GIDI Context $\rightarrow$ Facturación & Liquidación Context**:
  * *Relación*: **Customer-Supplier** con **Anti-Corruption Layer (ACL)**.
  * *Mecanismo*: El adaptador del OR traduce las estructuras heterogéneas (archivos XML, CSV, JSON o DLMS) a un evento estándar del dominio (`LecturaAMIRegistrada`).
* **Facturación & Liquidación Context $\rightarrow$ Mercado P2P & Comunidades Context**:
  * *Relación*: **Shared Kernel / Event-Driven Consumer**.
  * *Mecanismo*: El contexto P2P consume los eventos de lecturas verificadas para aplicar el algoritmo de reparto ($PDE$) antes de que el motor de facturación emita la liquidación final [85].

---

## 3. Diseño Táctico DDD: Bounded Contexts, Agregados y Entidades

### 3.1 Bounded Context 1: Ingesta de Medición (Telemetry & Ingestion)

#### **Agregado: `LecturaAMI` (Raíz del Agregado)**
* **Propósito**: Representa un registro de consumo o generación inmutable proveniente de la red de medición avanzada.
* **Atributos y Entidades**:
  * `LecturaId` (*Value Object*, GUID)
  * `NIU` (*Value Object*, Número de Identificación del Usuario)
  * `MedidorSerie` (*Value Object*, Identificador único del equipo físico)
  * `TimestampLectura` (*Value Object*, DateTime UTC)
  * `Intervalo` (*Value Object*, Enum: `MINUTOS_15`, `HORARIO`) [10]
  * `Metricas`:
    * `EnergiaImportadaKWh` (*Value Object*, Decimal $\ge 0$)
    * `EnergiaExportadaKWh` (*Value Object*, Decimal $\ge 0$)
    * `TensionVoltios` (*Value Object*, Decimal)
  * `EstadoLectura` (*Value Object*, Enum: `BRUTA`, `VALIDADA_VEE`, `ESTIMADA`)
* **Reglas de Negocio del Agregado**:
  * La lectura es **inmutable** una vez firmada.
  * No se permiten lecturas con `TimestampLectura` en el futuro.
  * Si la lectura contiene alarmas de manipulación (*tamper*) o fallo de tensión (*last gasp*), debe cambiar el estado del agregado a `ALERTA_DETECTADA` y emitir el evento correspondiente [8, 11].

---

### 3.2 Bounded Context 2: Mercado P2P y Comunidades Energéticas

#### **Agregado: `ComunidadEnergética` (Raíz del Agregado)**
* **Propósito**: Administra la asociación de usuarios, fronteras de autogeneración colectiva y reglas de reparto.
* **Atributos y Entidades**:
  * `ComunidadId` (*Value Object*, UUID)
  * `NombreComunidad` (*Value Object*, String)
  * `CodigoRUCE` (*Value Object*, Registro Único de Comunidades Energéticas) [75]
  * `RepresentanteLegalId` (*Value Object*)
  * `Miembros` (*Lista de Entidades `MiembroComunidad`*):
    * `NIU` (*Value Object*)
    * `Rol` (*Value Object*, Enum: `GENERADOR_AC`, `CONSUMIDOR_AC`, `PROSUMIDOR`)
    * `PDE` (*Value Object*, Porcentaje de Distribución de Excedentes, $0 \le PDE \le 100\%$) [85]
* **Reglas de Negocio del Agregado**:
  * **Invariante Regulado**: La sumatoria de los porcentajes de distribución de excedentes ($PDE$) de todos los miembros de la comunidad debe ser estrictamente igual al 100%:
    $$\sum_{u=1}^{U} PDE_{u} = 100\%$$ [85]
  * Todos los miembros de un Autogenerador Colectivo (AC) deben pertenecer al mismo mercado de comercialización y sistema de distribución local ($SDL$) [75].

---

### 3.3 Bounded Context 3: Facturación y Netting (Billing & Settlement)

#### **Agregado: `FacturaEnergia` (Raíz del Agregado)**
* **Propósito**: Calcula el balance mensual, aplica créditos de energía y genera la factura única unificada.
* **Atributos y Entidades**:
  * `FacturaId` (*Value Object*, UUID)
  * `NIU` (*Value Object*)
  * `PeriodoFacturacion` (*Value Object*, Mes/Año)
  * `ImportacionAcumuladaKWh` ($Imp$)
  * `ExportacionAcumuladaKWh` ($Exc$)
  * `CreditoEnergiaExc1KWh` ($Exc_1$, excedente permutado 1 a 1) [49]
  * `ExcedenteRestanteExc2KWh` ($Exc_2$, sobrante valorado al $Mc$) [51, 96, 113]
  * `ComponenteTarifario`:
    * `CostoUnitarioCU` ($CU_v$, $/kWh)
    * `CostoMedioEnergiaMc` ($Mc$, $/kWh) [51]
    * `MargenComercializacionCv` ($C_v$, $/kWh) [96, 113]
  * `ValorFacturaNeto` ($VE_{i,j,n,m,u}$, COP) [95, 112]
* **Reglas de Negocio del Agregado**:
  * Si $Exc \le Imp$, todo el excedente se trata como $Exc_1$ y se descuenta del consumo.
  * Si $Exc > Imp$, la fracción hasta igualar $Imp$ es $Exc_1$, y el remanente es $Exc_2$ valorado al costo medio $Mc$ [51, 93, 113].

---

## 4. Arquitectura de Event Mesh (Event-Driven Architecture)

El **Event Mesh** es la capa de transporte y enrutamiento dinámico de eventos que interconecta los microservicios en la nube con los agentes externos (GIDI, ORs e inversores IoT) [143].

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                   EVENT MESH (VOLTERA)                                  │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│  [ MQTT Broker (Edge) ]          [ Apache Kafka Cluster (Cloud Core) ]                  │
│  Inversores / DERs IoT   ──Bridge──► Tópico: voltera.co.telemetry.der.v1                │
│                                                                                         │
│  [ Multi-OR / GIDI Adapter ] ──────► Tópico: voltera.co.telemetry.ami-batch.v1         │
└────────────────────────────────────────────┬────────────────────────────────────────────┘
                                             │
                       ┌─────────────────────┼─────────────────────┐
                       ▼                     ▼                     ▼
            ┌────────────────────┐┌────────────────────┐┌────────────────────┐
            │ Microservicio P2P  ││ Microservicio Netting││ App Prosumidor     │
            │ & Comunidades      ││ & Facturación      ││ (WebSockets / Push)│
            └────────────────────┘└────────────────────┘└────────────────────┘
```

### 4.1 Convención de Nombres de Tópicos
Estructura: `voltera.{pais}.{entorno}.{dominio}.{tipo_evento}.v{version}`

Ejemplos:
* `voltera.co.prod.telemetry.ami-reading-received.v1`
* `voltera.co.prod.community.pde-allocated.v1`
* `voltera.co.prod.billing.invoice-settled.v1`

---

### 4.2 Catálogo y Esquema de Eventos de Negocio

#### **Evento 1: `LecturaAMIRegistrada` (Avro Schema)**
* **Tópico**: `voltera.co.prod.telemetry.ami-reading-received.v1`
* **Productor**: Microservicio `GIDI / Multi-OR Adapter`
* **Consumidores**: Microservicio de Facturación, Microservicio P2P, Data Lake Analítico.
* **Payload (JSON / Avro)**:
```json
{
  "eventId": "evt-8f92a34b-1234-4567-89ab-cdef01234567",
  "eventType": "LecturaAMIRegistrada",
  "timestamp": "2026-09-28T08:00:00Z",
  "data": {
    "niu": "98234710",
    "medidorSerie": "AMT-2026-009812",
    "orOrigen": "ENEL_BOGOTA",
    "fechaRegistro": "2026-09-27T23:45:00Z",
    "intervaloMinutos": 15,
    "importacionKWh": 1.45,
    "exportacionKWh": 3.80,
    "tensionVoltios": 120.5,
    "estadoVEE": "VALIDADA"
  }
}
```

#### **Evento 2: `ExcedenteP2PAsignado`**
* **Tópico**: `voltera.co.prod.community.pde-allocated.v1`
* **Productor**: Microservicio de Mercado P2P
* **Consumidores**: Microservicio de Facturación, Servicio de Certificados Blockchain, App Móvil.
* **Payload**:
```json
{
  "eventId": "evt-3c11b89a-5678-90ef-12ab-34cd567890ef",
  "eventType": "ExcedenteP2PAsignado",
  "timestamp": "2026-09-28T08:02:15Z",
  "data": {
    "comunidadId": "com-9012-sol-andina",
    "codigoRUCE": "CE-2025-00412",
    "niuGenerador": "98234710",
    "niuBeneficiario": "98234711",
    "pdeAplicado": 40.0,
    "kwhAsignados": 1.52,
    "fechaCiclo": "2026-09-27"
  }
}
```

---

### 4.3 Patrones de Resiliencia en el Event Mesh

1. **Idempotencia estricta en Consumidores**: Dado que el GIDI o los ORs pueden reenviar lotes ante fallos de red (at-least-once delivery), cada microservicio mantiene un almacén en memoria (Redis) de `eventId` procesados.
2. **CQRS (Command Query Responsibility Segregation)**:
   * *Capa de Escritura*: Ingesta masiva de lecturas procesadas a través de Kafka hacia bases de datos de series temporales (TimescaleDB).
   * *Capa de Lectura*: Vistas materializadas en PostgreSQL/Elasticsearch optimizadas para la App móvil del usuario.
3. **Schema Registry**: Validación automática de compatibilidad hacia atrás (*Backwards Compatibility*) de los esquemas Avro para evitar rupturas de contrato en los microservicios.
4. **Dead Letter Queue (DLQ)**: Si una lectura presenta inconsistencias incorregibles de formato, se desvía a `voltera.co.prod.telemetry.dlq.v1` para inspección de calidad sin bloquear el *pipeline* principal.

---

## 5. Plan de Ejecución de la PoC (Proof of Concept)

### 5.1 Alcance de la PoC
Demostrar la capacidad de la plataforma para:
1. Ingerir automáticamente un lote simulado de $10.000$ lecturas AMI diarias provenientes de un OR (Fase Transitoria) [21, 32].
2. Publicar las lecturas en el Event Mesh (Kafka).
3. Procesar en paralelo el reparto P2P para una Comunidad Energética con regla $PDE = 100\%$ [85].
4. Emitir la liquidación de la Factura Única Unificada aplicando tarifas CREG 101 072 de 2025 [51, 93, 113].

### 5.2 Atributos de Calidad a Medir
* **Escalabilidad**: Absorber el lote de $10.000$ lecturas en $< 30$ segundos.
* **Latencia de Procesamiento P2P**: Procesar cada evento de reparto en $p95 < 150\text{ ms}$ [119].
* **Seguridad Zero Trust**: Autenticación mTLS entre el adaptador y el bus Kafka con credenciales firmadas [120, 143].
