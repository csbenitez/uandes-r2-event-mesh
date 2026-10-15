# Entorno Local K3s (k3d en Docker) para Simulación Edge / On-Premise

Este módulo proporciona un entorno Kubernetes ligero (**K3s**) ejecutado localmente sobre **k3d dentro de Docker Desktop**, diseñado para:
1. **Simular la Región On-Premise / Edge**: Emular subestaciones y concentradores de medición avanzada (AMI) sin costo alguno en la nube.
2. **Desarrollo Desconectado**: Probar microservicios, el Service Mesh (Istio) y el Event Mesh (Knative) en tu estación de trabajo sin incurrir en consumo de créditos.

---

## 🏛️ 1. Arquitectura del Clúster Local en Docker

El clúster local deshabilita el ingress por defecto de K3s (Traefik) para ceder el control de puertos al **Istio Ingress Gateway**:

```mermaid
flowchart TD
    subgraph Host["Estación de Trabajo Local (Windows / Linux / macOS)"]
        Browser["Navegador / cURL<br/>http://localhost:8090"]
        K6Sim["Generador y Carga k6<br/>(tests/01_smoke_test.js)"]
        KubectlClient["kubectl CLI<br/>(Contexto: k3d-voltera-onprem)"]
        
        subgraph DockerEngine["Docker Desktop Runtime"]
            
            subgraph K3dCluster["Contenedor: k3d-voltera-onprem (K3s Server)"]
                
                subgraph PortForwarding["Mapeo de Puertos Host -> Contenedor"]
                    P8090["Puerto 8090 -> 80 (HTTP Ingress)"]
                    P8443["Puerto 8443 -> 443 (HTTPS Ingress)"]
                    P6550["Puerto 6550 -> 6443 (Kubernetes API)"]
                end

                subgraph MeshEdgeNamespace["Namespace: voltera-onprem (Istio Injection)"]
                    BrokerLocal["Knative Broker Local<br/>(onprem-broker)"]
                    MockService["Mock AMI Service (Go)<br/>(puerto 8080)"]
                    TriggerCloud["Trigger Knative<br/>(trigger-forward-ami-to-cloud)"]
                end

            end

        end

    end

    subgraph ExternalCloud["Región Cloud Externa (Azure AKS)"]
        CloudGateway["Istio Ingress Gateway Cloud<br/>http://<INGRESS_IP>/events"]
    end

    Browser --> P8090
    KubectlClient --> P6550
    K6Sim -->|POST CloudEvents| P8090
    P8090 --> MockService
    MockService --> BrokerLocal
    BrokerLocal --> TriggerCloud
    TriggerCloud -->|Reenvío seguro por Internet| CloudGateway
```

---

## ⚡ 2. Ciclo de Vida del Clúster Local

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Desarrollador
    participant Manager as manage.ps1
    participant Docker as Docker Desktop
    participant K3d as k3d CLI
    participant Addons as install.ps1

    Dev->>Manager: pwsh manage.ps1 local start
    Manager->>Docker: Verifica que Docker Desktop esté en ejecución
    Manager->>K3d: k3d cluster create voltera-onprem (--disable=traefik)
    K3d->>Docker: Levanta contenedor k3s con puertos 8090, 8443 y 6550
    Manager->>Dev: Contexto de kubectl configurado en 'k3d-voltera-onprem'
    
    Dev->>Manager: pwsh manage.ps1 local addons
    Manager->>Addons: Despliega Istio Minimal, Knative y KEDA
    Note over Dev: Clúster local 100% operativo para pruebas de Edge
    
    Note over Dev: Finalización de Pruebas
    Dev->>Manager: pwsh manage.ps1 local stop (Pausar) o delete (Eliminar)
    Manager->>K3d: Detiene contenedores y libera memoria RAM del sistema
```

---

## 📋 3. Requisitos Previos

| Herramienta | Versión Recomendada | Comando de Instalación (Windows) |
|---|---|---|
| **Docker Desktop** | 4.30+ | [Descargar de docker.com](https://www.docker.com/products/docker-desktop/) |
| **k3d** | v5.6+ | `winget install k3d.k3d` |
| **kubectl** | v1.30+ | `winget install Kubernetes.kubectl` |
| **Helm** | v3.14+ | `winget install Helm.Helm` |

---

## 🚀 4. Guía Operativa

### Paso 1: Iniciar el Clúster Local
Desde la raíz del repositorio o dentro de `infra/`:
```powershell
pwsh .\infra\manage.ps1 local start
```
*El script creará o reactivará el clúster `voltera-onprem`, mapeará los puertos y configurará el contexto de `kubectl`.*

### Paso 2: Instalar los Addons (Istio + Knative + KEDA)
```powershell
pwsh .\infra\manage.ps1 local addons
```

### Paso 3: Desplegar el Emulador On-Premise
```powershell
kubectl apply -f mock-onprem/k8s/app.yaml
kubectl apply -f mock-onprem/k8s/trigger-to-cloud.yaml
```

### Paso 4: Detener o Destruir el Clúster Local
* **Para pausar el clúster** (conserva contenedores y estado sin consumir CPU/RAM):
  ```powershell
  pwsh .\infra\manage.ps1 local stop
  ```
* **Para eliminar el clúster completamente**:
  ```powershell
  pwsh .\infra\manage.ps1 local delete
  ```

---

## 🔌 5. Tabla de Puertos Mapeados

| Puerto en el Host (Tu PC) | Puerto en K3s | Función |
|---|---|---|
| **`8090`** | `80` (HTTP) | Entrada HTTP para el Ingress Gateway de Istio |
| **`8443`** | `443` (HTTPS) | Entrada segura HTTPS / mTLS |
| **`6550`** | `6443` (API Server) | Puerto de control para comandos `kubectl` |

---

## 📁 6. Archivos del Módulo

* [`setup-k3s.ps1`](file:///d:/uniandes_local/nuevagen/infra/local-k3s/setup-k3s.ps1): Script para crear/iniciar el clúster k3d con Traefik deshabilitado y puertos expuestos.
* [`teardown-k3s.ps1`](file:///d:/uniandes_local/nuevagen/infra/local-k3s/teardown-k3s.ps1): Script para pausar (`stop`) o destruir (`delete`) el clúster.
* [`README.md`](file:///d:/uniandes_local/nuevagen/infra/local-k3s/README.md): Este documento explicativo.
