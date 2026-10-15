import http from 'k6/http';
import { check, sleep } from 'k6';
import { buildAmiPayload, buildCloudEventHeaders, getRandomFloat } from './utils.js';

// Escenario enfocado en prosumidores solares (alta inyección a la red)
const targetUrl = __ENV.TARGET_URL || 'http://localhost:8080/events';
const prosumerNiu = __ENV.NIU || '98234710';
const iterations = parseInt(__ENV.COUNT || '5', 10);

export const options = {
  insecureSkipTLSVerify: true,
  scenarios: {
    prosumer_readings: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: iterations,
      maxDuration: '5m',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  // Inyección solar alta (8.0 a 14.0 kWh) y consumo bajo (0.5 a 2.5 kWh)
  const importEnergy = __ENV.KWH_IMPORT !== undefined ? parseFloat(__ENV.KWH_IMPORT) : getRandomFloat(0.5, 2.5, 2);
  const exportEnergy = __ENV.KWH_EXPORT !== undefined ? parseFloat(__ENV.KWH_EXPORT) : getRandomFloat(8.0, 14.5, 2);

  const payload = buildAmiPayload({
    niu: prosumerNiu,
    kwhImportados: importEnergy,
    kwhExportados: exportEnergy,
  });

  const headers = buildCloudEventHeaders(
    'com.voltera.ami.lectura_registrada',
    `evt-prosumer-${Date.now()}`,
    '//onprem/prosumidores/solar-p2p'
  );

  console.log(`[02-Prosumidor] Enviando lectura: NIU=${payload.niu} | Import=${payload.kwh_importados} kWh | Export=${payload.kwh_exportados} kWh`);

  const res = http.post(targetUrl, JSON.stringify(payload), { headers });

  check(res, {
    'Lectura de prosumidor aceptada (200, 201, 202)': (r) => [200, 201, 202].includes(r.status),
  });

  sleep(1);
}

