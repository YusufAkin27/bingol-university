#!/usr/bin/env node
// RL1: kampus NAT senaryosu. TEK genel IP'den (X-Forwarded-For yok) 300 FARKLI kullanici giris yapar + refresh eder;
// ardindan kaba kuvvet koruma denetimleri. a-auth.js her VU'ya ayri IP verdigi icin NAT'i olcmuyordu.
// Ortam: BASE (http://localhost:18611), USERS (300), CONC (10; bcrypt kuyrugunu doldurmasin), PASSWORD (LoadTest-2026!)
// Beklenen (RL1 sonrasi): 300/300 giris 200, 300/300 refresh 200; tek hesaba kaba kuvvet 10. yanlis denemeden sonra 429;
// ayni NAT'ta baska cihazdan dogru parola 200; dagitik (80 IP) kaba kuvvet e-posta basina 60'ta 429.
'use strict';
const BASE = (process.env.BASE || 'http://localhost:18611').replace(/\/+$/, '');
const USERS = Number(process.env.USERS || 300);
const CONC = Number(process.env.CONC || 10);
const PASS = process.env.PASSWORD || 'LoadTest-2026!';
const email = (i) => `rl1u${i}@bingol.edu.tr`;

async function post(path, body, headers) {
  const t0 = performance.now();
  try {
    const res = await fetch(`${BASE}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(headers || {}) }, body: JSON.stringify(body) });
    let j = null; try { j = await res.json(); } catch { /* bos */ }
    return { status: res.status, code: j && j.code, json: j, ms: performance.now() - t0 };
  } catch (e) { return { status: 0, code: String(e.cause?.code || e.message), ms: performance.now() - t0 }; }
}
async function pool(n, conc, fn) {
  const out = new Array(n); let next = 0;
  await Promise.all(Array.from({ length: conc }, async () => { for (;;) { const i = next++; if (i >= n) return; out[i] = await fn(i); } }));
  return out;
}
const tally = (rs) => rs.reduce((m, r) => { const k = r.code && r.status >= 400 ? `${r.status}:${r.code}` : String(r.status); m[k] = (m[k] || 0) + 1; return m; }, {});
const pct = (a, p) => { const s = a.map((r) => r.ms).sort((x, y) => x - y); return s.length ? Math.round(s[Math.min(s.length - 1, Math.floor(p / 100 * s.length))]) : null; };

const report = {};
// 1) 300 farkli kullanici, tek IP, her biri kendi cihaz kimligiyle (mobil gercegi)
const logins = await pool(USERS, CONC, (i) => post('/api/auth/login', { email: email(i + 1), password: PASS, client: 'web' }, { 'X-Device-Id': `nat-dev-${String(i).padStart(6, '0')}` }));
report.natLogin = { users: USERS, statuses: tally(logins), p50: pct(logins, 50), p95: pct(logins, 95) };
// 2) ayni 300 kullanici refresh (ayni IP)
const refreshes = await pool(USERS, CONC, (i) => logins[i].status === 200
  ? post('/api/auth/refresh', { refreshToken: logins[i].json.refreshToken, client: 'web' }) : Promise.resolve({ status: -1 }));
report.natRefresh = { users: USERS, statuses: tally(refreshes), p95: pct(refreshes.filter((r) => r.status > 0), 95) };

// 3) tek hesaba kaba kuvvet (tek cihaz): 10 yanlis denemeden sonra 429
const victim = email(USERS + 1);
const bf = [];
for (let i = 0; i < 14; i++) bf.push(await post('/api/auth/login', { email: victim, password: `yanlis-${i}`, client: 'web' }, { 'X-Device-Id': 'attacker-device-0001' }));
report.bruteForceOneDevice = { statuses: bf.map((r) => r.status).join(','), firstBlockedAt: bf.findIndex((r) => r.status === 429) + 1 };
// kurban ayni NAT'ta baska cihazdan dogru parolayla girebilmeli (hedefli kilitleme DoS yok)
const victimOk = await post('/api/auth/login', { email: victim, password: PASS, client: 'web' }, { 'X-Device-Id': 'victim-device-00001' });
report.victimOnSameNatDifferentDevice = victimOk.status;
// ayni NAT'ta baska hesap etkilenmez
const other = await post('/api/auth/login', { email: email(USERS + 2), password: PASS, client: 'web' }, { 'X-Device-Id': 'other-device-00001' });
report.otherUserOnSameNat = other.status;

// 4) dagitik kaba kuvvet: 80 farkli IP + 80 farkli cihaz, TEK hesap -> e-posta tavani (60)
const target = email(USERS + 3);
const dist = [];
for (let i = 0; i < 80; i++) dist.push(await post('/api/auth/login', { email: target, password: `x-${i}`, client: 'web' }, { 'X-Forwarded-For': `11.7.${i >> 8}.${(i & 255) + 1}`, 'X-Device-Id': `dist-dev-${String(i).padStart(6, '0')}` }));
report.distributedBruteForce = { attempts: dist.length, statuses: tally(dist), firstBlockedAt: dist.findIndex((r) => r.status === 429) + 1 };

console.log(JSON.stringify(report, null, 2));
