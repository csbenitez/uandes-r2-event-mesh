import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';
import { buildAmiPayload, buildCloudEventHeaders, getRandomInt } from './utils.js';

// Métricas personalizadas
const eventsCounter = new Counter('ami_events_sent_total');
const latencyTrend = new Trend('ami_event_processing_latency');

const targetUrl = __ENV.TARGET_URL || 'http://localhost:8080/events';

export const options = {
  insecureSkipTLSVerify: true,
  // Escenario de carga escalonado por etapas
  stages: [
    { duration: '15s', target: 10 }, // Ramp-up a 10 medidores concurrentes
    { duration: '30s', target: 25 }, // Carga sostenida con 25 medidores concurrentes
    { duration: '15s', target: 50 }, // Pico de estrés con 50 medidores
    { duration: '10s', target: 0 },  // Ramp-down a 0
  ],
  thresholds: {
    http_req_failed: ['rate<0.02'],       // Máximo 2% de fallos tolerados
    http_req_duration: ['p(95)<500'],     // 95% de las solicitudes deben responder en < 500ms
    ami_events_sent_total: ['count>50'], // Asegura que se emita un volumen representativo
  },
};

export default function () {
  // Cada usuario virtual simula un medidor con NIU dinámico
  const simulatedNiu = `100${getRandomInt(1000, 9999)}`;
  const payload = buildAmiPayload({ niu: simulatedNiu });
  const headers = buildCloudEventHeaders();

  const startTime = Date.now();
  const res = http.post(targetUrl, JSON.stringify(payload), {
    headers: headers,
    tags: { name: 'PostAmiCloudEvent' },
  });
  const latency = Date.now() - startTime;

  latencyTrend.add(latency);
  eventsCounter.add(1);

  check(res, {
    'Broker aceptó el evento (200, 201, 202)': (r) => [200, 201, 202].includes(r.status),
  });

  // Intervalo realista entre lecturas por medidor (0.5s - 1.5s)
  sleep(Math.random() * 1.0 + 0.5);
}

