#!/usr/bin/env node
// Ayni WebSocket oturumundan art arda gonderilen chat.send cercevelerinin SIRASI (T-037 / A10-03).
// Tek soketten N cerceve BEKLEMEDEN yollanir; sunucunun atadigi mesaj kimlikleri gonderim sirasiyla artmali
// (kimlik sirasi = gecmiste gorunen sira). Eski davranis: cerceveler farkli is parcaciklarinda islenip yer degistirir.
//
//   BASE=http://localhost:18150 JWT_SECRET=... CONV=<id> SENDER=<uye id> [N=20] node scripts/perf/ws-order.js
//
// Not: kullanici basina dakikada 30 mesaj siniri vardir; N<=25 tutun ya da her kosuda farkli SENDER kullanin.
// Cikis kodu: 0 = sira korundu, 1 = sira bozuldu / mesaj eksik, 2 = hazirlik hatasi.
'use strict';
const crypto = require('node:crypto');

const BASE = process.env.BASE || 'http://localhost:8080';
const SECRET = process.env.JWT_SECRET || 'test-secret-test-secret-test-secret-9999';
const CONV = Number(process.env.CONV);
const SENDER = Number(process.env.SENDER);
const N = Number(process.env.N || 20);
const WS = typeof WebSocket !== 'undefined' ? WebSocket : require('ws');
if (!CONV || !SENDER) { console.error('CONV ve SENDER gerekli'); process.exit(2); }

const forge = (uid) => {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const head = b64({ alg: 'HS256' });
  const now = Math.floor(Date.now() / 1000);
  const body = b64({ sub: String(uid), role: 'USER', iat: now - 5, exp: now + 3600 });
  return head + '.' + body + '.' + crypto.createHmac('sha256', Buffer.from(SECRET, 'utf8')).update(head + '.' + body).digest('base64url');
};
const frame = (cmd, h, body) => cmd + '\n' + Object.entries(h || {}).map(([k, v]) => k + ':' + v).join('\n') + '\n\n' + (body || '') + '\0';

const run = Date.now();
const got = [];
const ws = new WS(BASE.replace(/^http/, 'ws') + '/ws', ['v12.stomp']);
ws.onopen = () => ws.send(frame('CONNECT', { 'accept-version': '1.2', host: 'x', 'heart-beat': '0,0', Authorization: 'Bearer ' + forge(SENDER) }));
ws.onerror = () => { console.error('baglanti hatasi'); process.exit(2); };
ws.onmessage = (ev) => {
  for (const part of String(ev.data).split('\0')) {
    const p = part.replace(/^\n+/, '');
    if (!p) continue;
    if (p.startsWith('CONNECTED')) {
      ws.send(frame('SUBSCRIBE', { id: 'm', destination: '/user/queue/messages' }));
      ws.send(frame('SUBSCRIBE', { id: 'e', destination: '/user/queue/errors' }));
      setTimeout(() => {
        // hepsi ayni tick'te: sunucuya art arda dusen N cerceve
        for (let i = 0; i < N; i++) {
          ws.send(frame('SEND', { destination: '/app/chat.send', 'content-type': 'application/json' },
            JSON.stringify({ conversationId: CONV, text: 'sira ' + i, clientId: 'ord-' + run + '-' + i })));
        }
      }, 300);
    } else if (p.startsWith('ERROR')) {
      console.error(p.slice(0, 200));
    } else if (p.startsWith('MESSAGE')) {
      const body = p.split('\n\n').slice(1).join('\n\n');
      let j = null; try { j = JSON.parse(body); } catch { /* hata kuyrugu govdesi */ }
      if (j && j.clientId && String(j.clientId).startsWith('ord-' + run + '-')) {
        got.push({ id: j.id, seq: Number(String(j.clientId).split('-').pop()) });
        if (got.length === N) finish();
      } else if (j && j.code) {
        console.error('hata kuyrugu:', j.code, j.message);
      }
    }
  }
};
setTimeout(() => { console.error(`zaman asimi: ${got.length}/${N} mesaj geldi`); finish(); }, 20000);

let finished = false;
function finish() {
  if (finished) return;
  finished = true;
  const byId = got.slice().sort((a, b) => a.id - b.id).map((g) => g.seq);
  const inOrder = byId.every((s, i) => s === i);
  console.log('kimlik sirasina gore gonderim sirasi:', byId.join(' '));
  console.log(inOrder && got.length === N ? 'OK: sira korundu (' + N + ' cerceve)' : 'FAIL: sira bozuldu ya da eksik (' + got.length + '/' + N + ')');
  try { ws.close(); } catch { /* */ }
  process.exit(inOrder && got.length === N ? 0 : 1);
}
