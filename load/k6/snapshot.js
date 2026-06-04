/**
 * snapshot.js — 90-second presentation snapshot
 *
 * Purpose: capture screenshots for Grafana without waiting 3-4 minutes.
 *   - Ramp 0→50 VU in 20s  → shows the ramp shape on the VU/RPS graph
 *   - Hold 50 VU for 50s   → saturates the stack, latency spikes visible
 *   - Ramp down in 20s     → clean exit so Grafana shows a complete story
 *   Total: 90 seconds
 *
 * Thresholds are intentionally absent — this script is for observation, not
 * pass/fail gating. Use level-compare.js for gating.
 *
 * Usage (via Makefile):
 *   make snapshot          ← warmup + 90s burst on whatever level is running
 *   make snapshot-l1       ← switch to level-1 then snapshot
 *   make snapshot-l2       ← switch to level-2 then snapshot
 *
 * Direct usage:
 *   docker compose --profile load run --rm \
 *     -e BASE_URL=http://host.docker.internal:8080 \
 *     k6 run /scripts/snapshot.js
 */
import http from 'k6/http';
import { sleep, check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://host.docker.internal:8080';

// Same pages as level-compare so metrics are comparable across runs
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
    snapshot: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '20s', target: 50 },  // ramp — fills the VU ramp shape
        { duration: '50s', target: 50 },  // hold — saturate stack, build latency data
        { duration: '20s', target: 0  },  // ramp down — clean end on graph
      ],
    },
  },
};

export default function () {
  const page = PAGES[Math.floor(Math.random() * PAGES.length)];
  const url  = `${BASE_URL}${page}`;

  const res = http.get(url, {
    headers: { 'Accept': 'text/html,application/json' },
    tags: { page },
    timeout: '15s',
  });

  check(res, {
    'status 200': (r) => r.status === 200,
    'not 5xx':    (r) => r.status < 500,
  });

  sleep(0.3 + Math.random() * 0.7);
}

export function handleSummary(data) {
  const dur = data.metrics.http_req_duration;
  const p95 = (dur && dur.values && dur.values['p(95)']) ? dur.values['p(95)'] : 0;
  const reqs = data.metrics.http_reqs;
  const rps  = (reqs && reqs.values) ? reqs.values.rate : 0;
  const fail = data.metrics.http_req_failed;
  const err  = (fail && fail.values) ? fail.values.rate * 100 : 0;

  console.log('\n╔══════════════════════════════════════╗');
  console.log('║  SNAPSHOT RESULT (90s)               ║');
  console.log('╠══════════════════════════════════════╣');
  console.log(`║  Requests Per Second (avg): ${rps.toFixed(1).padStart(6)} req/s  ║`);
  console.log(`║  P95 latency:     ${p95.toFixed(0).padStart(8)} ms        ║`);
  console.log(`║  Error rate:      ${err.toFixed(1).padStart(8)} %          ║`);
  console.log('╚══════════════════════════════════════╝');
  console.log('  → Screenshot Grafana now: http://localhost:3000/d/wp-demo\n');

  return {};
}
