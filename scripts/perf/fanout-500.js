#!/usr/bin/env node
// 500 uyeli grup sohbetinde mesaj dagitimi olcumu (W1-E: T-035 bildirim yazimi, T-036 WS teslimi).
// Onkosul: scripts/perf/fanout-seed.sql calismis olmali; backend'in JWT_SECRET'i bilinmeli (token URETILIR, giris yapilmaz).
//
//   BASE=http://localhost:18150 JWT_SECRET=... CONV=<id> FIRST=<id> LAST=<id> \
//   PSQL="docker compose -p bu_w1e exec -T postgres psql -U bingol -d bingol -At" node scripts/perf/fanout-500.js
//
// Ortam: MESSAGES (8) gonderilecek mesaj, WS (300) canli WebSocket alici sayisi, GAP_MS (0) mesajlar arasi bekleme,
//        TIMEOUT_S (120) bildirimlerin bitmesi icin ust sure.
// Olculenler:
//   - WS teslim gecikmesi: POST baslangicindan alicinin kuyruguna dusene dek (p50/p95/max), kayip teslim sayisi
//   - Bildirim tamamlanma: SON mesaj gonderiminden, her alici icin conv:<id> satirinin sayaci MESSAGES olana dek (sn)
// Cikis kodu: 0 = tamam, 1 = teslim/bildirim eksik, 2 = hazirlik hatasi.
'use strict';
const crypto = require('node:crypto');
const { execSync } = require('node:child_process');

const BASE = process.env.BASE || 'http://localhost:8080';
const SECRET = process.env.JWT_SECRET || 'test-secret-test-secret-test-secret-9999';
const CONV = Number(process.env.CONV);
const FIRST = Number(process.env.FIRST);
const LAST = Number(process.env.LAST);
const MESSAGES = Number(process.env.MESSAGES || 8);
const WS_N = Number(process.env.WS || 300);
const GAP_MS = Number(process.env.GAP_MS || 0);
const TIMEOUT_S = Number(process.env.TIMEOUT_S || 120);
const PSQL = process.env.PSQL || 'docker compose exec -T postgres psql -U bingol -d bingol -At';
const WS = typeof WebSocket !== 'undefined' ? WebSocket : require('ws');
if (!CONV || !FIRST || !LAST) { console.error('CONV, FIRST, LAST gerekli (fanout-seed.sql ciktisi)'); process.exit(2); }

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const q = (sql) => execSync(PSQL + ' -c "' + sql.replace(/"/g, '\\"') + '"', { encoding: 'utf8' }).trim();
const forge = (uid) => {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const head = b64({ alg: 'HS256' });
  const now = Math.floor(Date.now() / 1000);
  const body = b64({ sub: String(uid), role: 'USER', iat: now - 5, exp: now + 3600 });
  const sig = crypto.createHmac('sha256', Buffer.from(SECRET, 'utf8')).update(head + '.' + body).digest('base64url');
  return head + '.' + body + '.' + sig;
};
const frame = (cmd, h, body) => cmd + '\n' + Object.entries(h || {}).map(([k, v]) => k + ':' + v).join('\n') + '\n\n' + (body || '') + '\0';
const pct = (a, p) => (a.length ? a.slice().sort((x, y) => x - y)[Math.min(a.length - 1, Math.floor((p / 100) * a.length))] : NaN);

async function main() {
  const sender = FIRST; // grup yoneticisi
  const sendAt = new Map(); // clientId -> POST baslangic (ms)
  const lat = [];
  let delivered = 0;

  // canli alicilar: sender haric ilk WS_N uye
  const recipients = [];
  for (let id = FIRST + 1; id <= LAST && recipients.length < WS_N; id++) recipients.push(id);
  let connected = 0;
  const sockets = recipients.map((uid) => new Promise((resolve) => {
    const ws = new WS(BASE.replace(/^http/, 'ws') + '/ws', ['v12.stomp']);
    ws.onopen = () => ws.send(frame('CONNECT', { 'accept-version': '1.2', host: 'x', 'heart-beat': '0,0', Authorization: 'Bearer ' + forge(uid) }));
    ws.onmessage = (ev) => {
      for (const part of String(ev.data).split('\0')) {
        const p = part.replace(/^\n+/, '');
        if (!p) continue;
        if (p.startsWith('CONNECTED')) {
          connected++;
          ws.send(frame('SUBSCRIBE', { id: 'm', destination: '/user/queue/messages' }));
          resolve(ws);
        } else if (p.startsWith('MESSAGE')) {
          const m = p.split('\n\n').slice(1).join('\n\n');
          let j = null; try { j = JSON.parse(m); } catch { /* */ }
          const t0 = j && sendAt.get(j.clientId);
          if (t0 !== undefined) { lat.push(Date.now() - t0); delivered++; }
        }
      }
    };
    ws.onerror = () => resolve(null);
  }));
  const open = (await Promise.all(sockets)).filter(Boolean);
  console.log(`WS alici: ${open.length}/${recipients.length} bagli`);
  if (open.length < recipients.length * 0.9) { console.error('cok az WS baglandi'); process.exit(2); }

  q(`DELETE FROM notification WHERE collapse_key = 'conv:${CONV}'`);
  const token = forge(sender);
  const posts = [];
  let lastPostDone = 0;
  const t0 = Date.now();
  for (let i = 0; i < MESSAGES; i++) {
    const clientId = 'fan-' + Date.now() + '-' + i;
    sendAt.set(clientId, Date.now());
    posts.push(fetch(BASE + '/api/conversations/' + CONV + '/messages', {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + token },
      body: JSON.stringify({ text: 'olcum ' + i, clientId }),
    }).then((r) => { lastPostDone = Date.now(); return r.status; }));
    if (GAP_MS) await sleep(GAP_MS);
  }
  const statuses = await Promise.all(posts);
  console.log('POST durumlari:', [...new Set(statuses)].join(','), ' toplam', Date.now() - t0, 'ms');

  // WS teslimlerinin bitmesini bekle
  const expectedWs = open.length * MESSAGES;
  for (let w = 0; w < 100 && delivered < expectedWs; w++) await sleep(100);

  // bildirimler: her uyenin satiri sayac=MESSAGES olunca bitti (gonderen haric LAST-FIRST uye)
  const members = LAST - FIRST; // gonderen haric
  const want = members * MESSAGES;
  let done = 0, rows = 0;
  const tEnd = Date.now() + TIMEOUT_S * 1000;
  while (Date.now() < tEnd) {
    const out = q(`SELECT count(*) || ' ' || coalesce(sum(group_count),0) FROM notification WHERE collapse_key = 'conv:${CONV}' AND read_at IS NULL`).split(' ');
    rows = Number(out[0]); done = Number(out[1]);
    if (done >= want) break;
    await sleep(250);
  }
  const notifSecAfterLastPost = (Date.now() - lastPostDone) / 1000;
  const dupRows = Number(q(`SELECT count(*) - count(DISTINCT user_id) FROM notification WHERE collapse_key = 'conv:${CONV}' AND read_at IS NULL`));
  console.log('--- sonuc ---');
  console.log(`WS teslim: ${delivered}/${expectedWs}  p50=${pct(lat, 50)}ms p95=${pct(lat, 95)}ms max=${Math.max(...lat)}ms`);
  console.log(`Bildirim: satir=${rows} toplam sayac=${done}/${want} yinelenen satir=${dupRows}`);
  console.log(`Son POST'tan bildirimlerin bitisine: ${done >= want ? notifSecAfterLastPost.toFixed(1) + ' sn' : 'BITMEDI (' + TIMEOUT_S + ' sn)'}`);
  open.forEach((w) => { try { w.close(); } catch { /* */ } });
  process.exit(delivered >= expectedWs && done >= want && dupRows === 0 ? 0 : 1);
}
main().catch((e) => { console.error(e); process.exit(2); });
