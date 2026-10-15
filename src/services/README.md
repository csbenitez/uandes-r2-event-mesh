# Microservicios Transaccionales de Voltera (Go)

Este directorio aloja la implementación en **Go 1.22** de los microservicios transaccionales de **Voltera**, diseñados bajo una arquitectura orientada a eventos (**Event-Driven Architecture**) y preparados para operar dentro de un **Service Mesh (Istio)** con soporte dual para invocaciones síncronas REST y asíncronas vía **CloudEvents v1.0**.

---

## 🏛️ 1. Arquitectura de Servicios y Canales de Comunicación

```mermaid
flowchart TD
    subgraph KnativeEventMesh["Canal Asincrono: Knative Event Mesh (CloudEvents)"]
        Broker["Knative Cloud Broker"]
        TrigAMI["Trigger: trigger-billing-ami<br/>com.voltera.ami.lectura_registrada"]
        TrigInvoice["Trigger: trigger-payment-invoice<br/>com.voltera.billing.factura_generada"]
        
        Broker --> TrigAMI
        Broker --> TrigInvoice
    end

    subgraph BillingServiceBox["Microservicio: billing-service (:8080)"]
        BillingEvents["Handler /events<br/>(Consumidor CloudEvents)"]
        BillingSync["Handler /invoice<br/>(API REST Sincrona)"]
        BillingHealth["Handler /health<br/>(K8s Liveness/Readiness)"]
        BillingCore["Motor de Liquidacion Netting<br/>• Resolucion CREG 101-072 de 2025<br/>• Permuta Exc1 (1 a 1)<br/>• Venta Exc2 al costo Mc"]
    end

    subgraph PaymentServiceBox["Microservicio: payment-service (:8081)"]
        PaymentEvents["Handler /events<br/>(Consumidor CloudEvents)"]
        PaymentSync["Handler /process<br/>(API REST Sincrona)"]
        PaymentHealth["Handler /health<br/>(K8s Liveness/Readiness)"]
        PaymentCore["Motor de Cobro y Dispersion<br/>• Pasarela de Recaudo (PSE/BPS)<br/>• Dispersion de Saldos a Favor"]
    end

    TrigAMI -->|POST /events| BillingEvents
    BillingEvents --> BillingCore
    BillingCore -.->|Event Reply:<br/>com.voltera.billing.factura_generada| Broker
    TrigInvoice -->|POST /events| PaymentEvents
    PaymentEvents --> PaymentCore

    BillingSync -->|Llamada REST con Istio mTLS Cifrado| PaymentSync
```

---

## 📊 2. Modelos de Datos y Estructuras (Go Types)

```mermaid
classDiagram
    class AMILectura {
        +string NIU
        +string MedidorSerie
        +string TimestampLectura
        +string Intervalo
        +float64 KwhImportados
        +float64 KwhExportados
        +float64 TensionVoltios
    }

    class FacturaGenerada {
        +string InvoiceID
        +string NIU
        +string Periodo
        +float64 TotalCOP
        +float64 KwhNetos
        +float64 CreditoExc1Kwh
        +string Status
    }

    class InvoiceRequest {
        +string AccountID
        +float64 Total
    }

    class InvoiceResponse {
        +string InvoiceID
        +string Status
        +string PaymentStatus
    }

    class PaymentRequest {
        +string AccountID
        +float64 Amount
    }

    class PaymentResponse {
        +string Status
        +string TransactionID
        +string Message
    }

    AMILectura --> FacturaGenerada : Procesa Netting CREG 101-072
    InvoiceRequest --> PaymentRequest : Invocacion Directa REST
    PaymentRequest --> PaymentResponse : Retorno Transaccional
```

---

## ⚡ 3. Endpoints Expuestos por los Microservicios

### 3.1 `billing-service` (Puerto :8080)
* **`POST /events`**: Endpoint para recepción de CloudEvents desde Knative (`com.voltera.ami.lectura_registrada`).
  - Aplica la fórmula de Netting:
    $$\text{NetKWh} = \text{KwhImportados} - \text{KwhExportados}$$
  - Si $\text{NetKWh} > 0$, liquida a tarifa estándar (850 COP/kWh).
  - Si $\text{NetKWh} \le 0$, aplica cargo mínimo de comercialización ($C_v$).
  - Emite automáticamente el CloudEvent `com.voltera.billing.factura_generada` como respuesta al Broker (Knative Eventing Reply pattern).
* **`POST /invoice`**: Endpoint REST tradicional síncrono. Emite una factura e invoca directamente a `payment-service:8081/process` a través del sidecar de Istio con mTLS.
* **`GET /health`**: Endpoint de diagnóstico de salud (`{"status": "healthy"}`).

### 3.2 `payment-service` (Puerto :8081)
* **`POST /events`**: Endpoint para recepción de CloudEvents de facturas emitidas (`com.voltera.billing.factura_generada`). Simula el cobro bancario o dispersión masiva de fondos al prosumidor.
* **`POST /process`**: Endpoint REST síncrono para procesar pagos bajo demanda.
* **`GET /health`**: Probe de salud para Kubernetes.

---

## 🐳 4. Compilación y Ejecución Local

Para compilar y correr localmente los servicios:
```powershell
# Iniciar payment-service
cd src\services\payment-service
go run main.go

# En otra terminal, iniciar billing-service
cd src\services\billing-service
go run main.go
```
