// Ortak k6 yardimcilari (yuk paketi). Betikler konteynerde /load (bu klasor) ve /fx (prep.js ciktisi) olarak baglanir.
// Sirlar kodda yok: token'lar prep.js ile JWT_SECRET'tan uretilir.
import http from 'k6/http';
import { SharedArray } from 'k6/data';
import { Counter } from 'k6/metrics';
import exec from 'k6/execution';

export const BASE = (__ENV.BASE || 'http://ldapp:8080').replace(/\/+$/, '');
const FX = __ENV.FX_DIR || '/fx';
export const OUT = __ENV.OUT_DIR || '/out';

export const tokens = new SharedArray('tokens', () => JSON.parse(open(`${FX}/tokens.json`)));
// Buyuk diziler (pairs, userIds) ayri SharedArray: VU basina kopyalanmaz (bellek)
const fxArr = new SharedArray('fx', () => { const f = JSON.parse(open(`${FX}/fixtures.json`)); delete f.pairs; delete f.userIds; return [f]; });
export const fx = fxArr[0];
export const pairs = new SharedArray('pairs', () => JSON.parse(open(`${FX}/fixtures.json`)).pairs);
export const userIds = new SharedArray('uids', () => JSON.parse(open(`${FX}/fixtures.json`)).userIds);

export const c429 = new Counter('ld_429'); // hiz siniri (hata sayilmaz)
export const cErr = new Counter('ld_errors'); // beklenmeyen durum (5xx, 0, beklenmeyen 4xx)
export const c503 = new Counter('ld_503'); // DB_TIMEOUT / servis dis

let WARM_S = __ENV.WARMUP_S === undefined ? 60 : Number(__ENV.WARMUP_S);
/** Isinma gerektirmeyen senaryolar (yaris/patlama) modul seviyesinde cagirir: tum istekler 'main' sayilir. */
export function noWarmup() { WARM_S = 0; }
/** Senaryo baslangicindan WARM_S sn sonrasina kadar 'warm' (olcume katilmaz), sonra 'main'. */
export function phase() {
  if (WARM_S <= 0) return 'main';
  return Date.now() - exec.scenario.startTime < WARM_S * 1000 ? 'warm' : 'main';
}

export const rnd = (n) => Math.floor(Math.random() * n);
export const pick = (a) => a[rnd(a.length)];
export const uuid = () => `${Date.now().toString(36)}-${__VU}-${__ITER}-${rnd(1e9).toString(36)}`;

/** VU basina farkli istemci IP (X-Forwarded-For). UYARI: ozel araliklar (10/8, 172.16/12, 192.168/16) guvenilir proxy sayilir ve atlanir -> genel (11.x) adres kullanilir. */
export function ipOf(vu) {
  return `11.${(vu >> 16) & 255}.${(vu >> 8) & 255}.${(vu & 255) || 1}`;
}

export function headers(token, extra) {
  const h = { 'Content-Type': 'application/json', Accept: 'application/json', 'X-Forwarded-For': ipOf(__VU), ...(extra || {}) };
  if (token) h.Authorization = `Bearer ${token}`;
  return h;
}

/**
 * Tek istek: sure/hata/429 ayri sayilir. expect: beklenen ek durum kodlari (orn. [409] yaris testlerinde).
 * Donus: k6 yaniti.
 */
export function call(method, path, name, token, body, expect) {
  const exp = expect || [];
  const params = {
    headers: headers(token),
    tags: { name, phase: phase() },
    responseCallback: http.expectedStatuses({ min: 200, max: 399 }, 429, ...exp),
    timeout: '30s',
  };
  const res = http.request(method, `${BASE}${path}`, body === undefined || body === null ? null : JSON.stringify(body), params);
  if (res.status === 429) {
    c429.add(1, { name });
  } else if (res.status === 503) {
    c503.add(1, { name });
    cErr.add(1, { name });
  } else if (res.status === 0 || res.status >= 500 || (res.status >= 400 && !exp.includes(res.status))) {
    cErr.add(1, { name });
  }
  return res;
}

export const get = (path, name, token) => call('GET', path, name, token);

export function tokenOf(userIdx) {
  return tokens[userIdx % tokens.length];
}
export const randomUser = () => rnd(tokens.length);

/** Tek senaryo: ilk WARMUP_S sn yarim VU (phase=warm, olcume katilmaz), sonra VU'ya yukselir ve DURATION boyunca tutar (phase=main). */
export function twoPhase(vus, duration, extra) {
  const warm = WARM_S;
  const ramp = Number(__ENV.RAMP_S || 10);
  const stages = [];
  if (warm > 0) {
    stages.push({ duration: '10s', target: Math.max(1, Math.ceil(vus / 2)) }, { duration: `${Math.max(1, warm - 10)}s`, target: Math.max(1, Math.ceil(vus / 2)) });
  }
  stages.push({ duration: `${ramp}s`, target: vus }, { duration, target: vus });
  return { main: { executor: 'ramping-vus', startVUs: 0, gracefulRampDown: '10s', gracefulStop: '15s', stages, ...(extra || {}) } };
}

/** Her uc nokta icin sub-metrikleri acan (ve p95 hedefini denetleyen) esikler. */
export function thresholdsFor(names, p95ms) {
  const t = {};
  for (const n of names) {
    t[`http_req_duration{phase:main,name:${n}}`] = [`p(95)<${p95ms[n] || p95ms.default || 400}`];
    t[`http_req_failed{phase:main,name:${n}}`] = ['rate<0.01'];
    t[`ld_429{name:${n}}`] = ['count>=0'];
    t[`ld_errors{name:${n}}`] = ['count>=0'];
  }
  t['http_req_duration{phase:main}'] = ['p(95)<1000'];
  t['http_req_failed{phase:main}'] = ['rate<0.01'];
  t['ld_429'] = ['count>=0'];
  t['ld_errors'] = ['count>=0'];
  t['ld_503'] = ['count>=0'];
  return t;
}

const q = (m, k) => (m && m.values && m.values[k] !== undefined ? m.values[k] : null);

/** handleSummary: /out/<ad>.json (makine okur) + stdout'a kompakt tablo. */
export function summaryFor(scen, data, extra) {
  const rows = {};
  for (const key of Object.keys(data.metrics)) {
    const m = key.match(/^http_req_duration\{phase:main,name:(.+)\}$/);
    if (!m) continue;
    const name = m[1];
    const d = data.metrics[key];
    const f = data.metrics[`http_req_failed{phase:main,name:${name}}`];
    const r4 = data.metrics[`ld_429{name:${name}}`];
    const er = data.metrics[`ld_errors{name:${name}}`];
    const passes = f && f.values ? (f.values.passes || 0) : 0; // k6: Rate.passes = "failed" olan istekler
    const fails = f && f.values ? (f.values.fails || 0) : 0;
    rows[name] = {
      n: passes + fails, p50: q(d, 'med'), p95: q(d, 'p(95)'), p99: q(d, 'p(99)'), avg: q(d, 'avg'), max: q(d, 'max'),
      unexpectedFail: passes, c429: r4 ? q(r4, 'count') || 0 : 0, errors: er ? q(er, 'count') || 0 : 0,
    };
  }
  const all = data.metrics['http_req_duration{phase:main}'];
  const allFail = data.metrics['http_req_failed{phase:main}'];
  const secs = (data.state && data.state.testRunDurationMs ? data.state.testRunDurationMs : 0) / 1000;
  const mainN = allFail && allFail.values ? (allFail.values.passes || 0) + (allFail.values.fails || 0) : 0;
  const out = {
    scenario: scen,
    at: new Date().toISOString(),
    vus: Number(__ENV.VUS || 0) || null,
    totalRequestsMain: mainN,
    overall: all ? { p50: q(all, 'med'), p95: q(all, 'p(95)'), p99: q(all, 'p(99)'), avg: q(all, 'avg'), max: q(all, 'max') } : null,
    failRateMain: allFail ? q(allFail, 'rate') : null,
    c429: q(data.metrics.ld_429, 'count') || 0,
    errors: q(data.metrics.ld_errors, 'count') || 0,
    c503: q(data.metrics.ld_503, 'count') || 0,
    runSeconds: secs,
    endpoints: rows,
    extra: extra || {},
  };
  const lines = [`\n== ${scen} == istek(main)=${mainN} 429=${out.c429} hata=${out.errors} 503=${out.c503} sure=${secs.toFixed(0)}s`];
  lines.push('ad'.padEnd(34) + 'n'.padStart(8) + 'p50'.padStart(8) + 'p95'.padStart(8) + 'p99'.padStart(8) + 'max'.padStart(8) + 'hata'.padStart(7) + '429'.padStart(7));
  for (const [n, r] of Object.entries(rows).sort()) {
    const f = (v) => (v === null ? '-' : v.toFixed(0)).padStart(8);
    lines.push(n.padEnd(34) + String(r.n).padStart(8) + f(r.p50) + f(r.p95) + f(r.p99) + f(r.max) + String(r.errors).padStart(7) + String(r.c429).padStart(7));
  }
  return { [`${OUT}/${scen}.json`]: JSON.stringify(out, null, 2), stdout: lines.join('\n') + '\n' };
}

export const summaryTrendStats = ['min', 'med', 'avg', 'p(90)', 'p(95)', 'p(99)', 'max'];
