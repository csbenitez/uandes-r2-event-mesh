# Manifiestos de Kubernetes y Event Mesh (Región Cloud - AKS)

Esta carpeta contiene los manifiestos declarativos de Kubernetes para desplegar el núcleo transaccional de **Voltera** en la nube (Azure AKS o K3s), integrando **Istio Service Mesh** para seguridad Zero Trust y **Knative Eventing** para el enrutamiento desacoplado de CloudEvents.

---

## 🏛️ 1. Arquitectura de Despliegue y Seguridad Zero Trust

Todos los microservicios se despliegan en el namespace `voltera` con inyección automática de sidecar Envoy (`istio-injection: enabled`) y cifrado mutuo obligatorio (`PeerAuthentication mode: STRICT`):

```mermaid
flowchart TD
    subgraph K8sNamespace["Namespace: voltera (Istio Injection: enabled)"]
        
        subgraph PodBilling["Pod: billing-service"]
            EnvoyB["Envoy Sidecar Proxy<br/>(mTLS STRICT)"]
            ContBilling["Contenedor: billing-service<br/>(Go :8080)<br/>Probes: /health"]
            EnvoyB <--> ContBilling
        end

        subgraph PodPayment["Pod: payment-service"]
            EnvoyP["Envoy Sidecar Proxy<br/>(mTLS STRICT)"]
            ContPayment["Contenedor: payment-service<br/>(Go :8081)<br/>Probes: /health"]
            EnvoyP <--> ContPayment
        end

        subgraph PodLogger["Pod: cloud-event-logger"]
            EnvoyL["Envoy Sidecar Proxy<br/>(mTLS STRICT)"]
            ContLogger["Contenedor: event_display<br/>(Auditoria stdout)"]
            EnvoyL <--> ContLogger
        end

        PolicyZeroTrust["Politica Istio: PeerAuthentication<br/>(mode: STRICT)"]
    end

    subgraph ServiceMeshNetwork["Red Interna del Cluster"]
        SvcBilling["Kubernetes Service: billing-service:8080"]
        SvcPayment["Kubernetes Service: payment-service:8081"]
        SvcLogger["Kubernetes Service: cloud-event-logger:80"]
    end

    SvcBilling --> EnvoyB
    SvcPayment --> EnvoyP
    SvcLogger --> EnvoyL
    PolicyZeroTrust -.->|Aplica mTLS criptografico obligatorio| K8sNamespace
```

---

## 📡 2. Topología de Knative Eventing en Kubernetes

El archivo `knative-event-mesh.yaml` orquesta el enrutamiento de eventos mediante un Broker central y Triggers filtrados:

```mermaid
flowchart LR
    IngressRequest["Petición HTTP Externa<br/>POST /events<br/>(Ce-Type: com.voltera.ami.lectura_registrada)"] --> Gateway["Istio Ingress Gateway<br/>(cloud-eventmesh-gateway)"]

    Gateway --> VS["VirtualService: cloud-broker-ingress<br/>Rewrite: /events -> /voltera/cloud-broker"]

    subgraph KnativeCore["Knative Eventing Data Plane (Envoy Sidecars mTLS)"]
        VS --> IngressPod["mt-broker-ingress<br/>(Sidecar 2/2)"]
        IngressPod --> IMCPod["imc-dispatcher<br/>(Sidecar 2/2)"]
        IMCPod --> FilterPod["mt-broker-filter<br/>(Sidecar 2/2)"]
        
        FilterPod --> T1["Trigger: trigger-billing-ami<br/>Filtro: ami.lectura_registrada"]
        FilterPod --> T2["Trigger: trigger-logger-ami<br/>Filtro: ami.lectura_registrada"]
        FilterPod --> T3["Trigger: trigger-payment-invoice<br/>Filtro: billing.factura_generada"]
    end

    subgraph ServicesSubscribers["Namespace voltera (Zero Trust mTLS STRICT)"]
        T1 -->|POST /events| Billing["billing-service:8080<br/>(Sidecar 2/2)"]
        T2 -->|POST /| Logger["cloud-event-logger:80<br/>(Sidecar 2/2)"]
        T3 -->|POST /events| Payment["payment-service:8081<br/>(Sidecar 2/2)"]
    end

    Billing -.->|Knative Event Reply<br/>com.voltera.billing.factura_generada| IngressPod
```

---

## 🔄 3. Comparativa: Comunicación Asíncrona (Event Mesh) vs Síncrona (REST)

```mermaid
sequenceDiagram
    autonumber
    participant Client as Cliente Externo / Edge AMI
    participant IstioGW as Istio Ingress Gateway
    participant Broker as Knative Cloud Broker
    participant Billing as billing-service
    participant Payment as payment-service

    Note over Client, Payment: Ruta A: Asincrona Desacoplada (Event Mesh)
    Client->>IstioGW: POST /events (CloudEvent: lectura_registrada)
    IstioGW->>Broker: Envia evento al Broker
    Broker-->>IstioGW: HTTP 202 Accepted
    IstioGW-->>Client: HTTP 202 Accepted (No bloquea al emisor)
    Broker->>Billing: Despacha evento via Trigger (/events)
    Note over Billing: Calcula Netting CREG 101-072
    Billing-->>Broker: Reply CloudEvent: factura_generada
    Broker->>Payment: Despacha evento de factura via Trigger (/events)

    Note over Client, Payment: Ruta B: Sincrona Directa con Istio Service Mesh
    Client->>Billing: POST /invoice (Generar factura inmediata)
    Note over Billing: billing-service necesita procesar el pago de inmediato
    Billing->>Payment: POST http://payment-service:8081/process
    Note over Billing, Payment: Cifrado mTLS automatico y transparente via Envoy Sidecars
    Payment-->>Billing: HTTP 200 OK {"status": "SUCCESS"}
    Billing-->>Client: HTTP 200 OK {"invoice_id": "INV-...", "status": "ISSUED"}
```

---

## 📋 4. Catálogo de Manifiestos

| Archivo | Tipo de Recurso(s) | Función Principal |
|---|---|---|
| [`namespace.yaml`](file:///d:/uniandes_local/nuevagen/k8s/namespace.yaml) | `Namespace` | Crea el espacio de nombres `voltera` y habilita `istio-injection: enabled`. |
| [`istio-auth-policy.yaml`](file:///d:/uniandes_local/nuevagen/k8s/istio-auth-policy.yaml) | `PeerAuthentication` | Fuerza mTLS estricto (`mode: STRICT`) en todo el tráfico del namespace. |
| [`knative-event-mesh.yaml`](file:///d:/uniandes_local/nuevagen/k8s/knative-event-mesh.yaml) | `Broker`, `Trigger`, `Gateway`, `VirtualService`, `Deployment`, `Service` | Define el Broker de la nube, los 3 Triggers de enrutamiento, el pod logger y la regla de Ingress. |
| [`billing.yaml`](file:///d:/uniandes_local/nuevagen/k8s/billing.yaml) | `Deployment`, `Service` | Despliega el microservicio de facturación con liveness y readiness probes en `/health`. |
| [`payment.yaml`](file:///d:/uniandes_local/nuevagen/k8s/payment.yaml) | `Deployment`, `Service` | Despliega el microservicio de pagos y pasarela con probes de salud en `:8081/health`. |

---

## 🚀 5. Instrucciones de Despliegue

### Aplicar los manifiestos en orden:
```powershell
# 1. Namespace con inyeccion de Istio
kubectl apply -f k8s/namespace.yaml

# 2. Politica Zero Trust (mTLS STRICT)
kubectl apply -f k8s/istio-auth-policy.yaml

# 3. Microservicios transaccionales
kubectl apply -f k8s/billing.yaml
kubectl apply -f k8s/payment.yaml

# 4. Capa de Event Mesh e Ingress
kubectl apply -f k8s/knative-event-mesh.yaml
```

### Verificar el estado del despliegue:
```powershell
# Verificar pods y sidecars inyectados (2/2 ready)
kubectl get pods -n voltera

# Verificar Broker y Triggers de Knative
kubectl get broker,trigger -n voltera

# Monitorear logs del Event Display Logger
kubectl logs -n voltera -l app=cloud-event-logger -f
```
