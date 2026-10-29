#!/usr/bin/env node
// RL1: tek ankete N eszamanli oy + ayni kullanicidan cift (eszamanli) oy; sure/durum dagilimi ve veri butunlugu.
// Ortam: BASE (http://localhost:18611), JWT_SECRET, PSQL_CMD (docker exec -i rl1-postgres-1 psql -U bingol -d bingol),
//        N (300), DOUBLE (50: ilk DOUBLE kullanici iki es zamanli istek yollar), TYPE (SINGLE|MULTI)
// UYARI: tokenlar JWT_SECRET ile uretilir; YALNIZ test yiginina karsi calistirin.
'use strict';
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';

const BASE = (process.env.BASE || 'http://localhost:18611').replace(/\/+$/, '');
const SECRET = process.env.JWT_SECRET;
const PSQL = process.env.PSQL_CMD || 'docker exec -i rl1-postgres-1 psql -U bingol -d bingol';
const N = Number(process.env.N || 300);
const DOUBLE = Number(process.env.DOUBLE || 50);
if (!SECRET || SECRET.length < 32) { console.error('JWT_SECRET (>=32) gerekli'); process.exit(2); }

const q = (sql) => execSync(`${PSQL} -AtF "|" -c "${sql.replace(/"/g, '\\"').replace(/\n/g, ' ')}"`, { encoding: 'utf8' })
  .split('\n').filter(Boolean).map((l) => l.split('|'));
function forge(id, email) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Date.now(); const iat = Math.floor(now / 1000) - 5;
  const head = b64({ alg: 'HS256' });
  const body = b64({ sub: String(id), email, role: 'USER', cl: 'web', iatms: now - 5000, iat, exp: iat + 3 * 3600 });
  return `${head}.${body}.${crypto.createHmac('sha256', Buffer.from(SECRET, 'utf8')).update(`${head}.${body}`).digest('base64url')}`;
}
const pct = (a, p) => (a.length ? a[Math.min(a.length - 1, Math.floor((p / 100) * a.length))] : null);

const users = q(`SELECT id, email FROM app_user WHERE email LIKE 'rl1u%@bingol.edu.tr' ORDER BY id LIMIT ${N}`);
if (users.length < N) { console.error(`yeterli kullanici yok: ${users.length}/${N}`); process.exit(2); }
const creator = users[0][0];
const [[pollId]] = q(`INSERT INTO poll (title, description, type, scope, anonymous, allow_change_vote, show_results, max_choices, status, created_by, opens_at)
  VALUES ('rl1 burst ${Date.now()}', 'olcum', 'SINGLE', 'GLOBAL', TRUE, TRUE, 'ALWAYS', 1, 'OPEN', ${creator}, now() - interval '1 hour') RETURNING id`);
q(`INSERT INTO poll_option (poll_id, position, text) SELECT ${pollId}, o, 'Secenek ' || o FROM generate_series(1, 3) o`);
const optIds = q(`SELECT id FROM poll_option WHERE poll_id = ${pollId} ORDER BY position`).map((r) => Number(r[0]));
const tokens = users.map((u) => forge(u[0], u[1]));

// Isinma: ilgisiz bir uc (JIT/baglanti); ayri bir ankete tek oy
async function vote(i, optIndex) {
  const t0 = performance.now();
  try {
    const res = await fetch(`${BASE}/api/polls/${pollId}/vote`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokens[i]}` },
      body: JSON.stringify({ optionIds: [optIds[optIndex % optIds.length]] }),
    });
    let code = null;
    if (res.status >= 400) { try { code = (await res.json()).code; } catch { /* yut */ } } else { await res.arrayBuffer(); }
    return { status: res.status, code, ms: performance.now() - t0 };
  } catch (e) {
    return { status: 0, code: String(e.cause?.code || e.message), ms: performance.now() - t0 };
  }
}

// Havuz gozlemi (dev profilinde actuator/metrics aciksa)
let peakActive = 0; let peakPending = 0; let sampling = true;
async function sampler() {
  while (sampling) {
    try {
      const [a, p] = await Promise.all(['active', 'pending'].map((k) => fetch(`${BASE}/actuator/metrics/hikaricp.connections.${k}`).then((r) => r.json())));
      peakActive = Math.max(peakActive, a.measurements[0].value); peakPending = Math.max(peakPending, p.measurements[0].value);
    } catch { /* metrik yok */ }
    await new Promise((r) => setTimeout(r, 100));
  }
}

console.log(`anket ${pollId}: ${N} es zamanli oy + ${DOUBLE} cift istek -> ${BASE}`);
const smp = sampler();
const t0 = performance.now();
const jobs = [];
for (let i = 0; i < N; i++) {
  jobs.push(vote(i, i));
  if (i < DOUBLE) jobs.push(vote(i, i + 1)); // ayni kullanici, ayni anda farkli secenek
}
const results = await Promise.all(jobs);
const wall = performance.now() - t0;
sampling = false; await smp;

const by = {};
for (const r of results) { const k = r.code ? `${r.status}:${r.code}` : String(r.status); by[k] = (by[k] || 0) + 1; }
const ok = results.filter((r) => r.status === 200).map((r) => r.ms).sort((a, b) => a - b);
const all = results.map((r) => r.ms).sort((a, b) => a - b);

// Butunluk
const one = (sql) => Number(q(sql)[0][0]);
const ballots = one(`SELECT count(*) FROM poll_ballot WHERE poll_id = ${pollId}`);
const dupBallots = one(`SELECT count(*) FROM (SELECT user_id FROM poll_ballot WHERE poll_id = ${pollId} GROUP BY 1 HAVING count(*) > 1) x`);
const voteRows = one(`SELECT count(*) FROM poll_vote WHERE poll_id = ${pollId}`);
const dupVotes = one(`SELECT count(*) FROM (SELECT user_id FROM poll_vote WHERE poll_id = ${pollId} GROUP BY 1 HAVING count(*) > 1) x`);
const voterCount = one(`SELECT voter_count FROM poll WHERE id = ${pollId}`);
const optSum = one(`SELECT coalesce(sum(vote_count),0) FROM poll_option WHERE poll_id = ${pollId}`);
const optMismatch = one(`SELECT count(*) FROM poll_option o WHERE o.poll_id = ${pollId} AND o.vote_count <> (SELECT count(*) FROM poll_vote v WHERE v.option_id = o.id)`);
const out = {
  pollId, n: N, double: DOUBLE, requests: jobs.length, wallMs: Math.round(wall), statuses: by,
  okLatencyMs: { p50: Math.round(pct(ok, 50)), p95: Math.round(pct(ok, 95)), max: Math.round(ok[ok.length - 1] || 0) },
  allLatencyMs: { p50: Math.round(pct(all, 50)), p95: Math.round(pct(all, 95)), max: Math.round(all[all.length - 1] || 0) },
  hikariPeak: { active: peakActive, pending: peakPending },
  integrity: { ballots, voterCount, voteRows, optionSum: optSum, dupBallots, dupVotes, optionCountMismatch: optMismatch,
    ok: ballots === voterCount && voteRows === ballots && optSum === voteRows && dupBallots === 0 && dupVotes === 0 && optMismatch === 0 },
};
console.log(JSON.stringify(out, null, 2));
process.exit(out.integrity.ok ? 0 : 1);
