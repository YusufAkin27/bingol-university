#!/usr/bin/env node
// Mobil ana yollar icin API hiz testi. Harici paket yok (Node 24: fetch, performance).
// Kullanim: BASE=http://localhost:8080 node scripts/perf/perf-api.js
// Ortam: PERF_EMAIL, PERF_PASSWORD, PERF_N (olcum, vars. 50), PERF_C (eszamanlilik, vars. 5),
//        PERF_WARMUP (vars. 5), PERF_P95_MS (esik, vars. 400)
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const BASE = (process.env.BASE || 'http://localhost:8080').replace(/\/+$/, '');
const EMAIL = process.env.PERF_EMAIL || 'mobil.test@bingol.edu.tr';
const PASSWORD = process.env.PERF_PASSWORD || 'BuTest2026x';
const N = Math.max(1, parseInt(process.env.PERF_N || '50', 10));
const C = Math.max(1, parseInt(process.env.PERF_C || '5', 10));
const WARMUP = Math.max(0, parseInt(process.env.PERF_WARMUP || '5', 10));
const P95_LIMIT = parseFloat(process.env.PERF_P95_MS || '400');
const TIMEOUT_MS = 15000;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let backoffUntil = 0; // 429 sonrasi ortak geri cekilme

const d = new Date();
const month = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;

const ENDPOINTS = [
  { name: 'news HABER p0', url: '/api/news?type=HABER&size=20&page=0' },
  { name: 'news HABER p3', url: '/api/news?type=HABER&size=20&page=3' },
  { name: 'news DUYURU p0', url: '/api/news?type=DUYURU&size=20&page=0' },
  { name: 'news DUYURU p3', url: '/api/news?type=DUYURU&size=20&page=3' },
  { name: 'news ETKINLIK p0', url: '/api/news?type=ETKINLIK&size=20&page=0' },
  { name: 'news ETKINLIK p3', url: '/api/news?type=ETKINLIK&size=20&page=3' },
  { name: 'menu today', url: '/api/menu/today' },
  { name: 'events', url: '/api/events' },
  { name: 'events calendar', url: `/api/events/calendar?month=${month}` },
  { name: 'communities', url: '/api/communities' },
  { name: 'conversations', url: '/api/conversations' },
  { name: 'notifications', url: '/api/notifications?size=1' },
  { name: 'search', url: '/api/search?q=universite' },
  { name: 'users/me', url: '/api/users/me' },
  { name: 'me/summary', url: '/api/me/summary', optional: true },
];

async function timedFetch(url, headers) {
  const t0 = performance.now();
  try {
    const res = await fetch(BASE + url, { headers, signal: AbortSignal.timeout(TIMEOUT_MS) });
    const buf = await res.arrayBuffer();
    return { status: res.status, ms: performance.now() - t0, bytes: buf.byteLength, etag: res.headers.get('etag') };
  } catch (e) {
    return { status: 0, ms: performance.now() - t0, bytes: 0, err: String((e && e.message) || e) };
  }
}

// 429'da bekleyip yeniden dener (en fazla 4 deneme); 429 sayisini counters.rl'de tutar.
async function request(url, headers, counters) {
  for (let attempt = 0; attempt < 4; attempt++) {
    const wait = backoffUntil - Date.now();
    if (wait > 0) await sleep(wait);
    const r = await timedFetch(url, headers);
    if (r.status !== 429) return r;
    counters.rl++;
    backoffUntil = Date.now() + 2000 * (attempt + 1);
  }
  return { status: 429, ms: 0, bytes: 0, limited: true };
}

async function pool(total, conc, fn) {
  let i = 0;
  const workers = Array.from({ length: Math.min(conc, total) }, async () => {
    while (i < total) { i++; await fn(); }
  });
  await Promise.all(workers);
}

function pct(sorted, p) {
  if (!sorted.length) return NaN;
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.min(sorted.length - 1, Math.max(0, idx))];
}

async function login() {
  const res = await fetch(`${BASE}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: EMAIL, password: PASSWORD }),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`giris basarisiz: HTTP ${res.status}`);
  const j = await res.json();
  if (!j.accessToken) throw new Error('giris cevabinda accessToken yok');
  return j.accessToken;
}

async function measure(ep, headers) {
  const counters = { rl: 0 };
  const probe = await request(ep.url, headers, counters);
  if (probe.status === 404 && ep.optional) return { name: ep.name, url: ep.url, skipped: true };
  await pool(Math.max(0, WARMUP - 1), C, () => request(ep.url, headers, counters));

  const times = [];
  let errors = 0;
  let bytes = probe.bytes;
  let etagVal = probe.etag;
  await pool(N, C, async () => {
    const r = await request(ep.url, headers, counters);
    if (r.limited) return;
    if (r.status >= 200 && r.status < 400) {
      times.push(r.ms);
      bytes = r.bytes || bytes;
      etagVal = r.etag || etagVal;
    } else errors++;
  });
  times.sort((a, b) => a - b);
  const avg = times.reduce((s, v) => s + v, 0) / (times.length || 1);

  // ETag / 304 olcumu (tek istek)
  let etag = { supported: false };
  if (etagVal) {
    const r = await request(ep.url, { ...headers, 'If-None-Match': etagVal }, counters);
    etag = { supported: true, status: r.status, ms: +r.ms.toFixed(1), bytes: r.bytes };
  }

  return {
    name: ep.name, url: ep.url, n: times.length, errors, rateLimited: counters.rl,
    p50: pct(times, 50), p90: pct(times, 90), p95: pct(times, 95), p99: pct(times, 99),
    avg, max: times.length ? times[times.length - 1] : NaN, bytes, etag,
  };
}

const f = (v) => (Number.isFinite(v) ? v.toFixed(1) : '-');

async function main() {
  console.log(`BASE=${BASE} N=${N} C=${C} warmup=${WARMUP} esik p95<${P95_LIMIT}ms`);
  let token;
  try { token = await login(); } catch (e) { console.error(e.message); process.exit(2); }
  const headers = { Authorization: `Bearer ${token}`, 'Accept-Language': 'tr' };

  const results = [];
  for (const ep of ENDPOINTS) {
    const r = await measure(ep, headers);
    results.push(r);
    if (r.skipped) console.log(`atlandi (404): ${ep.name}`);
    await sleep(200);
  }

  const rows = results.filter((r) => !r.skipped);
  console.log('\n' + ['uc'.padEnd(18), 'n'.padStart(4), 'p50'.padStart(7), 'p90'.padStart(7), 'p95'.padStart(7),
    'p99'.padStart(7), 'ort'.padStart(7), 'max'.padStart(7), 'hata'.padStart(5), '429'.padStart(4),
    'bayt'.padStart(8), 'etag'.padStart(12)].join(' '));
  for (const r of rows) {
    const e = r.etag.supported ? `${r.etag.status}/${r.etag.ms}ms` : 'yok';
    console.log([r.name.padEnd(18), String(r.n).padStart(4), f(r.p50).padStart(7), f(r.p90).padStart(7),
      f(r.p95).padStart(7), f(r.p99).padStart(7), f(r.avg).padStart(7), f(r.max).padStart(7),
      String(r.errors).padStart(5), String(r.rateLimited).padStart(4), String(r.bytes).padStart(8),
      e.padStart(12)].join(' '));
  }

  const failed = rows.filter((r) => !(r.p95 < P95_LIMIT) || r.errors > 0 || r.n === 0);
  const out = {
    at: new Date().toISOString(), base: BASE, n: N, c: C, warmup: WARMUP, p95LimitMs: P95_LIMIT,
    results, failed: failed.map((r) => r.name),
  };
  fs.writeFileSync(path.join(__dirname, 'last-run.json'), JSON.stringify(out, null, 2));

  if (failed.length) {
    console.log(`\nESIK/HATA ASIMI: ${failed.map((r) => r.name).join(', ')}`);
    process.exit(1);
  }
  console.log('\nTum uclar esik icinde.');
}

main().catch((e) => { console.error(e); process.exit(2); });
