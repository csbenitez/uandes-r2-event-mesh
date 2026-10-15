/**
 * Utilidades compartidas para simulación de telemetría AMI y CloudEvents en k6.
 */

export function getRandomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

export function getRandomFloat(min, max, decimals = 2) {
  const str = (Math.random() * (max - min) + min).toFixed(decimals);
  return parseFloat(str);
}

/**
 * Genera la carga útil de lectura de telemetría de un medidor AMI.
 */
export function buildAmiPayload(overrides = {}) {
  const niu = overrides.niu || __ENV.NIU || "1002345";
  const medidorSerie = overrides.medidorSerie || `MTR-COL-${getRandomInt(1000, 9999)}`;
  const timestamp = overrides.timestamp || new Date().toISOString();
  const intervalo = overrides.intervalo || __ENV.INTERVALO || "MINUTOS_15";

  // Consumo e inyección configurables vía env o generados aleatoriamente
  const kwhImportados = overrides.kwhImportados !== undefined
    ? overrides.kwhImportados
    : (__ENV.KWH_IMPORT !== undefined ? parseFloat(__ENV.KWH_IMPORT) : getRandomFloat(0.5, 25.0, 2));

  const kwhExportados = overrides.kwhExportados !== undefined
    ? overrides.kwhExportados
    : (__ENV.KWH_EXPORT !== undefined ? parseFloat(__ENV.KWH_EXPORT) : getRandomFloat(0.0, 6.0, 2));

  const tensionVoltios = overrides.tensionVoltios !== undefined
    ? overrides.tensionVoltios
    : (__ENV.TENSION_VOLTIOS !== undefined ? parseFloat(__ENV.TENSION_VOLTIOS) : getRandomFloat(118.0, 122.0, 2));

  return {
    niu: String(niu),
    medidor_serie: medidorSerie,
    timestamp_lectura: timestamp,
    intervalo: intervalo,
    kwh_importados: kwhImportados,
    kwh_exportados: kwhExportados,
    tension_voltios: tensionVoltios,
  };
}

/**
 * Genera los encabezados de CloudEvents v1.0 en modo HTTP Binary.
 */
export function buildCloudEventHeaders(eventType, eventId, source) {
  const now = new Date().toISOString();
  return {
    "Ce-Specversion": "1.0",
    "Ce-Type": eventType || __ENV.EVENT_TYPE || "com.voltera.ami.lectura_registrada",
    "Ce-Source": source || __ENV.EVENT_SOURCE || "//onprem/medidores/ami-mock",
    "Ce-Id": eventId || `evt-ami-${Date.now()}-${getRandomInt(100, 999)}`,
    "Ce-Time": now,
    "Content-Type": "application/json",
  };
}

