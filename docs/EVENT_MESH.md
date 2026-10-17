# Arquitectura y Guía Operativa del Event Mesh (Voltera)

Este documento detalla la arquitectura, el flujo de datos, los contratos de eventos y las instrucciones operativas del **Event Mesh Híbrido** implementado para la plataforma **Voltera** (Energytech, UniAndes ARTI4208).

---

## 1. Visión General del Event Mesh

El **Event Mesh** es la capa de transporte y enrutamiento desacoplada y orientada a eventos (*EDA - Event-Driven Architecture*) que conecta dos planos de ejecución:
1. **Edge / On-Premise (Subestaciones y Medidores Inteligentes AMI)**: Emula la infraestructura física de medición avanzada regulada bajo la **Resolución CREG 101-001 de 2022**.
2. **Cloud Core (Azure Kubernetes Service - AKS)**: Aloja el núcleo transaccional de Voltera (Facturación, Netting CREG 101-072 / 174, Comunidades Energéticas P2P y Pasarela de Pagos).

El estándar de interoperabilidad adoptado en todo el bus es **[CloudEvents v1.0 (CNCF)](https://cloudevents.io/)**, transmitido en **Binary HTTP Mode**.

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   ARQUITECTURA DEL EVENT MESH HÍBRIDO                                  │
└────────────────────────────────────────────────────────────────────────────────────────────────────────┘

    [ REGIÓN EDGE / ON-PREMISE ]                                  [ REGIÓN CLOUD: AZURE AKS ]
 ┌─────────────────────────────────┐                             ┌──────────────────────────────────────────────┐
 │ • Medidores AMI Inteligentes    │                             │                                              │
 │ • Generador de Carga k6         │                             │               Azure AKS Cluster              │
 │   (tests/01_smoke_test.js)      │                             │                                              │
 │ • Mock AMI Service (Go)         │                             │  ┌────────────────────────────────────────┐  │
 └────────────────┬────────────────┘                             │  │         Istio Ingress Gateway          │  │
                  │ CloudEvents v1.0                             │  │  (VirtualService: /events -> rewrite)  │  │
                  │ (HTTP Binary Mode)                           │  └───────────────────┬────────────────────┘  │
                  ▼                                              │                      │                       │
 ┌─────────────────────────────────┐                             │                      ▼                       │
 │      Knative OnPrem Broker      │                             │  ┌────────────────────────────────────────┐  │
 │      (namespace: voltera-onprem)│                             │  │     Knative Cloud Broker               │  │
 └────────────────┬────────────────┘                             │  │     (cloud-broker / ns: voltera)       │  │
                  │                                              │  └───────┬──────────────┬──────────────┬──┘  │
                  │ Knative Trigger                              │          │              │              │     │
                  │ (trigger-forward-ami-to-cloud)               │          │ Filter Type  │ Filter Type  │     │
                  ▼                                              │          ▼              ▼              ▼     │
      [ Internet / APIM Gateway ] ───────────────────────────────┼──────────┘              │              │     │
            http://<Ingress-IP>/events                           │                         │              │     │
                                                                 │                         ▼              │     │
                                                                 │ ┌──────────────────────────────┐       │     │
                                                                 │ │ Trigger: trigger-billing-ami │       │     │
                                                                 │ │ -> Subscriber: billing-svc   │       │     │
                                                                 │ └──────────────────────────────┘       │     │
                                                                 │                                        │     │
                                                                 │ ┌──────────────────────────────┐       │     │
                                                                 │ │ Trigger: trigger-logger-ami  │       │     │
                                                                 │ │ -> Subscriber: logger (aud.) │       │     │
                                                                 │ └──────────────────────────────┘       │     │
                                                                 │                                        ▼     │
                                                                 │ ┌──────────────────────────────────────────┐ │
                                                                 │ │ Trigger: trigger-payment-invoice         │ │
                                                                 │ │ -> Subscriber: payment-svc (/events)     │ │
                                                                 │ └──────────────────────────────────────────┘ │
                                                                 └──────────────────────────────────────────────┘
```

---

## 2. Catálogo y Especificación de CloudEvents

### 2.1 Evento de Telemetría: `com.voltera.ami.lectura_registrada`
* **Dominio**: Telemetría e Ingesta de Medición (AMI).
* **Productor**: Agentes Edge / Inversores / Mocks AMI (`mock-onprem`).
* **Consumidores**: 
  - `billing-service`: Para procesar balance energético y liquidación.
  - `cloud-event-logger`: Para auditoría y observabilidad en tiempo real.
* **Encabezados HTTP (CloudEvents Binary Mode)**:
  ```http
  Ce-Specversion: 1.0
  Ce-Type: com.voltera.ami.lectura_registrada
  Ce-Source: //onprem/medidores/ami-mock
  Ce-Id: evt-ami-1718000000000
  Ce-Time: 2026-10-12T20:00:00Z
  Content-Type: application/json
  ```
* **Payload de Ejemplo**:
  ```json
  {
    "niu": "1002345",
    "medidor_serie": "MTR-COL-8492",
    "timestamp_lectura": "2026-10-12T20:00:00Z",
    "intervalo": "MINUTOS_15",
    "kwh_importados": 14.25,
    "kwh_exportados": 3.80,
    "tension_voltios": 121.4
  }
  ```

---

### 2.2 Evento Transaccional: `com.voltera.billing.factura_generada`
* **Dominio**: Facturación y Liquidación Netting (Billing).
* **Productor**: `billing-service`.
* **Consumidor**: `payment-service` (Pasarela de pagos y dispersión de recaudos).
* **Encabezados HTTP**:
  ```http
  Ce-Specversion: 1.0
  Ce-Type: com.voltera.billing.factura_generada
  Ce-Source: //cloud/billing/engine
  Ce-Id: evt-inv-98213840
  Ce-Time: 2026-10-12T20:01:00Z
  Content-Type: application/json
  ```
* **Payload de Ejemplo**:
  ```json
  {
    "invoice_id": "INV-2026-004812",
    "niu": "1002345",
    "periodo": "2026-10",
    "total_cop": 145800.0,
    "kwh_netos": 10.45,
    "credito_exc1_kwh": 3.80,
    "status": "ISSUED"
  }
  ```

---

## 3. Componentes y Manifiestos en Kubernetes

Los manifiestos del mesh en la nube residen en `k8s/knative-event-mesh.yaml`.

| Recurso Kubernetes | Nombre | Namespace | Función Principal |
|---|---|---|---|
| **Broker** | `cloud-broker` | `voltera` | Bus multi-canal que recibe y desacopla todos los eventos en la nube. |
| **Gateway (Istio)** | `cloud-eventmesh-gateway` | `voltera` | Expone los puertos 80 (HTTP) y 443 (HTTPS con TLS 1.3 `voltera-ingress-cert`) del Ingress LoadBalancer. |
| **VirtualService (Istio)** | `cloud-broker-ingress` | `voltera` | Enruta peticiones a `/events` hacia `broker-ingress.knative-eventing.svc.cluster.local/voltera/cloud-broker`. |
| **Trigger** | `trigger-billing-ami` | `voltera` | Filtra `com.voltera.ami.lectura_registrada` y entrega al servicio `billing-service:8080/events`. |
| **Trigger** | `trigger-logger-ami` | `voltera` | Filtra `com.voltera.ami.lectura_registrada` y entrega al pod `cloud-event-logger`. |
| **Trigger** | `trigger-payment-invoice` | `voltera` | Filtra `com.voltera.billing.factura_generada` y entrega al servicio `payment-service:8081/events`. |
| **Deployment / Svc** | `cloud-event-logger` | `voltera` | Pod basado en `knative.dev/eventing/cmd/event_display` para inspeccionar el flujo de eventos. |

---

## 4. Guía Operativa: Cómo Probar el Event Mesh

### Paso 1: Conectarse al clúster AKS
Verifica que el clúster esté iniciado (ver guía [FinOps](file:///d:/uniandes_local/nuevagen/docs/FINOPS_AKS.md)) y conecta tu CLI:
```powershell
az aks get-credentials --resource-group rg-voltera-dev --name voltera-dev-aks --overwrite-existing
kubectl get nodes
```

### Paso 2: Aplicar la Infraestructura del Event Mesh
Asegúrate de que los manifiestos base y el mesh estén aplicados en el namespace `voltera`:
```powershell
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/billing.yaml
kubectl apply -f k8s/payment.yaml
kubectl apply -f k8s/knative-event-mesh.yaml
```

Verifica el estado del Broker y los Triggers:
```powershell
kubectl get broker,trigger -n voltera
```
*(Todos deben reportar `READY=True`)*.

### Paso 3: Obtener el Dominio Oficial de Azure (o IP Pública) del Ingress
Azure asigna un FQDN oficial gratuito a través del servicio LoadBalancer:
* **Dominio Oficial Azure**: `voltera-dev-mesh.eastus2.cloudapp.azure.com`
* **IP Pública**:
  ```powershell
  $INGRESS_HOST = "voltera-dev-mesh.eastus2.cloudapp.azure.com"
  # O consultar IP directamente si se requiere:
  $INGRESS_IP = kubectl get svc istio-ingress -n istio-system -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
  ```
*(Si usas el entorno local k3s, utiliza `localhost:8090`)*.

### Paso 4: Monitorear el Consumidor de Eventos (Event Display Logger)
Abre una terminal secundaria para ver cómo entran los eventos en tiempo real:
```powershell
kubectl logs -n voltera -l app=cloud-event-logger -f --tail=50
```

### Paso 5: Emitir Lecturas AMI desde el Simulador

#### Opción A: Usando la suite de pruebas k6 (`tests/01_smoke_test.js`)
Desde la carpeta raíz (vía canal seguro HTTPS hacia el dominio oficial de Azure):
```powershell
# Enviar lecturas AMI vía dominio oficial Azure AKS
k6 run tests/01_smoke_test.js -e TARGET_URL="https://voltera-dev-mesh.eastus2.cloudapp.azure.com/events" -e COUNT=3 -e SLEEP=1.0
```

#### Opción B: Usando `curl` directamente sobre HTTPS
```bash
curl -k -X POST "https://voltera-dev-mesh.eastus2.cloudapp.azure.com/events" \
  -H "Ce-Specversion: 1.0" \
  -H "Ce-Type: com.voltera.ami.lectura_registrada" \
  -H "Ce-Source: //manual/test/curl" \
  -H "Ce-Id: evt-manual-tls-001" \
  -H "Ce-Time: 2026-10-14T20:00:00Z" \
  -H "Content-Type: application/json" \
  -d '{"niu": "1002345", "medidor_serie": "MTR-TEST-TLS", "kwh_importados": 12.5, "kwh_exportados": 4.1}'
```

### Paso 6: Validar la Recepción en los Servicios
1. En los logs de `cloud-event-logger` verás el CloudEvent completo formateado por `event_display`:
   ```text
   ☁️  cloudevents.Event
   Validation: valid
   Context Attributes,
     specversion: 1.0
     type: com.voltera.ami.lectura_registrada
     source: //onprem/medidores/ami-mock
     id: evt-ami-1792031544954-559
   Data,
     { "niu": "1002345", "kwh_importados": 14.25, ... }
   ```
2. En los logs del microservicio de facturación:
   ```powershell
   kubectl logs -n voltera -l app=billing-service -f
   ```

---

## 5. Resiliencia, Observabilidad y Patrones de Seguridad
* **Seguridad Perimetral e Inter-Clúster (TLS 1.3 / HTTPS)**: El Ingress Gateway de Istio (`cloud-eventmesh-gateway`) expone el puerto `443` con terminación TLS (`credentialName: voltera-ingress-cert`). El tráfico transita 100% cifrado a través de Internet entre la región On-Premise y AKS. En el clúster local K3s, el `Trigger` ([`mock-onprem/k8s/trigger-to-cloud.yaml`](file:///d:/uniandes_local/nuevagen/mock-onprem/k8s/trigger-to-cloud.yaml)) incluye el certificado CA para validación estricta de confianza.
* **Seguridad Intra-Clúster (mTLS STRICT)**: Una vez que el evento cruza el Gateway, los sidecars Envoy de Istio aplican mTLS estricto (`istio-auth-policy.yaml`) pod-a-pod dentro del namespace `voltera`.
* **Desacoplamiento Temporal**: Si `billing-service` o `payment-service` se caen o están escalando, el Knative Broker retiene y reintenta la entrega según la política de backoff.
* **Escalado Serverless**: Si la tasa de telemetría de medidores crece durante la noche, Knative Serving y KEDA pueden escalar los consumidores desde 0 hasta el límite de capacidad de cómputo del clúster.

---

## 6. Observabilidad y Trazabilidad en Azure Application Insights (FinOps)

El clúster integra un pipeline de trazabilidad distribuida para auditar el ciclo de vida completo de cada CloudEvent en **Azure Application Insights** sin incurrir en costos adicionales de cómputo o almacenamiento.

### 6.1 Arquitectura del Pipeline de Telemetría
1. **Istio Ingress Gateway**: Recibe el CloudEvent externo y le asigna o propaga un W3C `traceparent` (`00-<trace_id>-<span_id>-01`).
2. **Knative Eventing (`cloud-broker`)**: Configurado con `backend: zipkin` en `knative-eventing/config-tracing`, emite spans al enrutar eventos hacia los Triggers.
3. **Microservicios (`billing-service`, `payment-service`)**: Extraen el `traceparent` entrante, emiten un span con dimensiones de negocio (`ce.id`, `voltera.niu`, `voltera.invoice_id`, `voltera.total_cop`) y propagan el contexto en la respuesta asíncrona hacia el Broker y en llamadas síncronas.
4. **OpenTelemetry Collector (`istio-system/otel-collector`)**:
   - Recibe spans en `:9411` (Zipkin) y `:4317/:4318` (OTLP).
   - **Filtro FinOps**: Descarta en memoria todas las peticiones a `/health`, `/stats`, `/readyz` y `/metrics`. Solo transmite eventos reales del Event Mesh.
   - **Exportador**: Agrupa en lotes y exporta a Application Insights vía `azuremonitor` exporter.

### 6.2 Despliegue de la Observabilidad
Para desplegar o actualizar el pipeline de trazas en AKS:
```powershell
pwsh .\k8s\monitoring\deploy-appinsights.ps1
```

### 6.3 Consultas KQL de Utilidad en Application Insights
En el recurso `voltera-dev-appinsights` (sección *Logs*):

#### Ver flujo completo de eventos por TraceID:
```kql
union requests, dependencies
| where operation_Id == "<trace-id>"
| project timestamp, itemType, name, customDimensions["voltera.niu"], customDimensions["voltera.invoice_id"], duration, success
| order by timestamp asc
```

#### Consultar facturas y pagos procesados a través del Event Mesh:
```kql
requests
| where customDimensions["voltera.event"] in ("ami.lectura_registrada", "billing.factura_generada")
| project timestamp, name, 
    NIU = customDimensions["voltera.niu"], 
    Invoice = customDimensions["voltera.invoice_id"], 
    TotalCOP = customDimensions["voltera.total_cop"], 
    Txn = customDimensions["voltera.transaction_id"],
    duration, resultCode
| order by timestamp desc
```

