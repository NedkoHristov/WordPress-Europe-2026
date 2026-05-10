/**
 * spike.js — Instant spike: 0 → 500 VU in 10s
 * Tests the resilience of the stack under sudden burst traffic
 * (e.g., HN front page / viral post scenario)
 */
import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, randomPage, checkResponse, THRESHOLDS_RELAXED } from './lib/helpers.js';

export const options = {
  thresholds: THRESHOLDS_RELAXED,
  scenarios: {
    spike: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '10s', target: 500 }, // instant spike
        { duration: '3m',  target: 500 }, // sustain
        { duration: '30s', target: 0   }, // drain
      ],
    },
  },
};

export default function () {
  const res = http.get(`${BASE_URL}${randomPage()}`, {
    tags: { scenario: 'spike' },
  });
  checkResponse(res, 'spike');
  sleep(0.5);
}
