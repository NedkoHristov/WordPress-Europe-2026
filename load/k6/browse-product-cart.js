/**
 * browse-product-cart.js — WooCommerce realistic user journey
 * ACT IV demo: shows which requests bypass cache (cart/checkout)
 * and which are served statically (product pages)
 */
import http from 'k6/http';
import { sleep, group } from 'k6';
import { BASE_URL, checkResponse, THRESHOLDS_RELAXED } from './lib/helpers.js';

export const options = {
  thresholds: THRESHOLDS_RELAXED,
  scenarios: {
    woo_shoppers: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '1m',  target: 20  },
        { duration: '3m',  target: 100 },
        { duration: '2m',  target: 100 },
        { duration: '1m',  target: 0   },
      ],
    },
  },
};

export default function () {
  group('browse homepage', () => {
    const res = http.get(`${BASE_URL}/`, { tags: { page: 'home' } });
    checkResponse(res, 'home');
    sleep(1 + Math.random() * 2);
  });

  group('browse shop', () => {
    const res = http.get(`${BASE_URL}/shop/`, { tags: { page: 'shop' } });
    checkResponse(res, 'shop');
    sleep(1 + Math.random() * 2);
  });

  group('view product', () => {
    // Product slug — adjust to match your seeded product
    const res = http.get(`${BASE_URL}/product/test-product-1/`, { tags: { page: 'product' } });
    checkResponse(res, 'product');
    sleep(2 + Math.random() * 3);
  });

  group('add to cart (REST)', () => {
    // This hits WP origin even in Level 4 — the "dynamic island"
    const res = http.post(
      `${BASE_URL}/wp-json/wc/store/v1/cart/add-item`,
      JSON.stringify({ id: 1, quantity: 1 }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Nonce': 'demo-nonce', // populated by JS in real browser
        },
        tags: { page: 'add-to-cart' },
      }
    );
    // Cart endpoint returns 200 or 400 — both are "ok" for the demo
    sleep(1);
  });

  group('view cart', () => {
    const res = http.get(`${BASE_URL}/cart/`, { tags: { page: 'cart' } });
    sleep(2);
  });
}
