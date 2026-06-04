/**
 * soak.js — 1 hour flat load at 50 VU
 * Reveals memory leaks, slow cache eviction, connection pool exhaustion over time
 * Run overnight. Watch Redis evictions, PHP-FPM max_requests, swap usage.
 */
import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, randomPage, checkResponse, THRESHOLDS_STRICT } from './lib/helpers.js';

export const options = {
  thresholds: THRESHOLDS_STRICT,
  scenarios: {
    soak: {
      executor: 'constant-vus',
      vus: 50,
      duration: '1h',
    },
  },
};

export default function () {
  const res = http.get(`${BASE_URL}${randomPage()}`, {
    tags: { scenario: 'soak' },
  });
  checkResponse(res, 'soak');
  sleep(1 + Math.random());
}
