/**
 * black-friday.js — ACT I DEMO
 *
 * Ramps from 0 → 500 VU over 10 minutes.
 * Against Level 0 (Apache), this WILL crash the stack around 50-100 VU.
 * Against Level 1+, watch the breakpoint move dramatically right.
 *
 * Prometheus remote-write output: K6_OUT=experimental-prometheus-rw
 */
import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, randomPage, checkResponse, THRESHOLDS_RELAXED } from './lib/helpers.js';

export const options = {
  thresholds: THRESHOLDS_RELAXED,
  scenarios: {
    black_friday_ramp: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m',  target: 10  },  // warm up
        { duration: '2m',  target: 50  },  // Level 0 usually dies here
        { duration: '2m',  target: 100 },
        { duration: '2m',  target: 200 },
        { duration: '2m',  target: 350 },
        { duration: '2m',  target: 500 },  // Level 1 still standing
        { duration: '1m',  target: 500 },  // hold peak
        { duration: '2m',  target: 0   },  // ramp down
      ],
    },
  },
};

export default function () {
  const url = `${BASE_URL}${randomPage()}`;
  const res = http.get(url, {
    headers: { 'Accept': 'text/html,application/json' },
    tags: { scenario: 'black_friday' },
  });
  checkResponse(res, 'page');
  sleep(Math.random() * 2 + 0.5);
}
