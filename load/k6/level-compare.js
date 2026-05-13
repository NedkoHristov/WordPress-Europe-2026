/**
 * level-compare.js — Before/After Level Comparison Test
 *
 * Ramps to 50 VU over 1 min, holds 2 min, ramps down.
 * Total: ~4 minutes. Run between each optimization level.
 *
 * Level 0 (Apache):   Crashes ~20-30 VU. Error rate climbs fast.
 * Level 1 (Nginx+FPM): Handles 50 VU with some latency.
 * Level 2 (+ Cache):  50 VU barely registers. Sub-100ms P95.
 *
 * Usage:
 *   docker compose run --rm k6 run /scripts/level-compare.js
 */
import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// Custom metrics for clearer Grafana visibility
const errorCount  = new Counter('level_errors');
const successRate = new Rate('level_success_rate');
const pageLoad    = new Trend('level_page_load_ms', true);

// The BASE_URL must match the WordPress siteurl host to avoid canonical redirects.
// Use host.docker.internal:8080 so the Host header matches siteurl (http://localhost:8080).
const BASE_URL = __ENV.BASE_URL || 'http://host.docker.internal:8080';

const PAGES = [
  '/',
  '/post-2498/',
  '/category/uncategorized/',
  '/wp-json/wp/v2/posts?per_page=5',
  '/?s=hello',
  '/',
  '/',
];

export const options = {
  scenarios: {
    ramp_up: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '30s', target: 10  },  // warm up
        { duration: '30s', target: 30  },  // start pushing
        { duration: '60s', target: 50  },  // main load
        { duration: '60s', target: 50  },  // hold at peak
        { duration: '30s', target: 0   },  // ramp down
      ],
    },
  },
  thresholds: {
    // Intentionally relaxed — Level 0 WILL fail these
    http_req_duration: ['p(95)<5000'],
    http_req_failed:   ['rate<0.5'],
  },
};

export default function () {
  const page = PAGES[Math.floor(Math.random() * PAGES.length)];
  const url  = `${BASE_URL}${page}`;

  const res = http.get(url, {
    headers: { 'Accept': 'text/html,application/json' },
    tags: { page },
    timeout: '10s',
  });

  const ok = check(res, {
    'status 200': (r) => r.status === 200,
    'not 5xx':    (r) => r.status < 500,
    'fast enough': (r) => r.timings.duration < 3000,
  });

  successRate.add(ok);
  pageLoad.add(res.timings.duration);
  if (!ok) errorCount.add(1);

  sleep(0.5 + Math.random() * 1.5);
}

export function handleSummary(data) {
  const dur = data.metrics.http_req_duration;
  const p95 = (dur && dur.values && dur.values['p(95)']) ? dur.values['p(95)'] : 0;
  const reqs = data.metrics.http_reqs;
  const rps  = (reqs && reqs.values) ? reqs.values.rate : 0;
  const fail = data.metrics.http_req_failed;
  const err  = (fail && fail.values) ? fail.values.rate * 100 : 0;

  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  LEVEL COMPARE RESULT                ║');
  console.log('╠══════════════════════════════════════╣');
  console.log(`║  RPS (avg):     ${rps.toFixed(1).padStart(8)} req/s         ║`);
  console.log(`║  P95 latency:   ${p95.toFixed(0).padStart(8)} ms            ║`);
  console.log(`║  Error rate:    ${err.toFixed(1).padStart(8)} %              ║`);
  console.log('╚══════════════════════════════════════╝\n');

  return {};
}
