/**
 * lib/helpers.js — shared helpers for all k6 scenarios
 */
import { check } from 'k6';
import http from 'k6/http';

export const BASE_URL = __ENV.BASE_URL || 'http://nginx:80';

export const PAGES = [
  '/',
  '/?page_id=2',
  '/?p=1',
  '/wp-json/wp/v2/posts?per_page=5',
];

export const WOO_PAGES = [
  '/shop/',
  '/shop/page/2/',
  '/product-category/uncategorized/',
];

export function randomPage() {
  return PAGES[Math.floor(Math.random() * PAGES.length)];
}

export function randomWooPage() {
  return WOO_PAGES[Math.floor(Math.random() * WOO_PAGES.length)];
}

export function checkResponse(res, name) {
  return check(res, {
    [`${name} status 200`]: (r) => r.status === 200,
    [`${name} not empty`]: (r) => r.body && r.body.length > 100,
    [`${name} no PHP error`]: (r) => !r.body || !r.body.includes('Fatal error'),
  });
}

export const THRESHOLDS_STRICT = {
  http_req_duration: ['p(95)<500', 'p(99)<2000'],
  http_req_failed: ['rate<0.01'],
  checks: ['rate>0.99'],
};

export const THRESHOLDS_RELAXED = {
  http_req_duration: ['p(95)<2000'],
  http_req_failed: ['rate<0.05'],
};
