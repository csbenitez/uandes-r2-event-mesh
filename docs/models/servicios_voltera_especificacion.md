# Especificación de Microservicios: Arquitectura de Voltera Energytech

## 1. Visión General de la Arquitectura de Servicios

La plataforma **Voltera** opera como una comercializadora digital de energía (*energytech*) basada en una arquitectura de microservicios orientada a eventos (**Event-Driven Architecture**). Cada microservicio delimita su propio **Bounded Context**, manteniendo su propio modelo de dominio, almacenamiento de datos desacoplado e interfaces bien definidas para comunicarse asíncronamente mediante un **Event Mesh** (Apache Kafka) y APIs síncronas REST/gRPC.

```
                          ┌──────────────────────────────────────────────────────────┐
                          │                   EVENT MESH (KAFKA)                     │
                          └─────────────▲──────────────────────────────▲─────────────┘
                                        │                              │
             ┌──────────────────────────┴──────────┐        ┌──────────┴──────────────────────────┐
             │                                     │        │                                     │
┌────────────┴─────────────┐            ┌──────────┴────────┴──────┐           ┌──────────────────┴────────┐
│ TelemetryIngestionService│            │   P2PMatchingService     │           │  BillingSettlementService │
│ (Ingesta Multi-OR/GIDI)  │            │  (Motor P2P y Comunidades)│           │ (Facturación Net-Metering)│
└──────────────────────────┘            └──────────────────────────┘           └───────────────────────────┘
```

---

## 2. Catálogo de Microservicios

### 2.1 Servicio de Ingesta e Interoperabilidad de Medición (`TelemetryIngestionService`)

* **Descripción Funcional**: 
  Responsable de descargar, descomprimir y validar las lecturas de los medidores avanzados (AMI) en intervalos de 15 minutos u horarios. En la **fase de transición** en Colombia, actúa como una Capa Anti-Corrupción (**ACL**) conectándose a los portales y API Gateways de cada Operador de Red (Enel, EPM, Celsia, etc.), aplicando filtros VEE (Validación, Edición y Estimación) y estandarizando los formatos heterogéneos antes de inyectarlos al bus de eventos.

* **INPUT (Entradas Probables)**:
  * Archivos comprimidos por lotes diarios (formatos Parquet, CSV, XML) o peticiones REST/gRPC enviadas por el GIDI/OR.
  * *Payload de entrada (Lote/Stream)*:
    ```json
    {
      "niu": "98234710",
      "medidorSerie": "AMT-2026-009812",
      "orOrigen": "ENEL_BOGOTA",
      "timestampLectura": "2026-09-28T12:15:00Z",
      "intervaloMinutos": 15,
      "importacionKWh": 0.0,
      "exportacionKWh": 3.8,
      "tensionVoltios": 120.5,
      "estadoOR": "OK"
    }
    ```

* **OUTPUT (Salidas Probables)**:
  * Evento inmutable de dominio publicado en Apache Kafka: `voltera.co.prod.telemetry.ami-reading-received.v1`.
  * *Payload del Evento publicado*:
    ```json
    {
      "eventId": "evt-8f92a34b-1234-4567-89ab-cdef01234567",
      "eventType": "LecturaAMIRegistrada",
      "timestamp": "2026-09-28T08:00:00Z",
      "data": {
        "niu": "98234710",
        "medidorSerie": "AMT-2026-009812",
        "importacionKWh": 0.0,
        "exportacionKWh": 3.8,
        "estadoVEE": "VALIDADA"
      }
    }
    ```

---

### 2.2 Motor de Emparejamiento P2P y Comunidades (`P2PMatchingService`)

* **Descripción Funcional**: 
  Ejecuta el algoritmo de cruce de oferta y demanda de energía en tiempo real o por intervalos de 15 minutos. Identifica prosumidores con excedentes inyectados y los empareja con el consumo de sus vecinos o miembros de una **Comunidad Energética (Autogeneración Colectiva - AC)**. Aplica de manera estricta la matriz del **Porcentaje de Distribución de Excedentes (PDE)** regulada por la CREG 101 072 de 2025, garantizando que $\sum PDE = 100\%$.

* **INPUT (Entradas Probables)**:
  * Eventos `LecturaAMIRegistrada` consumidos desde Kafka.
  * Consulta al Agregado `ComunidadEnergética` (listado de $NIU$ asociados al RUCE, matrices $PDE$ activas y tipo de frontera).

* **OUTPUT (Salidas Probables)**:
  * Evento de negocio publicado en Kafka: `voltera.co.prod.community.pde-allocated.v1`.
  * *Payload del Evento publicado*:
    ```json
    {
      "eventId": "evt-3c11b89a-5678-90ef-12ab-34cd567890ef",
      "eventType": "ExcedenteP2PAsignado",
      "timestamp": "2026-09-28T08:02:15Z",
      "data": {
        "comunidadId": "com-sol-andina",
        "codigoRUCE": "CE-2025-00412",
        "generadorNIU": "98234710",
        "excedenteTotalKWh": 3.8,
        "asignaciones": [
          {"beneficiarioNIU": "98234711", "kwhAsignados": 2.28, "pdeAplicado": 60.0},
          {"beneficiarioNIU": "98234712", "kwhAsignados": 1.52, "pdeAplicado": 40.0}
        ],
        "sobranteRedKWh": 0.0
      }
    }
    ```

---

### 2.3 Servicio de Liquidación y Facturación Net-Metering (`BillingSettlementService`)

* **Descripción Funcional**: 
  Encargado del cierre contable y tarifario mensual para cada usuario. Acumula las lecturas del mes, clasifica los excedentes en Permuta 1:1 ($Exc_1$) y Venta ($Exc_2$), aplica las fórmulas tarifarias vigentes ($CU_v, C_v, M_c$) según la CREG 101 072 de 2025 y calcula el balance neto final ($VE$). Genera la Factura Única Unificada digital.

* **INPUT (Entradas Probables)**:
  * Eventos acumulados del ciclo mensual: `LecturaAMIRegistrada` (importación $Imp$) y `ExcedenteP2PAsignado` ($ExcAC_u$).
  * Objeto `EstructuraTarifaria` (valores mensuales de $CU_v, C_v, M_c$ para el mercado de comercialización correspondiente).

* **OUTPUT (Salidas Probables)**:
  * Evento publicado en Kafka: `voltera.co.prod.billing.invoice-settled.v1`.
  * Documento e historial del Agregado `FacturaEnergia` (factura unificada en PDF/JSON).
  * *Payload de la Liquidación emitida*:
    ```json
    {
      "facturaId": "fac-2026-09-98234710",
      "niu": "98234710",
      "periodo": "2026-09",
      "importacionKWh": 200.0,
      "exportacionTotalKWh": 300.0,
      "exc1PermutadoKWh": 200.0,
      "exc2SobranteKWh": 100.0,
      "subtotalEnergiaCOP": 0.0,
      "costoComercializacionCvCOP": 14000.0,
      "ingresoVentaExc2COP": -35000.0,
      "valorTotalFacturaVE": -21000.0,
      "estadoSaldo": "A_FAVOR_DEL_PROSUMIDOR"
    }
    ```

---

### 2.4 Servicio de Certificados de Origen Renovable Blockchain (`RenewableCertificateService`)

* **Descripción Funcional**: 
  Funciona como oráculo y gestor de tokens en la blockchain de Voltera. Garantiza la trazabilidad e inmutabilidad de la energía verde (FNCER). Emite (*mint*) un certificado digital por cada kWh solar producido, gestiona la transferencia P2P hacia las cuentas de los vecinos y destruye (*burn*) el token al momento de ser redimido en la factura mensual para evitar el doble conteo.

* **INPUT (Entradas Probables)**:
  * Evento `LecturaAMIRegistrada` (con confirmación de generación FNCER).
  * Evento `ExcedenteP2PAsignado` o `FacturaProcesada`.

* **OUTPUT (Salidas Probables)**:
  * Transacción On-Chain con hash de auditoría.
  * Evento publicado en Kafka: `voltera.co.prod.blockchain.certificate-burned.v1`.
  * *Payload de Certificado Redimido*:
    ```json
    {
      "certificateId": "cert-20260928-0012983",
      "transactionHash": "0x7f9a8b...3c12d",
      "niuGenerador": "98234710",
      "niuConsumidor": "98234711",
      "kwhCertificados": 2.28,
      "estado": "BURNED_AND_REDEEMED",
      "timestamp": "2026-09-28T08:05:00Z"
    }
    ```

---

### 2.5 Servicio de Telemetría e Ingesta DERs / IoT (`DERIoTService`)

* **Descripción Funcional**: 
  Módulo de baja latencia para comunicación bidireccional directa con dispositivos energéticos distribuidos (DERs): inversores solares, sistemas de almacenamiento BESS (baterías) y cargadores de vehículos eléctricos. Utiliza protocolos livianos como MQTT y WebSockets para monitoreo en tiempo real y envío de señales de control de respuesta a la demanda.

* **INPUT (Entradas Probables)**:
  * Mensajes MQTT en tiempo real publicados por los microinversores o controladores IoT de las viviendas.
  * *Payload IoT*:
    ```json
    {
      "deviceId": "inv-solis-9021",
      "niu": "98234710",
      "timestamp": "2026-09-28T12:15:02Z",
      "dcPowerWatts": 4200,
      "acPowerWatts": 4050,
      "batteryStateOfCharge": 85.0
    }
    ```

* **OUTPUT (Salidas Probables)**:
  * Evento de telemetría IoT publicado en Kafka: `voltera.co.prod.telemetry.der-status.v1`.
  * Métricas push a la App móvil para visualización de curva de generación en tiempo real.

---

### 2.6 Servicio de Clientes e Identidad (`CustomerIdentityService` - IAM)

* **Descripción Funcional**: 
  Gestiona la identidad de los usuarios bajo una postura **Zero Trust**, la vinculación de fronteras comerciales ($NIU$), el registro en el Registro Único de Comunidades Energéticas (RUCE) y las solicitudes digitales de cambio de comercializador enviadas al GIDI o al OR.

* **INPUT (Entradas Probables)**:
  * Solicitud de Onboarding / Cambio de comercializador desde la App móvil.
  * Datos del contrato digital aceptado.

* **OUTPUT (Salidas Probables)**:
  * Agregado `CuentaUsuario` y `FronteraComercial` actualizados.
  * Petición API saliente dirigida al GIDI: `POST /v1/comercializadores/cambio-frontera`.

---

### 2.7 Servicio de Pagos y Dispersión Bancaria (`PaymentSettlementService`)

* **Descripción Funcional**: 
  Gestiona la pasarela de recaudo para usuarios que tengan saldo a pagar y la dispersión masiva de dinero a cuentas bancarias (vía BPS/PSE/Transferencia) para prosumidores con saldos a favor acumulados por venta de excedentes ($Exc_2$).

* **INPUT (Entradas Probables)**:
  * Evento `FacturaEmitida` con saldo positivo (cobro) o negativo (saldo a favor).
  * Solicitud de retiro de fondos emitida por el prosumidor desde la App.

* **OUTPUT (Salidas Probables)**:
  * Peticiones API a pasarelas bancarias.
  * Evento publicado en Kafka: `voltera.co.prod.payments.settlement-executed.v1`.

---

## 3. Matriz Resumen de Interacciones entre Microservicios

| Microservicio | Frecuencia de Ejecución | Entrada Principal | Salida Principal | Protocolo Predominante |
| :--- | :--- | :--- | :--- | :--- |
| **`TelemetryIngestionService`** | Diaria / Lotes (8:00 AM) | Lote AMI del OR/GIDI | `LecturaAMIRegistrada` | HTTP REST / Kafka |
| **`P2PMatchingService`** | Cada 15 min / Horario | `LecturaAMIRegistrada` + Matriz $PDE$ | `ExcedenteP2PAsignado` | Kafka Event Stream |
| **`BillingSettlementService`** | Mensual / Por Ciclo | Eventos acumulados de $Imp$ y $P2P$ | `FacturaEnergia` ($VE$) | Kafka / PostgreSQL |
| **`RenewableCertificateService`** | Por Inyección / Liquidación | $kWh$ inyectados + Asignación P2P | Hash Blockchain (Mint/Burn) | gRPC / Smart Contract |
| **`DERIoTService`** | Segundos (Tiempo Real) | Telemetría Inversores/Baterías | Métricas Real-time App | MQTT / WebSockets |
| **`CustomerIdentityService`** | Bajo Demanda / Trámites | Solicitud App / Registro NIU | Solicitud de Cambio de Comercializador | REST API / OAuth2 |
| **`PaymentSettlementService`** | Mensual / Bajo Demanda | Saldo $VE$ o retiro de prosumidor | Dispersión Bancaria | REST API / ACH |
