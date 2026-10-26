#!/usr/bin/env node
// N+1 avi: her uc icin TEK istek atip veritabaninin calistirdigi SQL sayisini pg_stat_statements'tan sayar.
// Onkosul: postgres `scripts/load/compose.perf.yml` ile (pg_stat_statements acik) ve veri tohumlanmis olmali.
// Kullanim: COMPOSE_PROJECT_NAME=wt_t6 BASE=http://localhost:8106 node scripts/load/nplus1.js
// Cikti: uc basina toplam SQL sayisi + bir istekte 2+ kez calisan ayni (normalize) sorgular = N+1 supheli.
// Her istek oncesi 2 isinma cagrisi yapilir (Hibernate/JIT ilk-cagri sorgulari sayilmasin).
'use strict';
const { execFileSync } = require('node:child_process');
const crypto = require('node:crypto');

const BASE = process.env.BASE || 'http://localhost:8106';
const SECRET = process.env.JWT_SECRET || 'test-secret-test-secret-test-secret-9999';
function psql(sql) {
  return execFileSync('docker', ['compose', 'exec', '-T', 'postgres', 'psql', '-U', 'bingol', '-d', 'bingol', '-AtF', '|', '-c', sql],
    { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }).trim().split('\n').filter(Boolean);
}
function jwt(id, role = 'USER') {
  const b = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const t = Math.floor(Date.now() / 1000);
  const h = b({ alg: 'HS256' }), p = b({ sub: String(id), role, iat: t - 5, exp: t + 3600 });
  return h + '.' + p + '.' + crypto.createHmac('sha256', Buffer.from(SECRET, 'utf8')).update(h + '.' + p).digest('base64url');
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  // Kullanici 8: 3 numarali konusmada uye; toplulugu/etkinligi olan kullanici ve toplulugu bulunur
  const uid = Number(psql(`SELECT id FROM app_user WHERE email = 'demoperf.8@bingol.edu.tr'`)[0]);
  const admin = Number(psql(`SELECT id FROM app_user WHERE role = 'ADMIN' ORDER BY id LIMIT 1`)[0] || 0);
  const comm = psql(`SELECT c.id FROM community c JOIN community_member m ON m.community_id = c.id WHERE m.user_id = ${uid} AND c.status = 'ACTIVE' LIMIT 1`)[0]
    || psql(`SELECT id FROM community WHERE status = 'ACTIVE' ORDER BY id LIMIT 1`)[0];
  const ev = psql(`SELECT id FROM user_event WHERE status = 'ACTIVE' ORDER BY id LIMIT 1`)[0];
  const conv = psql(`SELECT conversation_id FROM conversation_member WHERE user_id = ${uid} ORDER BY id LIMIT 1`)[0];
  const news = psql(`SELECT id FROM news_item WHERE hidden = false ORDER BY id LIMIT 1`)[0];
  const other = psql(`SELECT id FROM app_user WHERE email = 'demoperf.9@bingol.edu.tr'`)[0];
  const eps = [
    ['GET /api/news?type=HABER', '/api/news?type=HABER&size=20', null],
    ['GET /api/news/{id}', `/api/news/${news}`, null],
    ['GET /api/search?q=sinav', '/api/search?q=sinav&limit=5', uid],
    ['GET /api/notifications', '/api/notifications?size=20', uid],
    ['GET /api/conversations', '/api/conversations?size=20', uid],
    ['GET /api/conversations/{id}/messages', `/api/conversations/${conv}/messages?size=30`, uid],
    ['GET /api/users/me', '/api/users/me', uid],
    ['GET /api/users/{id}', `/api/users/${other}`, uid],
    ['GET /api/communities', '/api/communities?size=20', uid],
    ['GET /api/communities/{id}', `/api/communities/${comm}`, uid],
    ['GET /api/communities/{id}/members', `/api/communities/${comm}/members?size=20`, uid],
    ['GET /api/communities/{id}/posts', `/api/communities/${comm}/posts?size=20`, uid],
    ['GET /api/me/communities', '/api/me/communities', uid],
    ['GET /api/events', '/api/events?size=20', uid],
    ['GET /api/events/{id}', `/api/events/${ev}`, uid],
    ['GET /api/events/{id}/attendees', `/api/events/${ev}/attendees?size=20`, uid],
    ['GET /api/me/events', '/api/me/events', uid],
    ['GET /api/bookmarks', '/api/bookmarks', uid],
    ['GET /api/admin/users', '/api/admin/users?page=0&size=20', admin],
    ['GET /api/admin/communities', '/api/admin/communities', admin],
    ['GET /api/admin/events', '/api/admin/events', admin],
  ];
  console.log('| uc | HTTP | SQL sayisi | supheli (2+ kez calisan sorgu) |');
  console.log('|---|---|---|---|');
  for (const [name, url, who] of eps) {
    const headers = who ? { Authorization: 'Bearer ' + jwt(who, who === admin ? 'ADMIN' : 'USER') } : {};
    let status = 0;
    for (let i = 0; i < 2; i++) { const r = await fetch(BASE + url, { headers }); await r.arrayBuffer(); status = r.status; }
    await sleep(600); // arka plan yazimlari (aktivite izleyici) otursun
    psql('SELECT pg_stat_statements_reset()');
    const r = await fetch(BASE + url, { headers }); await r.arrayBuffer(); status = r.status;
    await sleep(400);
    const rows = psql(`SELECT calls, regexp_replace(left(query, 90), '\\s+', ' ', 'g') FROM pg_stat_statements
                       WHERE query NOT ILIKE '%pg_stat_statements%' AND query NOT ILIKE 'SET %' AND query NOT ILIKE 'BEGIN%' AND query NOT ILIKE 'COMMIT%'
                       ORDER BY calls DESC`).map((l) => { const i = l.indexOf('|'); return { calls: Number(l.slice(0, i)), q: l.slice(i + 1) }; });
    const total = rows.reduce((a, b) => a + b.calls, 0);
    const sus = rows.filter((x) => x.calls >= 2 && !/activity_daily|last_seen_at/.test(x.q)).map((x) => `${x.calls}x ${x.q.replace(/\|/g, '/')}`);
    console.log(`| ${name} | ${status} | ${total} | ${sus.length ? sus.join('<br>') : '-'} |`);
  }
})();
