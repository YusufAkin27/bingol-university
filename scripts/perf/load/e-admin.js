// Senaryo E: YONETIM PANELI. Birkac yonetici (ADMIN_VUS, varsayilan 8) liste/arama/rapor uclarini gezer, ayrica CSV disa
// aktarimi (20k kullanici satiri + denetim kaydi) sure/bayt olarak olculur. Kullanici listesi 20k, denetim kaydi 100k+ satir.
// Ortam: ADMIN_VUS (8), DURATION (3m), WARMUP_S (30), CSV_VUS (2)
import http from 'k6/http';
import { sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { call, rnd, pick, fx, twoPhase, thresholdsFor, summaryFor, summaryTrendStats, BASE, headers, OUT, noWarmup } from './lib.js';

const VUS = Number(__ENV.ADMIN_VUS || 8);
const CSV_VUS = Number(__ENV.CSV_VUS || 2);
const N = {
  users: 'GET /admin/users', usersQ: 'GET /admin/users?q=', usersDeep: 'GET /admin/users (derin sayfa)', audit: 'GET /admin/audit',
  auditDeep: 'GET /admin/audit (derin sayfa)', reports: 'GET /admin/reports', overview: 'GET /admin/analytics/overview',
  engagement: 'GET /admin/analytics/engagement', active: 'GET /admin/analytics/active-users', retention: 'GET /admin/analytics/retention',
  content: 'GET /admin/analytics/content',
};
const csvMs = new Trend('admin_csv_ms', true);
const csvBytes = new Trend('admin_csv_bytes');
const csvRows = new Trend('admin_csv_rows');
const csvFail = new Counter('admin_csv_fail');

export const options = {
  scenarios: {
    admin: { ...twoPhase(VUS, __ENV.DURATION || '3m', { exec: 'browse' }).main, tags: { phase: 'main' } },
    csv: { executor: 'constant-vus', vus: CSV_VUS, duration: '120s', startTime: `${__ENV.WARMUP_S || 30}s`, exec: 'csv', tags: { phase: 'csv' } },
  },
  // admin listeleri: 400 ms hedef; analitik raporlar agir (gunluk ozet) -> 1500 ms
  thresholds: thresholdsFor(Object.values(N), { default: 400, [N.overview]: 1500, [N.engagement]: 1500, [N.active]: 1500, [N.retention]: 1500, [N.content]: 1500 }),
  summaryTrendStats,
};

const adminTok = fx.adminToken;

export function browse() {
  const x = Math.random();
  if (x < 0.22) call('GET', `/api/admin/users?page=${rnd(50)}&size=20&sort=createdAt,desc`, N.users, adminTok);
  else if (x < 0.34) call('GET', `/api/admin/users?q=${pick(['Seed%20Kullanici%20' + (1 + rnd(20000)), 'seed' + (1 + rnd(20000)), 'Kullanici'])}&page=0&size=20`, N.usersQ, adminTok);
  else if (x < 0.40) call('GET', `/api/admin/users?page=${500 + rnd(400)}&size=20&sort=createdAt,desc`, N.usersDeep, adminTok);
  else if (x < 0.55) call('GET', `/api/admin/audit?page=${rnd(10)}&size=20`, N.audit, adminTok);
  else if (x < 0.60) call('GET', `/api/admin/audit?page=${1000 + rnd(3000)}&size=20`, N.auditDeep, adminTok);
  else if (x < 0.68) call('GET', '/api/admin/reports?status=OPEN&page=0&size=20', N.reports, adminTok);
  else if (x < 0.76) call('GET', '/api/admin/analytics/overview', N.overview, adminTok);
  else if (x < 0.84) call('GET', '/api/admin/analytics/engagement', N.engagement, adminTok);
  else if (x < 0.90) call('GET', '/api/admin/analytics/active-users?days=30', N.active, adminTok);
  else if (x < 0.95) call('GET', '/api/admin/analytics/retention', N.retention, adminTok);
  else call('GET', '/api/admin/analytics/content', N.content, adminTok);
  sleep(1 + Math.random() * 2);
}

export function csv() {
  const which = Math.random() < 0.6 ? 'users' : 'audit';
  const url = which === 'users' ? '/api/admin/users/export.csv' : '/api/admin/audit/export.csv';
  const t0 = Date.now();
  const r = http.get(`${BASE}${url}`, { headers: headers(adminTok), tags: { name: `CSV ${which}`, phase: 'csv' }, timeout: '120s',
    responseCallback: http.expectedStatuses({ min: 200, max: 399 }, 429) });
  const ms = Date.now() - t0;
  if (r.status === 200) {
    csvMs.add(ms, { which });
    csvBytes.add(r.body.length, { which });
    csvRows.add((r.body.match(/\n/g) || []).length, { which });
  } else {
    csvFail.add(1, { which, status: String(r.status) });
  }
  sleep(10);
}

export function handleSummary(data) {
  const o = summaryFor(__ENV.SCEN_NAME || 'E-admin', data);
  const t = (n, k) => (data.metrics[n] && data.metrics[n].values ? data.metrics[n].values[k] : null);
  const extra = {
    csv: { ms_p50: t('admin_csv_ms', 'med'), ms_p95: t('admin_csv_ms', 'p(95)'), ms_max: t('admin_csv_ms', 'max'), bytes_avg: t('admin_csv_bytes', 'avg'),
      rows_avg: t('admin_csv_rows', 'avg'), fail: t('admin_csv_fail', 'count') },
  };
  const json = JSON.parse(o[`${OUT}/${__ENV.SCEN_NAME || 'E-admin'}.json`]);
  json.extra = extra;
  o[`${OUT}/${__ENV.SCEN_NAME || 'E-admin'}.json`] = JSON.stringify(json, null, 2);
  o.stdout += `CSV: sure p50=${extra.csv.ms_p50} p95=${extra.csv.ms_p95} max=${extra.csv.ms_max} ms; ort. ${Math.round(extra.csv.bytes_avg || 0)} bayt, ~${Math.round(extra.csv.rows_avg || 0)} satir; hata=${extra.csv.fail}\n`;
  return o;
}
