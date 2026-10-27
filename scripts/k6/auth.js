// Kimlik dogrulama senaryosu: giris + /me + refresh + (istege bagli) cikis.
// DIKKAT: giris ucu hiz sinirlidir (IP basina 30/15 dk, e-posta basina 10/15 dk). Bu test sinirin DAVRANISINI da olcer:
// 200 ve 429 kabul edilir; 5xx ve 401 (dogru parola ile) hata sayilir. Staging'de hiz siniri eslemeleri
// yuk testi IP'si icin gevsetilmediyse dusuk VU kullanin.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE_URL, JSON_HEADERS, authHeaders, accounts } from './lib.js';

const limited = new Counter('auth_rate_limited');

export const options = {
  scenarios: {
    logins: {
      executor: 'constant-arrival-rate',
      rate: Number(__ENV.RATE || 1),       // sn basina giris denemesi
      timeUnit: '1s',
      duration: __ENV.DURATION || '2m',
      preAllocatedVUs: 5,
      maxVUs: 20,
    },
  },
  thresholds: {
    // 429 beklenen yanittir; sunucu hatasi %1'den az olmali
    'http_req_duration{name:POST /api/auth/login}': ['p(95)<800'],
    checks: ['rate>0.99'],
  },
};

export function setup() {
  const a = accounts();
  if (a.length === 0) throw new Error('K6_EMAIL ve K6_PASSWORD gerekli');
  return { accs: a };
}

export default function (data) {
  const acc = data.accs[Math.floor(Math.random() * data.accs.length)];
  const res = http.post(`${BASE_URL}/api/auth/login`, JSON.stringify({ email: acc.email, password: acc.password, client: 'web' }), {
    headers: JSON_HEADERS,
    tags: { name: 'POST /api/auth/login' },
    responseCallback: http.expectedStatuses(200, 429),
  });
  if (res.status === 429) {
    limited.add(1);
    check(res, { 'Retry-After var': (r) => r.headers['Retry-After'] !== undefined });
    sleep(2);
    return;
  }
  const ok = check(res, { 'giris 200': (r) => r.status === 200, 'token var': (r) => !!r.json('accessToken') });
  if (!ok) return;

  const access = res.json('accessToken');
  const refresh = res.json('refreshToken');
  check(http.get(`${BASE_URL}/api/auth/me`, { ...authHeaders(access), tags: { name: 'GET /api/auth/me' } }), {
    'me 200': (r) => r.status === 200,
  });

  const r2 = http.post(`${BASE_URL}/api/auth/refresh`, JSON.stringify({ refreshToken: refresh }), {
    headers: JSON_HEADERS,
    tags: { name: 'POST /api/auth/refresh' },
    responseCallback: http.expectedStatuses(200, 429),
  });
  check(r2, { 'refresh 200/429': (r) => r.status === 200 || r.status === 429 });
  sleep(1);
}
