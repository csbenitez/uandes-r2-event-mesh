# Infraestructura como Código (IaC) para Azure AKS (Terraform)

Este módulo gestiona la infraestructura en la nube de **Microsoft Azure** para el entorno oficial de desarrollo (`voltera-dev`) en la región **East US 2**. Aprovisiona un clúster gestionado de **Azure Kubernetes Service (AKS)**, red virtual aislada, observabilidad, pasarela de APIs, Event Grid y automatización **FinOps** orientada a reducir el costo de cómputo en un **~76%**.

---

## 🏛️ 1. Arquitectura de Recursos en Azure

El entorno completo se encuentra confinado dentro del grupo de recursos `rg-voltera-dev`:

```mermaid
flowchart TD
    subgraph ResourceGroup["Resource Group: rg-voltera-dev (Region: East US 2)"]
        
        subgraph NetModule["Modulo Network"]
            VNet["Virtual Network: voltera-dev-vnet<br/>(10.10.0.0/16)"]
            SubnetAKS["Subnet AKS: 10.10.1.0/24<br/>(Azure CNI)"]
            VNet --- SubnetAKS
        end

        subgraph AKSModule["Modulo AKS"]
            AKSCluster["Clúster AKS: voltera-dev-aks<br/>• SKU: Standard_B4ms (4 vCPUs / 16 GB RAM)<br/>• Free Tier Control Plane ($0 USD)<br/>• Azure CNI & System-Assigned Identity<br/>• Max pods: 80 por nodo"]
        end

        subgraph APIMModule["Modulo APIM (Ingress Edge Cloud)"]
            APIM["Azure API Management (Consumption Tier)<br/>• Costo fijo mensual: $0 USD (Serverless)<br/>• Exposición segura de endpoints y rate limiting"]
        end

        subgraph EventGridModule["Modulo Event Grid"]
            EventGrid["Azure Event Grid System Topic<br/>• Formato nativo CloudEvents v1.0 Serverless"]
        end

        subgraph FinOpsModule["Modulo FinOps Automation"]
            AutoAccount["Azure Automation Account:<br/>voltera-dev-auto-finops"]
            RunbookStop["Runbook PowerShell:<br/>Stop-AksCluster"]
            RunbookStart["Runbook PowerShell:<br/>Start-AksCluster"]
            ScheduleNight["Schedule Automático:<br/>Daily-Stop-Aks-8PM (20:00 COT)"]
            
            AutoAccount --> RunbookStop
            AutoAccount --> RunbookStart
            ScheduleNight --> RunbookStop
        end

        subgraph MonitoringModule["Modulo Monitoring"]
            LogAnalytics["Log Analytics Workspace:<br/>voltera-dev-law (Cap diario 0.5 GB FinOps)"]
            AppInsights["Application Insights:<br/>voltera-dev-appinsights"]
        end

    end

    SubnetAKS --- AKSCluster
    RunbookStop -.->|Suspende cómputo de VMs B4ms fuera de horario| AKSCluster
    RunbookStart -.->|Inicia clúster al comenzar la jornada laboral| AKSCluster
    AKSCluster -.->|Diagnóstico, logs y métricas| LogAnalytics
```

---

## 💰 2. Estrategia y Flujo de Automatización FinOps

Para maximizar el rendimiento de los créditos de la suscripción (ej. Visual Studio Enterprise), el clúster suspende sus nodos automáticamente durante noches y fines de semana:

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Desarrollador / Pipeline CI
    participant Script as manage.ps1 / aks-power.ps1
    participant AzureAuto as Azure Automation Runbook
    participant AKS as Clúster AKS (voltera-dev-aks)

    Note over Dev, AKS: 1. Inicio de Jornada Laboral (08:00 COT)
    Dev->>Script: pwsh manage.ps1 azure start
    Script->>AKS: Inicia cómputo de nodos (VM B4ms)
    Note over AKS: Estado pasa a Running en ~2 minutos
    Script-->>Dev: Clúster listo para recibir despliegues

    Note over Dev, AKS: 2. Operación y Pruebas del Event Mesh
    Dev->>AKS: kubectl apply -f k8s/ (Microservicios + Istio + Knative)

    Note over AzureAuto, AKS: 3. Apagado Automático Programado (20:00 COT)
    AzureAuto->>AKS: Ejecuta Runbook Stop-AksCluster
    Note over AKS: PowerState pasa a Stopped.<br/>Discos, PVCs y configuraciones preservados intactos.<br/>Costo de cómputo en $0 USD.
```

---

## 📁 3. Organización del Directorio `azure-terraform/`

```
infra/azure-terraform/
├── README.md                      # 📘 (Este documento) Especificación y arquitectura Azure
├── environments/
│   └── dev/                       # Raíz de ejecución de Terraform para el entorno Dev
│       ├── main.tf                # Orquestador de llamadas a módulos
│       ├── variables.tf           # Declaración de variables y cuotas FinOps
│       ├── terraform.tfvars.example # Plantilla sanitizada de variables
│       ├── terraform.tfvars       # Valores locales activos (excluido en git)
│       ├── outputs.tf             # Salidas: Comandos de conexión, endpoints, etc.
│       ├── providers.tf           # Proveedor azurerm configurado
│       └── versions.tf            # Versión mínima de Terraform (>= 1.6) y azurerm
├── modules/
│   ├── aks/                       # Clúster AKS, pool de nodos Standard_B4ms y Azure CNI
│   ├── network/                   # Resource Group, VNet (10.10.0.0/16) y Subnet AKS
│   ├── finops_automation/         # Automation Account, Runbooks On/Off y Schedule nocturno
│   ├── apigateway/                # Azure API Management (Consumption Tier Serverless)
│   ├── eventgrid/                 # Azure Event Grid Topic (CloudEvents v1.0)
│   └── monitoring/                # Log Analytics Workspace (Cap 0.5 GB) y App Insights
└── scripts/
    └── aks-power.ps1              # Script PowerShell de control On/Off directo
```

---

## 🚀 4. Guía de Despliegue en Azure

### Paso 1: Autenticación en Azure CLI
```bash
az login
az account set --subscription "<TU_SUBSCRIPTION_ID>"
```

### Paso 2: Configurar Variables de Entorno
Copia la plantilla de ejemplo y ajusta tus valores:
```powershell
cd infra\azure-terraform\environments\dev
copy terraform.tfvars.example terraform.tfvars
```

### Paso 3: Inicializar y Aplicar Terraform
Puedes desplegar usando el gestor unificado o Terraform directo:

* **Opción A (Recomendada - CLI Unificado)**:
  ```powershell
  # Desde la raíz del repositorio:
  pwsh .\infra\manage.ps1 azure plan
  pwsh .\infra\manage.ps1 azure apply
  ```

* **Opción B (Terraform Nativo)**:
  ```powershell
  cd infra\azure-terraform\environments\dev
  terraform init
  terraform plan
  terraform apply
  ```

### Paso 4: Conectar `kubectl` al Clúster AKS
```powershell
pwsh .\infra\manage.ps1 azure connect
```
O directamente con `az cli`:
```powershell
az aks get-credentials --resource-group rg-voltera-dev --name voltera-dev-aks --overwrite-existing
kubectl get nodes
```

### Paso 5: Instalar los Addons Cloud-Agnósticos (Istio + Knative + KEDA)
```powershell
pwsh .\infra\manage.ps1 azure addons
```

---

## ⚡ 5. Control Operativo FinOps

Para encender o apagar el clúster bajo demanda sin destruir la infraestructura (preservando discos, PVCs y configuraciones):

```powershell
# Consultar estado actual (PowerState)
pwsh .\infra\manage.ps1 azure status

# Encender el clúster al iniciar trabajo
pwsh .\infra\manage.ps1 azure start

# Apagar el clúster al terminar el día (Costo de cómputo en $0 USD)
pwsh .\infra\manage.ps1 azure stop
```

También puedes invocar directamente el script especializado en [`infra/azure-terraform/scripts/aks-power.ps1`](file:///d:/uniandes_local/nuevagen/infra/azure-terraform/scripts/aks-power.ps1):
```powershell
pwsh -File .\infra\azure-terraform\scripts\aks-power.ps1 -Action status
pwsh -File .\infra\azure-terraform\scripts\aks-power.ps1 -Action start
pwsh -File .\infra\azure-terraform\scripts\aks-power.ps1 -Action stop
```
