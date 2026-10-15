import http from 'k6/http';
import { check, sleep } from 'k6';
import { buildAmiPayload, buildCloudEventHeaders } from './utils.js';

// Parámetros configurables vía variables de entorno (-e VARIABLE=valor)
const count = parseInt(__ENV.COUNT || '1', 10);
const sleepDuration = parseFloat(__ENV.SLEEP || '1.0');
const targetUrl = __ENV.TARGET_URL || 'http://localhost:8080/events';

export const options = {
  insecureSkipTLSVerify: true,
  scenarios: {
    smoke_reading: {
      executor: 'per-vu-iterations',
      vus: 1,
      iterations: count,
      maxDuration: '5m',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'], // Menos del 1% de errores
    http_req_duration: ['p(95)<2000'], // 95% de respuestas bajo 2s
  },
};

export default function () {
  const payload = buildAmiPayload();
  const headers = buildCloudEventHeaders();

  console.log(`[01-Smoke] Emisión hacia: ${targetUrl} (ID: ${headers['Ce-Id']}, NIU: ${payload.niu})`);
  console.log(`           Payload: ${JSON.stringify(payload)}`);

  const res = http.post(targetUrl, JSON.stringify(payload), { headers });

  const success = check(res, {
    'HTTP status exitoso (200, 201 o 202)': (r) => [200, 201, 202].includes(r.status),
  });

  if (success) {
    console.log(`[OK] Evento entregado exitosamente. HTTP ${res.status}`);
  } else {
    console.error(`[ERROR] Falló la entrega del evento. HTTP ${res.status}: ${res.body}`);
  }

  if (count > 1 && sleepDuration > 0) {
    sleep(sleepDuration);
  }
}

