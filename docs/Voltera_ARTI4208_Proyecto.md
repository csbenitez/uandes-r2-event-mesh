**Proyecto Voltera** ARTI4208 Arquitecturas de Nueva Generación

Facultad de Ingeniería · Departamento de Ingeniería de Sistemas y Computación

**ARTI4208 · Arquitecturas de Nueva Generación** Proyecto del curso

# Voltera

## Construyendo la comercializadora digital de la energía distribuida

*Explorando arquitecturas de nueva generación sobre un proyecto real de energytech*

**Curso** ARTI4208 · Arquitecturas de Nueva Generación **Programa** Maestría en Arquitecturas de TI (MATI) · Departamento de Ingeniería de Sistemas y Computación **Código del caso** ARTI4208-2026-P **Atributos de calidad** Latencia · Escalabilidad · Disponibilidad · Seguridad · Facilidad de modificación · Facilidad de integración **Ruta del curso** Modelado (Archimate/DDD) · Microservicios y APIs · EDA · Blockchain · IA Generativa y Agéntica **Eje transversal** Seguridad Zero Trust (infraestructura crítica)

*Documento de enseñanza. Voltera es una empresa ficticia creada con fines académicos; cualquier semejanza con entidades reales es* *coincidencia.*

Material de enseñanza — empresa ficticia Página de

**Proyecto Voltera** ARTI4208 Arquitecturas de Nueva Generación

# Contenido

1. Sinopsis del caso........................................................................................................................................3
2. Contexto de negocio y de mercado..........................................................................................................3
3. Mapa de stakeholders...............................................................................................................................7
4. Ecosistema de integraciones externas......................................................................................................9
5. Requisitos funcionales y experiencias de cliente (web y móvil)...............................................................9
6. Atributos de calidad (los seis ejes)..........................................................................................................12
7. Restricciones (de curso) y supuestos......................................................................................................14
8. Ruta de arquitecturas de nueva generación (5 módulos)...................................................................... 16
9. Preguntas de discusión...........................................................................................................................20
10. Glosario..................................................................................................................................................20
11. Referencias de contexto........................................................................................................................21

# 1. Sinopsis del caso

**Voltera** es una comercializadora digital de energía (**energytech**) que nace en 2026 sin sistemas heredados: nativa en la nube y construida sobre tres olas que están transformando el sector eléctrico — la **medición** **inteligente** (millones de medidores que reportan en tiempo real), la **generación distribuida** (hogares y empresas que producen su propia energía con paneles solares y baterías) y la apertura regulatoria a las **comunidades energéticas**. Su promesa: que cualquier hogar o empresa pueda producir, consumir, almacenar y vender energía de forma simple, transparente y en tiempo real.

Este caso es el **proyecto base** del curso: sobre él, el equipo explora arquitecturas de nueva generación de forma incremental. El trabajo avanza en **cinco módulos** —modelado de la empresa (Archimate y DDD), servicios y microservicios con portafolio de APIs, arquitecturas orientadas a eventos, arquitecturas Blockchain, e IA Generativa y Agéntica—, y en cada módulo se produce un **cuaderno de trabajo** con una prueba de concepto que valida una parte de la arquitectura.

El hilo conductor no es la tecnología por sí misma, sino cómo seis **atributos de calidad — latencia,** **escalabilidad, disponibilidad, seguridad, facilidad de modificación y facilidad de integración —** se convierten en decisiones de diseño concretas y medibles. El producto debe ofrecerse a través de un **cliente** **web** y un **cliente móvil**, cada uno con capacidades propias de su canal.

Hay un agravante que distingue a este caso: Voltera opera sobre **infraestructura crítica**. Un fallo no degrada una venta: puede dejar a una comunidad sin energía, enviar un comando peligroso a una batería o corromper la liquidación de un mercado. Por eso la seguridad se aborda como eje transversal a todos los módulos, bajo el enfoque **Zero Trust**.

### Pregunta central del caso

*¿Cómo se diseña la arquitectura de una plataforma de energía distribuida —que mide en tiempo real,* *controla dispositivos físicos y liquida un mercado entre pares— incorporando estilos de nueva generación* *(microservicios y APIs, eventos, blockchain e IA generativa y agéntica) de modo que sostenga los seis* *atributos de calidad bajo un enfoque de seguridad Zero Trust?*

# 2. Contexto de negocio y de mercado

## 2.1 La oportunidad

El sector eléctrico latinoamericano vive su mayor transformación en un siglo. Durante décadas el modelo fue unidireccional: unas pocas centrales generaban, la red distribuía y el usuario consumía de forma pasiva, con una factura mensual y un medidor que se leía a mano. Tres cambios rompen ese esquema. Primero, la **medición avanzada (AMI)**: en Colombia, la Resolución CREG 101-001 de 2022 fijó las condiciones para desplegar medidores inteligentes con comunicación bidireccional, con la meta de cubrir buena parte del país hacia 2030. Segundo, la **generación distribuida**: el usuario se convierte en **prosumidor** — produce energía con paneles solares, la almacena en baterías y puede entregar excedentes a la red. Tercero, las **comunidades** **energéticas**: la Ley 2294 de 2023 y el Decreto 2236 de 2023, y luego la regulación de la CREG, habilitan que vecinos se asocien para generar, compartir y comercializar energía localmente.

El resultado es un sistema con millones de puntos que miden, producen y consumen al mismo tiempo. Voltera apuesta a que el ganador de esta década no será quien tenga más activos de generación, sino quien tenga la **plataforma de datos, control y liquidación en tiempo real** más rápida, confiable y segura.

## 2.2 La empresa

|Atributo|Descripción|
|---|---|
|Fundación|2026, sin sistemas heredados (greenfield). Nativa en la nube.|
|Sede y mercados|Sede en Bogotá; expansión planeada a Chile, México y Brasil en 36 meses.|
|Modelo|Comercializadora digital de energía + plataforma de energía distribuida con mercado entre pares (P2P).|
|Segmentos|Hogares con solar en techo, pymes, comunidades energéticas y grandes consumidores.|
|Propuesta de valor|Visibilidad del consumo en tiempo real, tarifas dinámicas, venta de excedentes al vecino y certificados de origen renovable verificables.|
|Meta a 36 meses|2 millones de medidores conectados, 500 comunidades energéticas activas y un mercado P2P líquido en cuatro países.|

## 2.3 Capacidades de negocio

El portafolio se organiza en capacidades de negocio, no en aplicaciones. Estas capacidades son un insumo para razonar sobre cómo estructurar la arquitectura:

|Capacidad de negocio|Qué resuelve|
|---|---|
|Medición y telemetría (AMI/IoT)|Ingesta, validación y almacenamiento de las lecturas de millones de medidores y dispositivos.|
|Facturación y liquidación|Cálculo de consumo neto, tarifa dinámica, excedentes entregados y emisión de la factura.|
|Mercado P2P de energía|Emparejamiento de ofertas y demandas entre prosumidores y liquidación de cada transacción.|
|Gestión de activos distribuidos (DER)|Registro, monitoreo y control de paneles, baterías y cargadores de vehículos eléctricos.|
|Pronóstico de demanda y generación|Predice consumo y generación solar para operar el sistema y fijar precios.|
|Respuesta a la demanda (flexibilidad)|Envía señales y comandos para desplazar consumo o descargar baterías en momentos críticos.|
|Certificados de origen renovable|Emite, transfiere y verifica certificados de energía limpia, evitando el doble conteo.|
|Comunidades energéticas|Alta y operación de comunidades, con reglas de reparto de la energía y de los excedentes.|
|Cumplimiento y reportes al mercado|Reportes al regulador y al operador del mercado; trazabilidad y auditoría.|

## 2.4 Caso insignia: comunidades energéticas y mercado P2P con certificados de origen

El gran diferenciador de Voltera es permitir que una **comunidad energética** opere de verdad: que los excedentes del techo solar de una casa alimenten al vecino de enfrente, que el reparto se haga con reglas transparentes y que cada kilovatio-hora limpio quede registrado con un **certificado de origen verificable** que nadie pueda duplicar ni falsificar.

Esto exige mucho más que una factura mensual. Exige medir con granularidad fina y en tiempo casi real, emparejar oferta y demanda de forma continua, liquidar transacciones entre decenas de miles de pares, y hacerlo con un registro que **todas las partes —vecinos, comunidad, operador de red y regulador— puedan** **auditar y confiar**, sin que ninguna sea dueña única de la verdad.

### Por qué es exigente para la arquitectura

El caso insignia tensiona los seis atributos a la vez: la telemetría exige latencia y escalabilidad extremas; la liquidación exige exactitud y disponibilidad; el control de dispositivos exige seguridad de infraestructura crítica; las reglas de reparto y las tarifas cambian con la regulación, lo que exige modificabilidad; y el ecosistema (medidores, red, mercado, agregadores) exige integrabilidad. Es, además, el escenario donde un libro mayor compartido y verificable se justifica por sí solo — y por eso conecta de forma natural con el módulo de Blockchain.

## 2.5 Motivadores de negocio y metas de crecimiento

Los **motivadores de negocio** son las metas que justifican la arquitectura: cada atributo de calidad existe porque hay un objetivo de negocio detrás. En Voltera, el crecimiento en **ingresos** y en **captación de clientes y** **medidores conectados** es el principal motor de las decisiones técnicas.

**Metas de crecimiento (titulares)**

**2.000.000 de medidores conectados en 24 meses · USD 180 M de ingresos anualizados en 36 meses ·** **Crecimiento ~12% mensual · 500 comunidades energéticas activas · Retención anual ≥ 92%**

|Motivador de negocio|Meta / métrica de crecimiento|Atributos de calidad que impulsa|
|---|---|---|
|Captación de clientes|De 0 a 2.000.000 de medidores conectados en 24 meses; hasta +80.000 altas/mes.|Escalabilidad, latencia, disponibilidad.|
|Crecimiento de ingresos|Ingresos creciendo ~12% mensual; USD 180 M anualizados en 36 meses.|Escalabilidad, facilidad de integración.|
|Comunidades energéticas|500 comunidades activas en 24 meses, con reglas de reparto propias.|Facilidad de modificación, integrabilidad.|
|Liquidez del mercado P2P|Energía transada entre pares creciendo mes a mes, con liquidación confiable.|Latencia, disponibilidad, seguridad.|
|Confianza y retención|Retención anual ≥ 92%; cero incidentes graves de seguridad o de facturación.|Seguridad, disponibilidad.|
|Expansión regional|Cuatro países operando sobre la misma plataforma.|Escalabilidad, facilidad de modificación.|

# 3. Mapa de stakeholders

El diseño arquitectónico debe responder a intereses en tensión. Un buen arquitecto reconoce que cada atributo de calidad tiene un “dueño” en el negocio.

## 3.1 Stakeholders internos

|Stakeholder interno|Qué le importa (interés arquitectónico)|
|---|---|
|CEO / Junta directiva|Crecimiento, time-to-market, costo por medidor conectado y continuidad del negocio.|
|CTO / Arquitectura|Sostenibilidad técnica, evolvabilidad y control del costo de la nube y de los datos.|
|Mesa de energía (trading)|Precisión y oportunidad de los precios, del pronóstico y de la liquidación del mercado.|
|Producto y crecimiento|Rapidez para lanzar tarifas y productos; experiencia en tiempo real del prosumidor.|
|Operaciones de red y campo|Disponibilidad de la telemetría, detección de fallas y gestión de dispositivos.|
|Seguridad de la información (CISO)|Infraestructura crítica: integridad de los comandos, identidad de dispositivos, superficie de ataque.|
|Cumplimiento y regulación|Reglas de la CREG, reportes al mercado, habeas data y protección del dato de consumo.|
|Finanzas (CFO)|Costo total de propiedad, exactitud de la facturación y previsibilidad del gasto.|
|Equipos de desarrollo (SRE/Dev)|Autonomía, velocidad de despliegue, observabilidad y carga cognitiva.|

## 3.2 Stakeholders externos

|Stakeholder externo|Relación con Voltera|
|---|---|
|Prosumidores y hogares|Producen, consumen y venden energía; esperan visibilidad en tiempo real y transparencia.|
|Comunidades energéticas|Se asocian para generar y compartir energía con reglas de reparto propias.|
|Empresas y grandes consumidores|Compran energía y certificados de origen; exigen trazabilidad y disponibilidad.|
|Operador de red / distribuidora|Opera la red física; aporta topología, cortes y calidad del servicio.|
|Operador del mercado mayorista|Define precios y despacho; impone ventanas de tiempo estrictas de liquidación.|
|Regulador (CREG) y vigilancia|Fija las reglas de AMI, generación distribuida y comunidades energéticas.|
|Fabricantes de medidores y dispositivos|Proveen medidores, inversores, baterías y cargadores (protocolos heterogéneos).|
|Agregadores de flexibilidad|Consumen la capacidad de respuesta a la demanda de Voltera y la llevan al|

|Stakeholder externo|Relación con Voltera|
|---|---|
||mercado.|
|Certificadoras de origen renovable|Validan y reconocen los certificados de energía limpia.|
|Pasarelas de pago y bancos|Recaudo de facturas y pago de excedentes a los prosumidores.|

# 4. Ecosistema de integraciones externas

Voltera es, en esencia, un **orquestador de integraciones sobre el mundo físico**. Debe conectarse de forma segura, resiliente y con baja latencia a dispositivos, redes, mercados y proveedores de datos. La siguiente tabla resume las integraciones clave y por qué son arquitectónicamente exigentes.

|Integración externa|Propósito|Reto arquitectónico|
|---|---|---|
|Medidores inteligentes (AMI/IoT)|Telemetría de consumo y generación en tiempo casi real.|Volumen masivo, dispositivos heterogéneos, identidad y conectividad intermitente.|
|Dispositivos DER (baterías, inversores, VE)|Monitoreo y control de activos distribuidos.|Comandos seguros y no repudiables; estado seguro ante fallo (fail-safe).|
|Operador de red / distribuidora|Topología, cortes y calidad del servicio.|Disponibilidad variable, formatos heredados, conciliación.|
|Operador del mercado mayorista|Precios, despacho y liquidación.|Ventanas de tiempo estrictas y exactitud de los datos.|
|Datos abiertos (clima y radiación solar)|Pronóstico de generación y de demanda.|Calidad variable, cacheo y degradación elegante.|
|Ledger de certificados de origen|Emisión y transferencia verificable de energía renovable.|Qué va on-chain y qué off-chain; oráculos; costo y latencia.|
|Pasarelas de pago y bancos|Cobro de facturas y pago de excedentes.|Idempotencia, reintentos, conciliación, PCI-DSS.|
|Regulador y reportes de mercado|Cumplimiento y reportes periódicos.|Trazabilidad, auditoría y reconstrucción de cálculos.|
|Proveedores de IA / LLM|Copilotos, agentes y pronóstico.|Costo, privacidad del dato de consumo y explicabilidad.|

### Implicación de diseño

Cada dependencia externa es un punto de fallo y una fuente de latencia — y aquí, además, muchas son físicas: un medidor se queda sin señal, una batería no responde, una red se cae. La arquitectura debe asumir que el mundo real falla: timeouts, reintentos con backoff, circuit breakers, encolamiento y almacenamiento local, degradación elegante y estados seguros no son opcionales, sino parte del contrato de calidad.

# 5. Requisitos funcionales y experiencias de cliente (web y móvil)

## 5.1 Recorridos críticos

El equipo destila seis recorridos (journeys) críticos que la plataforma debe soportar de extremo a extremo:

**1. Telemetría y visibilidad en tiempo real:** el medidor reporta consumo y generación; el dato se valida, se almacena y el prosumidor lo ve en su app casi al instante.

**Proyecto Voltera** ARTI4208 Arquitecturas de Nueva Generación

**2. Facturación y liquidación:** se calcula el consumo neto, se aplica la tarifa (posiblemente dinámica), se valoran los excedentes entregados y se emite la factura.
**3. Mercado P2P:** un prosumidor ofrece sus excedentes; el sistema empareja oferta y demanda entre vecinos y liquida la transacción.
**4. Certificado de origen renovable:** por la energía limpia generada se emite un certificado verificable, transferible y no duplicable.
**5. Respuesta a la demanda:** ante un pico o una señal de precio, se envían comandos a baterías y dispositivos, y se compensa al usuario por su flexibilidad.
**6. Comunidad energética:** alta y operación de una comunidad, con reglas configurables de reparto de la energía y de los excedentes entre sus miembros.
## 5.2 Clientes web y móvil

El producto debe ofrecerse mediante **dos clientes**. La **web** es la experiencia completa de operación y gestión (mesa de energía, facturación, administración de comunidades, tableros regulatorios, back-office). La **móvil** es la del prosumidor: vive en el bolsillo del usuario, muestra su energía en tiempo real y le permite actuar en el momento oportuno.

|Aspecto|Cliente web|Cliente móvil|
|---|---|---|
|Propósito principal|Operación, gestión y análisis (mesa de energía, back-office, comunidades).|Autoservicio del prosumidor y acción en tiempo real.|
|Usuarios típicos|Operaciones, mesa de energía, gestores de comunidad, grandes clientes.|Hogares y pymes prosumidoras.|
|Alcance funcional|Cobertura funcional total del negocio.|Subconjunto orientado a monitoreo, alertas y control.|

**Funcionalidades particulares del cliente móvil** (aprovechan el dispositivo y el momento, y no tienen equivalente pleno en web):

- **Monitoreo en tiempo real:** consumo y generación al instante, con streaming continuo hacia la app.
- **Notificaciones push:** picos de precio, eventos de respuesta a la demanda, excedente vendido, corte de energía o falla del medidor.
- **Control de dispositivos:** cargar o descargar la batería y gestionar el cargador del vehículo eléctrico desde el móvil.
- **Autorización biométrica:** confirmar con huella o rostro la venta de excedentes y los comandos sensibles a dispositivos.
- **Reporte de incidencias con cámara y geolocalización:** registrar una falla del medidor o del panel con evidencia visual y ubicación.
- **Modo offline:** consultar la última lectura, la factura y las credenciales aun sin conexión, con sincronización posterior.
### Implicación de arquitectura

Servir a dos clientes muy distintos, más los agregadores y las comunidades, es una decisión de diseño: ¿se exponen las mismas APIs a todos o se usa un back-end por experiencia (BFF)? ¿Cómo se lleva el tiempo real hasta el móvil sin agotar la batería del teléfono? ¿Cómo se maneja el offline y la sincronización? ¿Y cómo se versiona la API sin romper apps ya instaladas en millones de hogares? Estas preguntas conectan directamente con la facilidad de integración y la de modificación.

# 6. Atributos de calidad (el corazón del caso)

Este es el núcleo del proyecto. Los requisitos no funcionales se expresan como **escenarios de atributo de** **calidad medibles**, con metas deliberadamente exigentes. Cada escenario es una **hipótesis** que el equipo deberá validar con **pruebas de concepto y experimentos de arquitectura**. Las metas son ambiciosas a propósito: el reto es demostrar, con evidencia, que la arquitectura elegida las sostiene.

Se evalúan **seis ejes**: los cuatro clásicos —latencia, escalabilidad, disponibilidad y seguridad— más la **facilidad** **de modificación** (qué tan barato es cambiar el sistema cuando cambian las tarifas o la regulación) y la **facilidad de integración** (qué tan barato es conectarlo con nuevos medidores, redes, mercados y clientes).

## 6.1 Latencia

|Escenario|Estímulo|Respuesta medible|
|---|---|---|
|Telemetría a la app|Llega una lectura del medidor.|Visible en la app del prosumidor en p95 ≤ 500 ms; p99 ≤ 1 s.|
|Comando de respuesta a la demanda|Se dispara un evento de flexibilidad.|Del disparo a la confirmación del dispositivo p95 ≤ 1 s.|
|Emparejamiento en el mercado P2P|Un prosumidor publica excedentes.|Emparejamiento de oferta y demanda en p95 ≤ 300 ms.|
|Consulta de consumo y factura|El usuario abre su app o la web.|Respuesta p95 ≤ 200 ms; p99 ≤ 400 ms.|
|Pronóstico bajo demanda|Se solicita el pronóstico de generación del día.|Resultado p95 ≤ 2 s.|
|Presupuesto por dependencia externa|Llamada a red, mercado o proveedor de datos.|Presupuesto ≤ 150 ms por dependencia; timeout duro a 800 ms.|

## 6.2 Escalabilidad

|Escenario|Estímulo|Respuesta medible|
|---|---|---|
|Telemetría masiva sostenida|2.000.000 de medidores reportando cada 15 minutos.|Ingesta sostenida de ≥ 2.200 lecturas/s sin pérdida ni degradación del p95.|
|Pico de telemetría|Reconexión masiva tras una falla; los medidores vuelcan su buffer.|Absorber picos de 10× (≥ 22.000 lecturas/s) con contrapresión y sin pérdida.|
|Tormenta de eventos de red|Apagón regional: miles de medidores reportan corte.|Procesar ≥ 5.000.000 de eventos en 10 minutos sin perder ninguno.|
|Liquidación mensual|Se liquidan todas las cuentas del mes.|Liquidar 2 M de cuentas en < 4 h sin degradar la operación en tiempo real.|
|Hora pico solar en el mercado P2P|Mediodía: máxima oferta de excedentes.|Procesar ≥ 100.000 ofertas/min conservando el p95 de emparejamiento.|
|Crecimiento de dispositivos controlables|Se pasa de 50.000 a 500.000 dispositivos DER.|Escalar el control sin rediseñar el núcleo; alta de país nuevo en ≤ 6 semanas.|

||Proyecto Voltera||ARTI4208 Arquitecturas de Nueva Generación|
|---|---|---|---|
||6.3 Disponibilidad|||
|Escenario||Estímulo|Respuesta medible|
|(crítico)|Telemetría y facturación|Operación normal 24/7.|Disponibilidad ≥ 99,99% mensual (≈ 4 min de indisponibilidad/mes).|
||Control de dispositivos|Se envían comandos a baterías y cargadores.|≥ 99,99%; ante fallo, el dispositivo queda en estado seguro (fail-safe).|
||Caída de una zona de nube|Falla una zona de disponibilidad.|Continuidad con RTO ≤ 5 min y sin pérdida de lecturas confirmadas (RPO ≤ 10 s).|
|completa|Caída de una región|Se pierde una región.|Failover multi-región con RTO ≤ 10 min y liquidaciones íntegras.|
||Dependencia externa caída|Se cae el operador de red o el mercado.|Seguir midiendo y encolando; degradación elegante; reconciliar al restablecerse.|
|de fallos|Despliegues y aislamiento 6.4 Seguridad (infraestructura crítica)|Se despliega en producción varias veces al día.|Cero downtime; la caída de un módulo no crítico no detiene la medición ni el control.|
|Escenario||Estímulo|Respuesta medible|
|físicos|Comandos a dispositivos|Se ordena descargar una batería o cortar un suministro.|Comando autenticado, firmado y no repudiable; bloqueo de un comando anómalo ≤ 1 s.|
||Identidad de dispositivos IoT|Un medidor nuevo se conecta a la plataforma.|Identidad fuerte por dispositivo, credenciales rotables y revocación efectiva ≤ 5 min.|
|consumo|Privacidad del dato de|La curva de consumo revela hábitos del hogar.|Cifrado en tránsito y reposo, minimización, anonimización para analítica y consentimiento.|
|(antifraude)|Integridad de la medición|Se intenta manipular un medidor o inyectar lecturas falsas.|Detección de manipulación y trazabilidad completa; la lectura es verificable de origen a factura.|
||Certificados de origen|Se emite y transfiere un certificado renovable.|No duplicable ni falsificable; verificable por terceros; sin doble conteo.|
||Auditoría de la liquidación|El regulador o un cliente cuestiona una factura.|Toda liquidación es trazable y reconstruible al 100%.|
||Marco de cumplimiento (supuesto del caso)|Voltera opera bajo la regulación del sector eléctrico colombiano —medición avanzada (Resolución CREG 101- 001 de 2022), generación distribuida y comunidades energéticas (Ley 2294 y Decreto 2236 de 2023, con la||
||Material de enseñanza — empresa ficticia||Página 13 de 22|

regulación posterior de la CREG)— además de la Ley 1581 de 2012 (habeas data) para el dato de consumo y estándares de pagos como PCI-DSS. Al tratarse de infraestructura crítica, la ciberseguridad y la privacidad se tratan como requisitos de diseño, no como controles añadidos al final.

## 6.5 Facilidad de modificación

|Escenario|Estímulo|Respuesta medible|
|---|---|---|
|Nuevo esquema tarifario|Se lanza una tarifa dinámica por horas.|Añadir la tarifa modificando componentes acotados, sin tocar el núcleo, en ≤ 2 semanas-equipo.|
|Cambio regulatorio|La CREG modifica las reglas de comunidades energéticas.|Absorber el cambio en módulos localizados; impacto trazable y acotado.|
|Nueva regla de reparto en comunidad|Una comunidad define un reparto distinto de excedentes.|Regla configurable por comunidad, sin cambios de código ni despliegue.|
|Nuevo tipo de dispositivo DER|Entra un modelo nuevo de batería o cargador.|Incorporarlo sin modificar el motor de control ni los demás dispositivos.|
|Cambio del algoritmo de pronóstico|Se reemplaza el modelo de predicción solar.|Sustituirlo tras una interfaz estable, sin redesplegar todo el sistema.|

## 6.6 Facilidad de integración

|Escenario|Estímulo|Respuesta medible|
|---|---|---|
|Nuevo fabricante de medidores|Entra un medidor con otro protocolo.|Integrarlo tras un adaptador estándar en ≤ 2 semanas, sin cambios en el núcleo.|
|Nuevo operador de red o mercado|Se habilita un país nuevo.|Conectar el operador tras un adaptador, aislando el modelo interno.|
|Web y móvil sobre las mismas APIs|Ambos clientes consumen la plataforma.|APIs versionadas y estables; un cambio no obliga a actualizar todas las apps a la vez.|
|Interoperabilidad de estándares del sector|Intercambio con la red y el mercado.|Mapeo a estándares del sector mediante adaptadores, sin contaminar el dominio.|
|Consumo por agregadores de flexibilidad|Un tercero quiere usar la flexibilidad de Voltera.|Exponer capacidad y eventos con contratos claros, sin acoplar a los productores.|

# 7. Restricciones y supuestos

Las restricciones acotan el espacio de soluciones: no son obstáculos accidentales, sino condiciones de diseño que el equipo debe respetar y aprovechar.

||Proyecto Voltera||ARTI4208 Arquitecturas de Nueva Generación|
|---|---|---|---|
||7.1 Restricciones técnicas|||
|Restricción||Descripción|Implicación arquitectónica|
||Diseño incremental con PoC por módulo (obligatoria)|Cada módulo culmina en una prueba de concepto que valida una parte de la arquitectura sobre el caso.|El diseño se somete a evidencia temprana y continua, no solo a documentación.|
||Estilos y tecnologías de nueva generación (obligatoria)|La solución debe incorporar los estilos del curso —microservicios y APIs, EDA, blockchain e IA generativa/agéntica— donde aporten valor real.|Exige justificar cuándo cada estilo suma y cuándo no; evita el uso por moda.|
|(propuesta)|Cloud-native y contenedores 7.2 Restricciones de negocio|La solución se empaqueta en contenedores y se despliega en la nube con automatización reproducible.|Portabilidad, escalamiento elástico y pruebas de concepto repetibles.|
|Restricción||Descripción|Implicación arquitectónica|
||Proyecto semestral en equipo multidisciplinario (obligatoria)|Equipos de 4–5 personas que entregan de forma incremental (cuadernos de trabajo) a lo largo del semestre.|La arquitectura evoluciona por entregas; la coordinación y la carga cognitiva importan.|
||Operación sobre infraestructura crítica (obligatoria)|Un fallo puede dejar sin energía a una comunidad o enviar un comando peligroso a un dispositivo.|La seguridad y la disponibilidad no son negociables; se exige estado seguro ante fallo.|
|(propuesta)|Crecimiento regional sostenible|La arquitectura debe soportar las metas de ingresos y de medidores conectados sin rediseños disruptivos.|Escalabilidad y facilidad de modificación como condiciones, no aspiraciones.|
|7.3 Supuestos • • • •|Greenfield: Nube primero: Dependencia del mundo físico: Regulación evolutiva: madurando. Material de enseñanza — empresa ficticia|no hay sistemas legados; el equipo diseña desde cero. infraestructura elástica, multi-zona y con posibilidad multi-región. medidores y dispositivos con conectividad intermitente y fallas reales. las reglas de AMI, generación distribuida y comunidades energéticas siguen|Página 15 de 22|

# 8. Ruta de arquitecturas de nueva generación

Voltera es el **proyecto base** sobre el que el curso explora, de forma incremental, los estilos y tecnologías que definen las arquitecturas de nueva generación. El trabajo avanza en **cinco módulos**; cada uno introduce un estilo moderno, se aplica al caso y culmina en un **cuaderno de trabajo** con una **prueba de concepto (PoC)** que valida una parte de la arquitectura.

Dos prácticas son transversales a todos los módulos: el **modelado de la arquitectura** (Archimate y DDD para las vistas y el dominio) y la **validación con pruebas de concepto**. Y un eje de seguridad recorre todo el diseño: el enfoque **Zero Trust**, especialmente exigente aquí por tratarse de infraestructura crítica.

|Módulo|Foco de nueva generación|Entregable|
|---|---|---|
|Módulo 1|Modelado de la empresa: Archimate y Domain-Driven Design (DDD).|Cuaderno 1 — Modelo de Empresa|
|Módulo 2|Servicios y microservicios; portafolio de APIs.|Cuaderno 2 — Microservicios|
|Módulo 3|Arquitecturas orientadas a eventos (EDA) y telemetría masiva.|Cuaderno 3 — EDA|
|Módulo 4|Arquitecturas Blockchain (certificados de origen, mercado P2P).|Cuaderno 4 — Blockchain|
|Módulo 5|IA Generativa y Agéntica (RAG, agentes, LLMOps).|Cuaderno 5 — IA Gen. y Agéntica|

## 8.1 Módulo 1 — Modelado de la empresa (Archimate + DDD)

**Reto.** Entender el negocio de Voltera —capacidades, procesos, actores y motivadores— y traducirlo a un modelo empresarial y a un modelo de dominio con contextos acotados (bounded contexts) y lenguaje ubicuo. El dominio energético tiene un vocabulario propio (prosumidor, excedente, flexibilidad, liquidación, certificado) que hay que capturar sin ambigüedad.

**Nueva generación.** Alineación negocio–TI con Archimate (capas de motivación, negocio, aplicación y tecnología) y DDD estratégico (mapa de contextos, subdominios núcleo/soporte/genéricos, event storming) para descomponer bien antes de construir.

**Entregable / PoC.** Cuaderno de Trabajo 1 — Modelo de Empresa: modelo Archimate, mapa de contextos y clasificación de subdominios de Voltera.

*Para reflexionar: ¿cuáles son los subdominios núcleo de Voltera (¿medición? ¿liquidación? ¿mercado P2P?) y cuáles* *conviene comprar o delegar?*

## 8.2 Módulo 2 — Servicios, microservicios y portafolio de APIs

**Reto.** Exponer las capacidades (medición, facturación, mercado P2P, control de dispositivos, comunidades) como servicios y como un portafolio de APIs consumible por los clientes web y móvil, por los agregadores de flexibilidad y por las comunidades energéticas, con bajo acoplamiento y autoadaptabilidad.

**Nueva generación.** Diseño API-first y gobierno de un portafolio de APIs; microservicios con datos propios; API gateway y service mesh; contratos y versionado que permiten evolucionar sin romper a los consumidores — incluidas apps ya instaladas en millones de hogares.

**Proyecto Voltera** ARTI4208 Arquitecturas de Nueva Generación

**Entregable / PoC.** Cuaderno de Trabajo 2 — Microservicios: descomposición por subdominios, diseño del portafolio de APIs (OpenAPI) y PoC de dos o tres servicios tras un gateway.

*Para reflexionar: ¿qué granularidad de servicios resiste la carga de la telemetría sin fragmentar en exceso el* *dominio?*

## 8.3 Módulo 3 — Arquitecturas orientadas a eventos (EDA)

**Reto.** La telemetría de millones de medidores, las tormentas de eventos ante un apagón, la respuesta a la demanda y el mercado P2P en hora pico exigen comunicación por eventos, streaming y coreografía de servicios. Aquí lo síncrono simplemente no alcanza.

**Nueva generación.** EDA y event streaming a gran escala; coreografía frente a orquestación; event sourcing y CQRS (la lectura del medidor es, por naturaleza, un hecho inmutable); schema registry, contrapresión y patrones saga para la liquidación distribuida.

**Entregable / PoC.** Cuaderno de Trabajo 3 — EDA: catálogo de eventos de negocio, diseño de los flujos coreografiados y PoC de la ingesta de telemetría y del disparo de una respuesta a la demanda de extremo a extremo.

*Para reflexionar: ¿cómo se absorbe una tormenta de eventos sin perder ninguna lectura? ¿Cómo se garantizan* *idempotencia, orden y trazabilidad?*

**Proyecto Voltera** ARTI4208 Arquitecturas de Nueva Generación

## 8.4 Módulo 4 — Arquitecturas Blockchain (certificados y mercado P2P)

**Reto.** Que vecinos, comunidad, operador de red y regulador confíen en un mismo registro sin que ninguno sea dueño único de la verdad: liquidar transacciones de energía entre pares y emitir certificados de origen renovable que sean verificables, transferibles y — sobre todo — imposibles de duplicar o contar dos veces.

**Nueva generación.** Contratos inteligentes para liquidar automáticamente las transacciones del mercado P2P; tokenización de certificados de energía renovable; libro mayor compartido y auditable entre las partes; oráculos que inyectan la lectura del medidor como dato confiable; y el diseño de qué va on-chain y qué se queda off-chain.

**Entregable / PoC.** Cuaderno de Trabajo 4 — Blockchain: diseño del contrato inteligente que liquida una transacción P2P y emite el certificado de origen, con una PoC que dispara la liquidación a partir de una lectura reportada por un oráculo.

*Para reflexionar: ¿qué va on-chain y qué off-chain? ¿Cómo se concilian la latencia y el costo del ledger con las* *metas de latencia y disponibilidad? ¿Y cuándo una base de datos auditada bastaría?*

## 8.5 Módulo 5 — IA Generativa y Agéntica

**Reto.** Hacer entendible y accionable un dominio que para el usuario es opaco: explicar por qué la factura subió, recomendar cuándo consumir o almacenar, optimizar automáticamente la carga y descarga de una batería, y responder preguntas sobre contratos y regulación tanto a clientes como a los equipos internos.

**Nueva generación.** IA generativa y agéntica: un copiloto de energía para el prosumidor; RAG con almacenes vectoriales sobre contratos, tarifas y regulación de la CREG; agentes (agentic AI) que optimizan el despacho de baterías y participan en el mercado en nombre del usuario; y LLMOps —evaluación, guardrails, control de costo y observabilidad— con foco en explicabilidad.

**Entregable / PoC.** Cuaderno de Trabajo 5 — IA Generativa y Agéntica: diseño de un copiloto/agente (p. ej. asistente que explica la factura y optimiza la batería) y de su arquitectura de servido de IA (LLMOps), con una PoC.

*Para reflexionar: si un agente actúa sobre dispositivos físicos, ¿qué límites, guardrails y trazabilidad debe tener?* *¿Cómo se controlan la alucinación y el costo?*

## 8.6 Eje transversal — Seguridad Zero Trust

**Idea.** La seguridad no es un módulo aparte sino un eje que recorre los cinco: bajo el principio “nunca confiar, siempre verificar”, cada componente, servicio, medidor, dispositivo, agente de IA y contrato inteligente autentica su identidad, opera con mínimo privilegio y se verifica de forma continua.

**Por qué aquí.** Voltera es infraestructura crítica: millones de dispositivos en hogares, comandos que actúan sobre el mundo físico, un ledger compartido con terceros y agentes de IA que pueden ejecutar acciones. La superficie de ataque es enorme y la perimetral clásica no sirve. Zero Trust —identidad fuerte por dispositivo, microsegmentación, separación TI/OT y verificación continua— es la respuesta arquitectónica moderna.

*En la práctica: cada módulo incorpora controles Zero Trust en su diseño y en su PoC (identidad de servicios y* *dispositivos, autorización por alcance, comandos firmados y verificación continua).*

### Actividades clave del proyecto (incrementales, por módulo)

- Modelar la empresa y el dominio (Archimate + DDD) como base de todo el diseño.
- Diseñar, por módulo, el estilo de nueva generación correspondiente y sus vistas de arquitectura.
- Construir una prueba de concepto (PoC) por módulo que valide una parte de la arquitectura.
- Incorporar el eje Zero Trust en cada diseño y PoC.
- Justificar las decisiones frente a los seis atributos de calidad y a los motivadores de negocio.
- Consolidar los cuadernos de trabajo como evidencia incremental de la arquitectura.

**Proyecto Voltera** ARTI4208 Arquitecturas de Nueva Generación

# 9. Preguntas de discusión

**7.** A partir del modelo de dominio (DDD), ¿cuáles son los subdominios núcleo de Voltera y cómo guían la descomposición en servicios?
**8.** ¿Qué granularidad de microservicios y qué diseño de portafolio de APIs soportan la telemetría masiva sin fragmentar el dominio ni romper a los consumidores?
**9.** ¿Cómo se absorbe una tormenta de eventos (apagón regional) sin perder lecturas, y cuándo conviene coreografía frente a orquestación?
**10.** ¿En qué aporta valor real la blockchain en Voltera (certificados de origen, liquidación P2P) y en qué casos una base de datos auditada sería suficiente?
**11.** Si un agente de IA puede actuar sobre baterías y participar en el mercado, ¿qué guardrails, límites y trazabilidad exige esa autonomía?
**12.** ¿Cómo se materializa Zero Trust cuando los “usuarios” son millones de dispositivos físicos con conectividad intermitente?
**13.** ¿Qué prueba de concepto por módulo aporta la evidencia más convincente de que la arquitectura sostiene los seis atributos de calidad?
# 10. Glosario

|Término|Definición breve|
|---|---|
|Energytech|Empresa que usa tecnología para reinventar la comercialización y gestión de la energía.|
|Prosumidor|Usuario que consume y a la vez produce energía (p. ej. con paneles solares).|
|AMI / Medición avanzada|Infraestructura de medidores inteligentes con comunicación bidireccional en tiempo casi real.|
|DER|Recursos energéticos distribuidos: paneles, baterías, cargadores de vehículos eléctricos.|
|Comunidad energética|Grupo de usuarios asociados para generar, compartir y comercializar energía localmente.|
|Respuesta a la demanda|Desplazar o reducir consumo (o descargar baterías) ante señales de precio o de red.|
|Certificado de origen renovable|Registro verificable de que una cantidad de energía fue generada de forma limpia.|
|Mercado P2P|Compraventa de energía directamente entre pares (vecinos), sin intermediario tradicional.|
|Archimate|Lenguaje de modelado de arquitectura empresarial (motivación, negocio, aplicación y tecnología).|
|Domain-Driven Design (DDD)|Diseño guiado por el dominio: contextos acotados, subdominios y lenguaje ubicuo.|

|Término|Definición breve|
|---|---|
|Portafolio de APIs|Conjunto gobernado de APIs de una organización, diseñado para bajo acoplamiento y reutilización.|
|EDA|Arquitectura orientada a eventos: integración vía hechos publicados y consumidos.|
|Microservicios|Servicios desplegables e independientes, con datos y equipos propios.|
|Smart contract|Programa que se ejecuta en una blockchain y hace cumplir reglas automáticamente.|
|Oráculo (blockchain)|Componente que inyecta datos del mundo real (p. ej. una lectura) en un contrato inteligente.|
|IA generativa y agéntica|Modelos que generan contenido y agentes que orquestan y ejecutan tareas de forma autónoma.|
|RAG|Generación aumentada por recuperación: el modelo responde apoyándose en fuentes recuperadas.|
|LLMOps|Prácticas para operar modelos de lenguaje: evaluación, guardrails, costo y observabilidad.|
|Zero Trust|Seguridad de “nunca confiar, siempre verificar”: identidad fuerte, mínimo privilegio y verificación continua.|
|Fail-safe|Diseño en el que, ante un fallo, el sistema o dispositivo queda en un estado seguro.|
|RTO / RPO|Tiempo objetivo de recuperación / punto objetivo de recuperación de datos.|

# 11. Referencias de contexto

Fuentes públicas que informan el marco regulatorio y de industria del caso (no exhaustivas; con fines didácticos):

- CREG — Medición Avanzada (AMI) — [https://www.creg.gov.co/sectores-que-regulamos/energia-electrica/medicion-](https://www.creg.gov.co/sectores-que-regulamos/energia-electrica/medicion-) avanzada-ami
- Resolución CREG 101-001 de 2022 — condiciones para la AMI — [https://gestornormativo.creg.gov.co/gestor/entorno/docs/resolucion_creg_101-1_2022.htm](https://gestornormativo.creg.gov.co/gestor/entorno/docs/resolucion_creg_101-1_2022.htm)
- Decreto 2236 de 2023 — Comunidades Energéticas — [https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=227230](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=227230)
- Ministerio de Minas y Energía — Comunidades Energéticas — [https://www.minenergia.gov.co/es/comunidades-](https://www.minenergia.gov.co/es/comunidades-) energeticas/
- Resolución CREG 101 072 de 2025 — reglas de comunidades energéticas — [https://gestornormativo.creg.gov.co/gestor/entorno/docs/originales/Resoluci%C3%B3n_CREG_101_072_2025/](https://gestornormativo.creg.gov.co/gestor/entorno/docs/originales/Resoluci%C3%B3n_CREG_101_072_2025/) Resoluci%C3%B3n_CREG_101_072_2025.pdf
- Blockchain en mercados P2P de energía (revisión académica) — [https://www.nature.com/articles/s41598-024-](https://www.nature.com/articles/s41598-024-) 72642-2
- Blockchain para comercio de energía renovable y certificados — [https://www.digitalwindmill.com/ai-technology/blockchain-renewable-energy-trading](https://www.digitalwindmill.com/ai-technology/blockchain-renewable-energy-trading)

*Caso preparado como material de enseñanza para el curso ARTI4208 Arquitecturas de Nueva Generación (MATI). Voltera y sus datos* *son ficticios. Reproducción autorizada para uso académico.*
