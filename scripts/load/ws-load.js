#!/usr/bin/env node
// WebSocket/STOMP yayin yuku: N bagli kullanici, gruplarda eszamanli gonderim, mesaj dagitim gecikmesi.
// Onkosul: scripts/load/seed.sh (20 adet 25 uyeli "demoperf-ws-N" grubu; kullanicilar 1..500).
// Kullanim (repo kokunden):
//   COMPOSE_PROJECT_NAME=wt_t6 BASE=http://localhost:8106 CONNS=500 node scripts/load/ws-load.js
// Ortam: CONNS=300 (1..500; 25'in kati kadar baglanti kullanilir), SENDERS=5 (grup basina gonderen),
//        RATE=0.4 (gonderen basina mesaj/sn; sunucu limiti 30/dk -> en fazla 0.5), DURATION=30 (sn),
//        JWT_SECRET, LABEL (sonuc dosyasi), RAMP_MS=20 (baglantilar arasi bekleme)
// Gecikme = alicinin aldigi an - gondericinin gonderdigi an (ayni surecin saati; sunucu + Redis pub/sub + yazma dahil).
'use strict';
const { execFileSync, spawn } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const BASE = process.env.BASE || 'http://localhost:8106';
const WS_URL = BASE.replace(/^http/, 'ws') + '/ws';
const SECRET = process.env.JWT_SECRET || 'test-secret-test-secret-test-secret-9999';
const CONNS = Number(process.env.CONNS || 300);
const SENDERS = Number(process.env.SENDERS || 5);
const RATE = Math.min(Number(process.env.RATE || 0.4), 0.5);
const DURATION = Number(process.env.DURATION || 30) * 1000;
const RAMP = Number(process.env.RAMP_MS || 20);
const LABEL = process.env.LABEL || 'ws';
const RUN = crypto.randomBytes(3).toString('hex');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const now = () => performance.timeOrigin + performance.now();

function psql(sql) {
  return execFileSync('docker', ['compose', 'exec', '-T', 'postgres', 'psql', '-U', 'bingol', '-d', 'bingol', '-AtF', '|', '-c', sql],
    { encoding: 'utf8' }).trim().split('\n').filter(Boolean);
}
function forgeJwt(userId) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const t = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'HS256' });
  const body = b64({ sub: String(userId), role: 'USER', iat: t - 5, exp: t + 3600 });
  return head + '.' + body + '.' + crypto.createHmac('sha256', Buffer.from(SECRET, 'utf8')).update(head + '.' + body).digest('base64url');
}
const enc = (cmd, headers, body) => cmd + '\n' + Object.entries(headers || {}).map(([k, v]) => k + ':' + v + '\n').join('') + '\n' + (body || '') + '\0';
function parseFrame(part) {
  const i = part.indexOf('\n\n');
  const head = part.slice(0, i < 0 ? part.length : i).split('\n').filter(Boolean);
  const body = i < 0 ? '' : part.slice(i + 2);
  const headers = {};
  for (const l of head.slice(1)) { const k = l.indexOf(':'); headers[l.slice(0, k)] = l.slice(k + 1); }
  return { command: head[0], headers, body };
}
const pct = (arr, p) => (arr.length ? arr[Math.min(arr.length - 1, Math.floor(p * arr.length))] : NaN);

// Handshake IP limiti (600/dk) tekrarlanan kosularda tikanmasin
function clearWsRateLimit() {
  try {
    execFileSync('docker', ['compose', 'exec', '-T', 'redis', 'redis-cli', 'EVAL',
      "for _,k in ipairs(redis.call('keys','rl:ws:*')) do redis.call('del',k) end", '0'], { stdio: 'ignore' });
  } catch { /* redis erisilemez: devam */ }
}

const stats = { frames: 0, errors: {}, delivered: 0, acks: 0, lat: [], ackLat: [], connectMs: [], connFail: 0, closedEarly: 0 };

function connect(user) {
  return new Promise((resolve) => {
    const t0 = now();
    const c = { user, ws: new WebSocket(WS_URL, ['v12.stomp']), ready: false, buf: '' };
    const fail = () => { if (!c.ready) { stats.connFail++; resolve(null); } };
    const timer = setTimeout(fail, 15000);
    c.ws.onerror = () => {};
    c.ws.onclose = () => { if (c.ready) stats.closedEarly++; else { clearTimeout(timer); fail(); } };
    c.ws.onopen = () => c.ws.send(enc('CONNECT', { 'accept-version': '1.2', host: 'localhost', 'heart-beat': '0,0', Authorization: 'Bearer ' + forgeJwt(user) }));
    c.ws.onmessage = (ev) => {
      const at = now();
      for (const part of String(ev.data).split('\0')) {
        const p = part.replace(/^\n+/, '');
        if (!p.trim()) continue;
        const f = parseFrame(p);
        stats.frames++;
        if (f.command === 'CONNECTED' && !c.ready) {
          c.ready = true;
          clearTimeout(timer);
          stats.connectMs.push(at - t0);
          c.ws.send(enc('SUBSCRIBE', { id: 'm', destination: '/user/queue/messages' }));
          c.ws.send(enc('SUBSCRIBE', { id: 'e', destination: '/user/queue/errors' }));
          resolve(c);
        } else if (f.command === 'MESSAGE') {
          if (f.headers.destination === '/user/queue/errors') {
            let code = 'UNKNOWN';
            try { code = JSON.parse(f.body).code; } catch { /* metin */ }
            stats.errors[code] = (stats.errors[code] || 0) + 1;
          } else {
            let m;
            try { m = JSON.parse(f.body); } catch { continue; }
            const mt = /^wsload-(\w+) ([\d.]+)$/.exec(m.text || '');
            if (!mt || mt[1] !== RUN) continue;
            const lat = at - Number(mt[2]);
            if (m.senderId === c.user) { stats.acks++; stats.ackLat.push(lat); } else { stats.delivered++; stats.lat.push(lat); }
          }
        } else if (f.command === 'ERROR') {
          stats.errors['STOMP_ERROR'] = (stats.errors['STOMP_ERROR'] || 0) + 1;
        }
      }
    };
  });
}

(async () => {
  const rows = psql(`SELECT c.id, string_agg(m.user_id::text, ',' ORDER BY m.id) FROM conversation c
                     JOIN conversation_member m ON m.conversation_id = c.id
                     WHERE c.title LIKE 'demoperf-ws-%' GROUP BY c.id ORDER BY c.id`);
  const groups = rows.map((r) => { const [id, us] = r.split('|'); return { id: Number(id), users: us.split(',').map(Number) }; });
  if (!groups.length) { console.error('demoperf-ws gruplari yok: once scripts/load/seed.sh'); process.exit(1); }
  const gUse = Math.max(1, Math.min(groups.length, Math.floor(CONNS / 25)));
  const use = groups.slice(0, gUse);
  const total = use.reduce((a, g) => a + g.users.length, 0);
  console.log(`# ${LABEL}: ${total} baglanti, ${gUse} grup x ${use[0].users.length} uye, ${SENDERS} gonderen/grup @ ${RATE}/sn, ${DURATION / 1000} sn`);

  clearWsRateLimit();
  const conns = [];
  const tConn = now();
  for (const g of use) {
    for (const u of g.users) {
      conns.push(connect(u).then((c) => c && Object.assign(c, { group: g })));
      await sleep(RAMP);
    }
  }
  const live = (await Promise.all(conns)).filter(Boolean);
  console.log(`baglandi: ${live.length}/${total} (${((now() - tConn) / 1000).toFixed(1)} sn, basarisiz ${stats.connFail})`);
  await sleep(1000);

  // Gonderim: her grupta ilk SENDERS uye, RATE ile; Poisson degil, sabit aralik + rastgele ofset
  let sent = 0;
  const expected = { deliveries: 0, acks: 0 };
  const byUser = new Map(live.map((c) => [c.user, c]));
  const timers = [];
  const tEnd = now() + DURATION;
  for (const g of use) {
    const liveMembers = g.users.filter((u) => byUser.has(u)).length;
    for (const u of g.users.slice(0, SENDERS)) {
      const c = byUser.get(u);
      if (!c) continue;
      let seq = 0;
      const tick = () => {
        if (now() >= tEnd) return;
        const text = `wsload-${RUN} ${now()}`;
        c.ws.send(enc('SEND', { destination: '/app/chat.send', 'content-type': 'application/json' },
          JSON.stringify({ conversationId: g.id, text, clientId: `lw-${RUN}-${u}-${seq++}` })));
        sent++;
        expected.deliveries += liveMembers - 1;
        expected.acks += 1;
        timers.push(setTimeout(tick, 1000 / RATE));
      };
      timers.push(setTimeout(tick, Math.random() * (1000 / RATE)));
    }
  }
  await sleep(DURATION + 500);
  await sleep(5000); // gec gelenleri topla
  timers.forEach(clearTimeout);

  const dockerStat = (() => {
    try { return execFileSync('docker', ['stats', '--no-stream', '--format', '{{.Name}} cpu={{.CPUPerc}} mem={{.MemUsage}}', `${process.env.COMPOSE_PROJECT_NAME || 'wt_t6'}-backend-1`], { encoding: 'utf8' }).trim(); }
    catch { return 'n/a'; }
  })();
  live.forEach((c) => { try { c.ws.close(); } catch { /* kapali */ } });

  stats.lat.sort((a, b) => a - b);
  stats.ackLat.sort((a, b) => a - b);
  stats.connectMs.sort((a, b) => a - b);
  const r = {
    label: LABEL, connections: live.length, groups: gUse, sent, offeredMsgPerSec: +(sent / (DURATION / 1000)).toFixed(1),
    expectedDeliveries: expected.deliveries, delivered: stats.delivered, lossPct: +(100 * (1 - stats.delivered / Math.max(1, expected.deliveries))).toFixed(2),
    expectedAcks: expected.acks, acks: stats.acks,
    deliveryMs: { p50: +pct(stats.lat, 0.5).toFixed(1), p95: +pct(stats.lat, 0.95).toFixed(1), p99: +pct(stats.lat, 0.99).toFixed(1), max: +(stats.lat[stats.lat.length - 1] || NaN).toFixed(1) },
    ackMs: { p50: +pct(stats.ackLat, 0.5).toFixed(1), p95: +pct(stats.ackLat, 0.95).toFixed(1), p99: +pct(stats.ackLat, 0.99).toFixed(1) },
    connectMs: { p50: +pct(stats.connectMs, 0.5).toFixed(1), p95: +pct(stats.connectMs, 0.95).toFixed(1) },
    connFail: stats.connFail, closedEarly: stats.closedEarly, errors: stats.errors, backend: dockerStat,
  };
  console.log(JSON.stringify(r, null, 2));
  console.log(`| ${r.connections} | ${r.offeredMsgPerSec} | ${r.delivered}/${r.expectedDeliveries} (${r.lossPct}% kayip) | ${r.deliveryMs.p50} | ${r.deliveryMs.p95} | ${r.deliveryMs.p99} | ${r.deliveryMs.max} | ${r.ackMs.p50} | ${r.connectMs.p95} |`);
  fs.mkdirSync(path.join(__dirname, 'results'), { recursive: true });
  fs.writeFileSync(path.join(__dirname, 'results', LABEL + '.json'), JSON.stringify(r, null, 2));
  let th = {};
  try { th = JSON.parse(fs.readFileSync(path.join(__dirname, 'thresholds.json'), 'utf8')).ws || {}; } catch { /* yok */ }
  const bad = r.lossPct > (th.lossPct ?? 0) || r.deliveryMs.p95 > (th.deliveryP95 ?? 1e9) || r.deliveryMs.p99 > (th.deliveryP99 ?? 1e9) || r.connFail > (th.connFail ?? 0);
  if (bad) console.log('ESIK ASILDI (ws): bkz. scripts/load/thresholds.json');
  process.exit(bad ? 1 : 0);
})();
