// Akis senaryosu: giris (setup) -> akis oku (sayfalama) -> gonderi detayi -> begen / begeniyi geri al.
// Gonderi OLUSTURMA varsayilan kapali (WRITE_POSTS=1 ile acilir; saatte 20 sinir vardir, staging'i kirletir).
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';
import { BASE_URL, baseThresholds, authHeaders, loginAll, tokenFor, get, rand, allow429 } from './lib.js';

// 429 (hiz siniri) beklenen yuk sonucudur: http_req_failed'e sayilmaz, gercek hata 4xx/5xx olarak kalir
allow429();

const feedLatency = new Trend('feed_page_ms', true);

export const options = {
  scenarios: {
    readers: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: __ENV.RAMP || '1m', target: Number(__ENV.VUS || 20) },
        { duration: __ENV.HOLD || '3m', target: Number(__ENV.VUS || 20) },
        { duration: '30s', target: 0 },
      ],
    },
  },
  thresholds: {
    ...baseThresholds,
    feed_page_ms: ['p(95)<500'],
  },
};

export function setup() {
  return { tokens: loginAll() };
}

export default function (data) {
  const token = tokenFor(data.tokens);
  let cursor = null;
  let first = null;

  // 1-3 sayfa akis oku
  const pages = 1 + rand(3);
  for (let i = 0; i < pages; i++) {
    const q = `/api/feed?scope=latest&size=10${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`;
    const res = get(q, token, 'GET /api/feed');
    feedLatency.add(res.timings.duration);
    const ok = check(res, { 'akis 200/429': (r) => r.status === 200 || r.status === 429 });
    if (!ok || res.status !== 200) break;
    const body = res.json();
    if (!first && body.items && body.items.length > 0) first = body.items[rand(body.items.length)];
    cursor = body.nextCursor;
    if (!cursor) break;
    sleep(0.3);
  }

  if (first) {
    check(get(`/api/posts/${first.id}`, token, 'GET /api/posts/{id}'), { 'detay 200/429': (r) => r.status === 200 || r.status === 429 });
    const put = http.put(`${BASE_URL}/api/posts/${first.id}/like`, null, { ...authHeaders(token), tags: { name: 'PUT /api/posts/{id}/like' } });
    check(put, { 'begen 2xx/429': (r) => (r.status >= 200 && r.status < 300) || r.status === 429 });
    // Staging verisini bozmamak icin begeniyi geri al
    const del = http.del(`${BASE_URL}/api/posts/${first.id}/like`, null, { ...authHeaders(token), tags: { name: 'DELETE /api/posts/{id}/like' } });
    check(del, { 'begeni geri 2xx/429': (r) => (r.status >= 200 && r.status < 300) || r.status === 429 });
  }

  if (__ENV.WRITE_POSTS === '1' && rand(100) < 2) {
    const res = http.post(`${BASE_URL}/api/posts`, JSON.stringify({ text: `k6 yuk testi ${Date.now()}` }), {
      ...authHeaders(token),
      tags: { name: 'POST /api/posts' },
    });
    check(res, { 'gonderi 201/429': (r) => r.status === 201 || r.status === 429 });
  }
  sleep(1 + Math.random());
}
