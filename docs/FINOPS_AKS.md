# Guía Operativa de FinOps: Control On/Off para AKS en Entornos Dev

Este documento describe la estrategia de optimización financiera (**FinOps**) aplicada al clúster de **Azure Kubernetes Service (AKS)** en el entorno de desarrollo (`voltera-dev`), orientada a maximizar el rendimiento de los créditos de la suscripción **Visual Studio Enterprise**.

---

## 1. Justificación FinOps y Modelo de Costos

En entornos de pruebas y desarrollo, los clústeres de Kubernetes suelen permanecer inactivos más del **70% del tiempo** (noches, fines de semana y festivos). 

### Comparativa de Costos (VM `Standard_B4ms` - 4 vCPUs, 16 GB RAM)
| Componente | Estado `Running` (24/7) | Estado `Stopped` (Stop/Start FinOps) | Ahorro Estimado |
|---|---|---|---|
| **Cómputo de Nodos (VMs)** | ~\$125 - \$145 USD / mes | **\$0 USD** (mientras esté apagado) | **~75% - 80%** |
| **Control Plane de AKS** | \$0 (Free Tier habilitado) | \$0 (Free Tier) | 0% |
| **Almacenamiento (Discos OS / PVCs)** | Costo estándar por GB (~\$5-10 USD) | Costo estándar por GB (~\$5-10 USD) | Preservado intacto |
| **IP Pública / VNet** | Tarifa fija menor (~\$3-4 USD) | Tarifa fija menor (~\$3-4 USD) | Preservado intacto |

> [!NOTE]
> Al ejecutar `az aks stop`, el estado de los pods, servicios, deployments, volúmenes persistentes (PVCs) y configuraciones de red **NO se destruyen ni se pierden**. Simplemente se detienen los nodos de cómputo. Al iniciar (`start`), el clúster despierta exactamente en el mismo estado en ~2 a 3 minutos.

---

## 2. Métodos de Control On / Off

Dispones de tres alternativas operativas para controlar el encendido y apagado del clúster:

---

### Método 1: CLI Unificado / Script Rápido de PowerShell (Recomendado)
El repositorio incluye el CLI unificado [`infra/manage.ps1`](file:///d:/uniandes_local/nuevagen/infra/manage.ps1) y el script especializado en [`infra/azure-terraform/scripts/aks-power.ps1`](file:///d:/uniandes_local/nuevagen/infra/azure-terraform/scripts/aks-power.ps1).

Abre PowerShell en la raíz del proyecto y ejecuta:

#### 1. Consultar estado actual:
```powershell
# Vía CLI unificado:
pwsh .\infra\manage.ps1 azure status

# O vía script directo:
pwsh -File .\infra\azure-terraform\scripts\aks-power.ps1 -Action status
```

#### 2. Apagar el clúster (Detener facturación de cómputo en $0 USD):
```powershell
# Vía CLI unificado:
pwsh .\infra\manage.ps1 azure stop

# O vía script directo:
pwsh -File .\infra\azure-terraform\scripts\aks-power.ps1 -Action stop
```

#### 3. Encender el clúster (Reanudar laboratorio de desarrollo):
```powershell
# Vía CLI unificado:
pwsh .\infra\manage.ps1 azure start

# O vía script directo:
pwsh -File .\infra\azure-terraform\scripts\aks-power.ps1 -Action start
```

*Parámetros opcionales soportados:*
* `-ResourceGroup "rg-voltera-dev"`
* `-ClusterName "voltera-dev-aks"`

---

### Método 2: Comandos Nativos de Azure CLI

Si prefieres usar directamente `az cli` o integrarlo en pipelines de CI/CD:

#### 1. Iniciar sesión en Azure (si el token expiró):
```bash
az login --tenant "fab26e5a-737a-4438-8ccd-8e465ecf21d8"
```

#### 2. Consultar el estado de energía (`powerState`):
```bash
az aks show --resource-group rg-voltera-dev --name voltera-dev-aks --query "{PowerState:powerState.code, ProvisioningState:provisioningState}" -o table
```
*Posibles valores de `PowerState`: `Running` o `Stopped`.*

#### 3. Apagar el clúster (Stop):
```bash
az aks stop --resource-group rg-voltera-dev --name voltera-dev-aks
```
*(Para ejecución asíncrona sin bloquear la consola, añade `--no-wait`)*.

#### 4. Encender el clúster (Start):
```bash
az aks start --resource-group rg-voltera-dev --name voltera-dev-aks
```
*(Para ejecución asíncrona, añade `--no-wait`)*.

#### 5. Actualizar credenciales de `kubectl` tras encender:
```bash
az aks get-credentials --resource-group rg-voltera-dev --name voltera-dev-aks --overwrite-existing
kubectl get nodes
```

---

### Método 3: Automatización Programada Serverless (Zero-Ops)

En el módulo Terraform [`infra/azure-terraform/modules/finops_automation`](file:///d:/uniandes_local/nuevagen/infra/azure-terraform/modules/finops_automation) ya está aprovisionada la infraestructura de apagado desatendido:

* **Azure Automation Account**: `voltera-dev-auto-finops`
* **Identidad Administrada**: Cuenta con el rol RBAC `Azure Kubernetes Service Contributor Role`.
* **Runbook PowerShell**: `Stop-AksCluster` y `Start-AksCluster`.
* **Programación Nocturna (`Daily-Stop-Aks-8PM`)**:
  - Se ejecuta automáticamente todos los días a las **20:00 (8:00 PM hora Bogotá / UTC-5)**.
  - Garantiza que si algún desarrollador olvidó apagar el clúster al final de la jornada, la nube suspenderá el cómputo automáticamente para evitar consumos no deseados durante la noche.

#### Ejecutar el Runbook de apagado bajo demanda desde Azure CLI:
```bash
az automation runbook start \
  --automation-account-name voltera-dev-auto-finops \
  --resource-group rg-voltera-dev \
  --name Stop-AksCluster
```

#### Ejecutar el Runbook de encendido bajo demanda:
```bash
az automation runbook start \
  --automation-account-name voltera-dev-auto-finops \
  --resource-group rg-voltera-dev \
  --name Start-AksCluster
```

---

## 3. Checklist y Buenas Prácticas FinOps

1. **Al iniciar tu jornada de desarrollo**:
   - Ejecuta `aks-power.ps1 -Action start`.
   - Espera ~2 minutos hasta que `PowerState` pase a `Running`.
   - Verifica la disponibilidad de los pods con `kubectl get pods -A`.

2. **Al finalizar tu sesión**:
   - Ejecuta `aks-power.ps1 -Action stop`.
   - Verifica que el estado reporte `Stopped`.

3. **Cálculo de Ahorro Real**:
   - Jornada de desarrollo típica: 8 horas/día de lunes a viernes = **40 horas/semana**.
   - Horas totales de una semana: **168 horas**.
   - Horas en estado `Stopped`: **128 horas/semana (76.2% de ahorro en la factura de cómputo)**.
