/**
 * browse.js — simple smoke/browse test (10 VU × 1 min)
 * Used by 'make load-smoke' and as a quick before/after comparison
 */
import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, randomPage, checkResponse } from './lib/helpers.js';

export const options = {
  thresholds: {
    http_req_duration: ['p(95)<2000'],
    http_req_failed: ['rate<0.05'],
  },
};

export default function () {
  const res = http.get(`${BASE_URL}${randomPage()}`, {
    tags: { scenario: 'browse' },
  });
  checkResponse(res, 'browse');
  sleep(1 + Math.random());
}
