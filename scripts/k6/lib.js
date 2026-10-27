// Ortak k6 yardimcilari. Sirlar ENV'den gelir (K6_EMAIL / K6_PASSWORD ...), koda yazilmaz.
import http from 'k6/http';
import { check, fail } from 'k6';

export const BASE_URL = (__ENV.BASE_URL || 'http://localhost:8080').replace(/\/+$/, '');

// Ortak esikler: p95 < 500 ms, hata orani < %1 (senaryo basina ek esik eklenebilir)
export const baseThresholds = {
  http_req_failed: ['rate<0.01'],
  http_req_duration: ['p(95)<500'],
  checks: ['rate>0.99'],
};

/** 2xx/3xx ve 429 'beklenen' sayilir (hiz siniri yuk altinda normal). init asamasinda cagrilmali. */
export function allow429() {
  http.setResponseCallback(http.expectedStatuses({ min: 200, max: 399 }, 429));
}

export const JSON_HEADERS = { 'Content-Type': 'application/json', Accept: 'application/json' };

export function authHeaders(token) {
  return { headers: { ...JSON_HEADERS, Authorization: `Bearer ${token}` } };
}

/**
 * Test hesaplari: K6_EMAIL/K6_PASSWORD (+ istege bagli K6_EMAIL_2/K6_PASSWORD_2 ...).
 * Giris ucu sinirli (30/15dk/IP, 10/15dk/e-posta): token'lar setup()'ta bir kez alinir, VU'lar paylasir.
 * Access token 15 dk gecerlidir: senaryolari 12 dakikayi gecmeyecek sekilde tutun.
 */
export function accounts() {
  const list = [];
  for (let i = 1; i <= 10; i++) {
    const sfx = i === 1 ? '' : `_${i}`;
    const email = __ENV[`K6_EMAIL${sfx}`];
    const password = __ENV[`K6_PASSWORD${sfx}`];
    if (email && password) list.push({ email, password });
  }
  return list;
}

export function login(email, password) {
  const res = http.post(`${BASE_URL}/api/auth/login`, JSON.stringify({ email, password, client: 'web' }), {
    headers: JSON_HEADERS,
    tags: { name: 'POST /api/auth/login' },
  });
  const ok = check(res, { 'giris 200': (r) => r.status === 200 });
  if (!ok) return null;
  return res.json('accessToken');
}

/** setup() icin: tum hesaplarla giris yapip token listesi dondurur. */
export function loginAll() {
  const accs = accounts();
  if (accs.length === 0) fail('K6_EMAIL ve K6_PASSWORD ortam degiskenleri gerekli (bkz. scripts/k6/README.md)');
  const tokens = [];
  for (const a of accs) {
    const t = login(a.email, a.password);
    if (t) tokens.push(t);
  }
  if (tokens.length === 0) fail('hicbir hesapla giris yapilamadi');
  return tokens;
}

export function tokenFor(tokens) {
  return tokens[(__VU - 1) % tokens.length];
}

/** URL'lerdeki degisken parcalar metrik kardinalitesini sisirmesin diye ad etiketi. */
export function get(path, token, name) {
  return http.get(`${BASE_URL}${path}`, { ...authHeaders(token), tags: { name: name || `GET ${path}` } });
}

export function rand(n) {
  return Math.floor(Math.random() * n);
}

export function uuid() {
  return 'k6-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
}
