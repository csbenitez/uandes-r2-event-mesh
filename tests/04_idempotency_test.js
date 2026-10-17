// tests/04_idempotency_test.js
// Prueba de Idempotencia: 1000 eventos con 10% duplicados
// Uso: k6 run tests/04_idempotency_test.js -e TARGET_URL="http://..." -e TOTAL=1000

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';
import { SharedArray } from 'k6/data';
import exec from 'k6/execution';

// Métricas custom
const uniqueSent = new Counter('test_unique_sent');
const duplicatesSent = new Counter('test_duplicates_sent');

// Pool de matchIds únicos (compartido entre VUs)
const uniqueMatchIds = new SharedArray('matchIds', function () {
    const total = parseInt(__ENV.TOTAL || '1000');
    const uniqueCount = Math.floor(total * 0.9); // 90% únicos
    const ids = [];
    for (let i = 0; i < uniqueCount; i++) {
        ids.push(`MATCH-${Date.now()}-${i.toString().padStart(6, '0')}`);
    }
    return ids;
});

export const options = {
    scenarios: {
        idempotency_test: {
            executor: 'shared-iterations',
            vus: 10,
            iterations: parseInt(__ENV.TOTAL || '1000'),
            maxDuration: '5m',
        },
    },
    thresholds: {
        http_req_failed: ['rate<0.01'], // <1% de errores
        http_req_duration: ['p(95)<500'], // 95% bajo 500ms
    },
};

const TARGET_URL = __ENV.TARGET_URL || 'http://localhost:8090/events';
const DUPLICATE_RATE = parseFloat(__ENV.DUPLICATE_RATE || '0.10');

export default function () {
    const iteration = exec.scenario.iterationInTest;
    const shouldDuplicate = Math.random() < DUPLICATE_RATE;
    
    let matchId;
    let isDuplicate = false;

    if (shouldDuplicate && uniqueMatchIds.length > 0) {
        // Seleccionar matchId existente (DUPLICADO)
        const randomIndex = Math.floor(Math.random() * uniqueMatchIds.length);
        matchId = uniqueMatchIds[randomIndex];
        isDuplicate = true;
        duplicatesSent.add(1);
    } else {
        // Usar matchId único del pool
        const index = Math.floor((iteration * 0.9) % uniqueMatchIds.length);
        matchId = uniqueMatchIds[index] || `MATCH-${Date.now()}-${iteration}`;
        uniqueSent.add(1);
    }

    const payload = JSON.stringify({
        match_id: matchId,
        prosumer_id: `PROS-${Math.floor(Math.random() * 1000).toString().padStart(4, '0')}`,
        consumer_id: `CONS-${Math.floor(Math.random() * 1000).toString().padStart(4, '0')}`,
        kwh_matched: parseFloat((Math.random() * 50).toFixed(2)),
        price_cop: parseFloat((Math.random() * 500 + 300).toFixed(2)),
        timestamp: new Date().toISOString(),
    });

    const params = {
        headers: {
            'Ce-Specversion': '1.0',
            'Ce-Type': 'com.voltera.match.created',
            'Ce-Source': '//test/idempotency/k6',
            'Ce-Id': `evt-${matchId}-${Date.now()}`,
            'Ce-Time': new Date().toISOString(),
            'Content-Type': 'application/json',
        },
        tags: {
            duplicate: isDuplicate ? 'yes' : 'no',
        },
    };

    const response = http.post(TARGET_URL, payload, params);

    check(response, {
        'status is 2xx': (r) => r.status >= 200 && r.status < 300,
    });

    // Log cada 100 eventos
    if (iteration > 0 && iteration % 100 === 0) {
        console.log(`[${iteration}] ${isDuplicate ? '🔁 DUPLICATE' : '✅ UNIQUE'}: ${matchId}`);
    }
}

export function handleSummary(data) {
    const uniqueCount = data.metrics.test_unique_sent?.values?.count || 0;
    const duplicateCount = data.metrics.test_duplicates_sent?.values?.count || 0;
    const total = uniqueCount + duplicateCount;

    console.log('\n' + '='.repeat(60));
    console.log('📊 RESUMEN DE PRUEBA DE IDEMPOTENCIA');
    console.log('='.repeat(60));
    console.log(`Total enviado:        ${total}`);
    console.log(`  • Únicos:           ${uniqueCount} (${((uniqueCount/total)*100).toFixed(1)}%)`);
    console.log(`  • Duplicados:       ${duplicateCount} (${((duplicateCount/total)*100).toFixed(1)}%)`);
    console.log('='.repeat(60));
    console.log('✅ Ahora valida en PostgreSQL que hay SOLO eventos únicos');
    console.log('='.repeat(60) + '\n');

    return {
        'stdout': JSON.stringify(data, null, 2),
    };
}
