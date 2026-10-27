// Duman testi: herkese acik uclar + tek giris + birkac okuma. Kisa ve hafif (1 VU, 30 sn).
// Calistirma: k6 run -e BASE_URL=https://staging.example -e K6_EMAIL=... -e K6_PASSWORD=... scripts/k6/smoke.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL, baseThresholds, loginAll, tokenFor, get } from './lib.js';

export const options = {
  vus: Number(__ENV.VUS || 1),
  duration: __ENV.DURATION || '30s',
  thresholds: baseThresholds,
};

export function setup() {
  return { tokens: loginAll() };
}

export default function (data) {
  const token = tokenFor(data.tokens);

  const health = http.get(`${BASE_URL}/actuator/health`, { tags: { name: 'GET /actuator/health' } });
  check(health, { 'saglik 200': (r) => r.status === 200 });

  check(http.get(`${BASE_URL}/api/status`, { tags: { name: 'GET /api/status' } }), { 'status 200': (r) => r.status === 200 });
  check(http.get(`${BASE_URL}/api/news?size=10`, { tags: { name: 'GET /api/news' } }), { 'haber 200': (r) => r.status === 200 });
  check(http.get(`${BASE_URL}/api/menu`, { tags: { name: 'GET /api/menu' } }), { 'menu 200': (r) => r.status === 200 });

  check(get('/api/auth/me', token, 'GET /api/auth/me'), { 'me 200': (r) => r.status === 200 });
  check(get('/api/feed?scope=latest&size=10', token, 'GET /api/feed'), { 'akis 200': (r) => r.status === 200 });
  check(get('/api/conversations?size=20', token, 'GET /api/conversations'), { 'sohbet listesi 200': (r) => r.status === 200 });
  sleep(1);
}
