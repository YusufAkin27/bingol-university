// Senaryo A: KIMLIK. 500 kullanici ayni anda giris yapar (sabah yogunlugu), ardindan refresh ve ilk ekran istegi.
// Gercek bcrypt calisir (seed-load-extra.sql tum sentetik kullanicilara bilinen bir parola yazar). Her VU ayri IP
// (X-Forwarded-For) ve ayri e-posta kullanir; IP/e-posta limitine takilan istekler (429) ayri sayilir.
// Ortam: VUS (500), LOGIN_PASSWORD (varsayilan LoadTest-2026!), BG=1 ise ayni anda hafif okuma yuku ekler (cakisma testi)
import http from 'k6/http';
import { sleep, check } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { noWarmup, call, headers, BASE, c429, cErr, ipOf, rnd, get, tokenOf, randomUser, summaryFor, summaryTrendStats, thresholdsFor } from './lib.js';

const VUS = Number(__ENV.VUS || 500);
const PASS = __ENV.LOGIN_PASSWORD || 'LoadTest-2026!';
const OFFSET = Number(__ENV.USER_OFFSET || 5000); // seedN e-postasi: N = OFFSET + vu (rate limit/oturum cakismasin)
noWarmup();
const loginE2e = new Trend('login_e2e_ms', true); // ilk denemeden basarili girise kadar (429'da Retry-After kadar bekleyip yeniden dener)
const loginOk = new Counter('login_ok');
const loginGaveUp = new Counter('login_gaveup');
const N = { login: 'POST /auth/login', refresh: 'POST /auth/refresh', first: 'GET /me/summary (login sonrasi)', bg: 'GET /feed (arka plan)' };

const scen = {
  burst: { executor: 'per-vu-iterations', vus: VUS, iterations: 1, maxDuration: '3m', tags: { phase: 'main' }, exec: 'burst' },
};
if (__ENV.BG === '1') {
  scen.bg = { executor: 'constant-vus', vus: Number(__ENV.BG_VUS || 100), duration: '40s', tags: { phase: 'main' }, exec: 'bg' };
}
export const options = {
  scenarios: scen,
  thresholds: thresholdsFor(Object.values(N), { default: 800, [N.login]: 3000, [N.refresh]: 800 }),
  summaryTrendStats,
};

export function burst() {
  const email = `seed${OFFSET + __VU}@bingol.edu.tr`;
  const t0 = Date.now();
  let r = null;
  for (let attempt = 0; attempt < 12; attempt++) {
    r = call('POST', '/api/auth/login', N.login, null, { email, password: PASS, client: 'mobile' });
    if (r.status !== 429 && r.status !== 503) break;
    sleep(Number(r.headers['Retry-After'] || 3) + Math.random()); // istemci geri cekilmesi
  }
  if (!r || r.status !== 200) { loginGaveUp.add(1); return; }
  loginOk.add(1);
  loginE2e.add(Date.now() - t0);
  const body = r.json();
  check(r, { 'access+refresh var': () => !!body.accessToken && !!body.refreshToken });
  sleep(1 + Math.random());
  const rr = call('POST', '/api/auth/refresh', N.refresh, null, { refreshToken: body.refreshToken, client: 'mobile' });
  const at = rr.status === 200 ? rr.json('accessToken') : body.accessToken;
  get('/api/me/summary', N.first, at);
}

export function bg() {
  get('/api/feed?scope=top&size=12', N.bg, tokenOf(randomUser()));
  sleep(1 + Math.random() * 2);
}

export function handleSummary(data) {
  const t = (n, k) => (data.metrics[n] && data.metrics[n].values ? data.metrics[n].values[k] : null);
  const extra = { loginOk: t('login_ok', 'count'), loginGaveUp: t('login_gaveup', 'count'), e2e_p50: t('login_e2e_ms', 'med'), e2e_p95: t('login_e2e_ms', 'p(95)'), e2e_max: t('login_e2e_ms', 'max') };
  const o = summaryFor(__ENV.SCEN_NAME || 'A-auth', data, extra);
  o.stdout += 'giris (429 sonrasi yeniden denemeli): ' + JSON.stringify(extra) + '\n';
  return o;
}
