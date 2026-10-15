# 🧪 Suite de Pruebas de Event Mesh y Telemetría AMI (k6)

Esta carpeta contiene la suite de pruebas automatizadas y ordenadas por fases de ejecución para validar el flujo de eventos **CloudEvents v1.0 (HTTP Binary Mode)** hacia el Ingress de Azure AKS, el Broker de Knative Eventing o el concentrador local.

---

## 🗂️ Orden de Ejecución de las Pruebas

```mermaid
flowchart LR
    Paso1["01: Smoke Test<br/>(01_smoke_test.js)"]
    Paso2["02: Escenario Prosumidor<br/>(02_prosumer_scenario.js)"]
    Paso3["03: Carga y Estrés<br/>(03_load_test.js)"]

    Paso1 -->|Verificar Conectividad| Paso2
    Paso2 -->|Validar Lógica de Negocio CREG/P2P| Paso3
    Paso3 -->|Evaluar Resistencia y SLAs| Fin[Resultados Validados]
```

| Orden | Archivo | Tipo de Prueba | Descripción |
| :---: | :--- | :--- | :--- |
| **01** | **[`01_smoke_test.js`](file:///d:/uniandes_local/nuevagen/tests/01_smoke_test.js)** | **Humo y Conectividad** | Emite una lectura individual o un lote secuencial para verificar que el broker/ingress recibe y acepta los encabezados y payload CloudEvent. |
| **02** | **[`02_prosumer_scenario.js`](file:///d:/uniandes_local/nuevagen/tests/02_prosumer_scenario.js)** | **Escenario de Negocio** | Simula prosumidores solares con excedentes de energía inyectada ($Export > Import$) para probar reglas de liquidación CREG y P2P. |
| **03** | **[`03_load_test.js`](file:///d:/uniandes_local/nuevagen/tests/03_load_test.js)** | **Carga y Resistencia** | Genera múltiples medidores concurrentes (VUs) en etapas escalonadas para medir latencia, volumen total y tasas de error. |
| **--** | **[`utils.js`](file:///d:/uniandes_local/nuevagen/tests/utils.js)** | **Módulo Compartido** | Constructores de payload AMI, valores aleatorios y encabezados `Ce-*` estándar. |

---

## 🚀 Guía de Ejecución Paso a Paso

### Paso 01: Prueba de Humo y Conectividad (`01_smoke_test.js`)

Valida que el endpoint receptor esté activo y responda con códigos HTTP aceptados (`200 OK`, `201 Created` o `202 Accepted`).

#### 1.1 Emisión de una sola lectura (por defecto a `http://localhost:8080/events`):
```powershell
k6 run tests/01_smoke_test.js
```

#### 1.2 Emisión hacia el Ingress Gateway de Azure AKS:
```powershell
k6 run tests/01_smoke_test.js -e TARGET_URL="http://<INGRESS_IP>/events"
```

#### 1.3 Emisión de un lote de lecturas con intervalo de espera:
```powershell
# Envía 5 lecturas espaciadas por 0.5 segundos
k6 run tests/01_smoke_test.js `
  -e TARGET_URL="http://<INGRESS_IP>/events" `
  -e COUNT=5 `
  -e SLEEP=0.5
```

#### 1.4 Personalización de parámetros del medidor:
```powershell
k6 run tests/01_smoke_test.js `
  -e TARGET_URL="http://<INGRESS_IP>/events" `
  -e NIU="98234710" `
  -e KWH_IMPORT="15.20" `
  -e KWH_EXPORT="1.80" `
  -e TENSION_VOLTIOS="120.2"
```

---

### Paso 02: Escenario de Prosumidor Solar (`02_prosumer_scenario.js`)

Simula un usuario con paneles solares residenciales que genera más energía de la que consume, validando el flujo de liquidación de excedentes (*netting* según CREG 101-072 / CREG 101-001).

```powershell
# Enviar 5 lecturas de prosumidor con alta inyección
k6 run tests/02_prosumer_scenario.js `
  -e TARGET_URL="http://<INGRESS_IP>/events" `
  -e NIU="98234710" `
  -e COUNT=5
```

---

### Paso 03: Prueba de Carga Masiva y Estrés (`03_load_test.js`)

Evalúa la estabilidad y latencia del broker bajo ráfagas concurrentes de múltiples medidores inteligentes.

#### 3.1 Ejecución con rampa escalonada predeterminada:
* **0 a 15s**: Ramp-up hasta 10 medidores concurrentes.
* **15s a 45s**: Carga sostenida con 25 medidores concurrentes.
* **45s a 60s**: Pico de estrés con 50 medidores concurrentes.
* **60s a 70s**: Ramp-down a 0.

```powershell
k6 run tests/03_load_test.js -e TARGET_URL="http://<INGRESS_IP>/events"
```

#### 3.2 Modificación de concurrencia y tiempo al vuelo:
```powershell
# 100 medidores virtuales concurrentes durante 1 minuto continuo
k6 run --vus 100 --duration 1m tests/03_load_test.js -e TARGET_URL="http://<INGRESS_IP>/events"
```

---

## ⚙️ Tabla de Variables de Entorno Configurables

Todas las variables se configuran mediante el argumento `-e NOMBRE=VALOR` al ejecutar `k6 run`:

| Variable | Script Aplicable | Descripción | Valor por Defecto |
| :--- | :---: | :--- | :--- |
| `TARGET_URL` | Todos | URL del Ingress, Broker o servicio local | `http://localhost:8080/events` |
| `COUNT` | `01`, `02` | Número de eventos/iteraciones a emitir | `1` en 01 / `5` en 02 |
| `SLEEP` | `01` | Segundos de pausa entre iteraciones consecutivas | `1.0` |
| `NIU` | `01`, `02` | Número de Identificación de Usuario del medidor | `1002345` en 01 / `98234710` en 02 |
| `EVENT_TYPE` | `01`, `03` | Tipo de CloudEvent (`Ce-Type`) | `com.voltera.ami.lectura_registrada` |
| `EVENT_SOURCE`| `01`, `03` | Origen del evento (`Ce-Source`) | `//onprem/medidores/ami-mock` |
| `KWH_IMPORT` | `01`, `02` | Valor fijo de kWh importados | Aleatorio realista |
| `KWH_EXPORT` | `01`, `02` | Valor fijo de kWh exportados | Aleatorio realista |
| `TENSION_VOLTIOS` | `01` | Tensión de red medida en voltios | Aleatorio (118.0 - 122.0) |

---

## 📊 Umbrales de Calidad (*Thresholds*)

Las pruebas fallarán automáticamente si no se cumplen los siguientes SLAs:
* **`http_req_failed` < 1%**: Menos del 1% de solicitudes con fallos o códigos HTTP inesperados.
* **`http_req_duration` p(95) < 500ms**: El 95% de los eventos deben ser procesados en menos de 500 milisegundos.
* **Validación de estado HTTP**: Solo se consideran exitosos los códigos `200`, `201` y `202` (estándar de recepción asíncrona de Knative).
