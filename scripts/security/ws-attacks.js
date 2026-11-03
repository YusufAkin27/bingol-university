#!/usr/bin/env node
// T5 guvenlik denetimi: WebSocket/STOMP'a ozel saldirilar (genel akis testleri scripts/ws-test.js'de).
// Kapsam: token'siz CONNECT, baskasinin /user kuyruguna dogrudan abonelik, SEND govdesinde
// gonderici (senderId/userId) alani sahteciligi, broker-genis /queue/* aboneligi, SUBSCRIBE
// olmadan SEND. Kullanim: BASE=http://localhost:8105 node scripts/security/ws-attacks.js
'use strict';
const { execSync } = require('node:child_process');

const BASE = process.env.BASE || 'http://localhost:8105';
const WS_URL = BASE.replace(/^http/, 'ws') + '/ws';
const WS = typeof WebSocket !== 'undefined' ? WebSocket : require('ws');
let failed = 0;
function check(name, cond, extra) {
  if (cond) console.log('  OK      ' + name);
  else { failed++; console.log('  FINDING ' + name + (extra !== undefined ? ' -> ' + JSON.stringify(extra) : '')); }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function api(method, path, token, body) {
  const res = await fetch(BASE + '/api' + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* json degil */ }
  return { status: res.status, json };
}
async function register(email, name) {
  await api('POST', '/auth/register', null, { email, password: 'Sifre1234', displayName: name, acceptTerms: true });
  await sleep(1000);
  const logs = execSync('docker compose logs backend', { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  const m = [...logs.matchAll(new RegExp(email.replace('.', '\\.') + ' icin dogrulama kodu: (\\d+)', 'g'))].pop();
  let r = await api('POST', '/auth/verify-email', null, { email, code: m && m[1], password: 'Sifre1234' });
  if (!r.json || !r.json.accessToken) r = await api('POST', '/auth/login', null, { email, password: 'Sifre1234' });
  const token = r.json.accessToken;
  const me = await api('GET', '/users/me', token);
  return { token, id: me.json.id };
}

function encode(command, headers, body) {
  let s = command + '\n';
  for (const [k, v] of Object.entries(headers || {})) s += k + ':' + v + '\n';
  return s + '\n' + (body || '') + '\0';
}
function parse(chunk) {
  const [head, ...rest] = chunk.split('\n\n');
  const lines = head.split('\n').filter((l) => l.length);
  const headers = {};
  for (const l of lines.slice(1)) { const i = l.indexOf(':'); headers[l.slice(0, i)] = l.slice(i + 1); }
  const raw = rest.join('\n\n');
  let json = null;
  try { json = raw ? JSON.parse(raw) : null; } catch { /* metin govde */ }
  return { command: lines[0], headers, body: raw, json };
}
class Stomp {
  constructor() { this.frames = []; this.closed = false; this.waiters = []; }
  static open(token) {
    const c = new Stomp();
    return new Promise((resolve) => {
      c.ws = new WS(WS_URL, ['v12.stomp']);
      c.ws.onerror = () => {};
      c.ws.onclose = () => { c.closed = true; c.notify(); resolve(c); };
      c.ws.onmessage = (ev) => {
        for (const part of String(ev.data).split('\0')) {
          if (!part.trim()) continue;
          const f = parse(part.replace(/^\n+/, ''));
          c.frames.push(f);
          if (f.command === 'CONNECTED') resolve(c);
          c.notify();
        }
      };
      c.ws.onopen = () => {
        const h = { 'accept-version': '1.2', host: 'localhost', 'heart-beat': '0,0' };
        if (token) h.Authorization = 'Bearer ' + token;
        c.ws.send(encode('CONNECT', h));
      };
      setTimeout(() => resolve(c), 6000);
    });
  }
  get connected() { return this.frames.some((f) => f.command === 'CONNECTED'); }
  notify() { this.waiters.forEach((w) => w()); }
  send(dest, obj) { this.ws.send(encode('SEND', { destination: dest, 'content-type': 'application/json' }, JSON.stringify(obj))); }
  rawSend(dest, bodyStr) { this.ws.send(encode('SEND', { destination: dest, 'content-type': 'application/json' }, bodyStr)); }
  subscribe(dest, id) { this.ws.send(encode('SUBSCRIBE', { id: id || dest, destination: dest })); }
  waitFor(pred, ms = 3000) {
    return new Promise((resolve) => {
      const test = () => { const f = this.frames.find(pred); if (f) { done(f); return true; } return false; };
      const done = (v) => { clearTimeout(t); this.waiters = this.waiters.filter((w) => w !== test); resolve(v); };
      const t = setTimeout(() => done(null), ms);
      if (!test()) this.waiters.push(test);
    });
  }
  countAll(pred) { return this.frames.filter(pred).length; }
  close() { try { this.ws.close(); } catch { /* kapali */ } }
}

(async () => {
  const sfx = Math.floor(Math.random() * 1e6);
  console.log('== kullanicilar');
  const A = await register(`wsatk-a-${sfx}@bingol.edu.tr`, 'WsAtk A');
  const B = await register(`wsatk-b-${sfx}@bingol.edu.tr`, 'WsAtk B');
  const conv = (await api('POST', '/conversations', A.token, { userId: B.id })).json.id;
  console.log('A id=%s B id=%s conv=%s', A.id, B.id, conv);

  console.log('== 1) token siz CONNECT');
  let c = await Stomp.open(null);
  check('token olmadan CONNECT reddedilir (UNAUTHORIZED)', !c.connected && c.frames.some((f) => f.command === 'ERROR'), c.frames.map(f=>f.command));

  console.log('== 2) baskasinin /user kuyruguna dogrudan abonelik (B kimligiyle A nin kuyrugunu istemek)');
  c = await Stomp.open(B.token);
  // Spring'in /user hedef cevirisi sunucu tarafindadir; istemci asla /user/{id}/... yazmaz, ama
  // saldirgan bunu deneyebilir -- sunucunun bunu reddetmesi (SUBSCRIBABLE beyaz listesi) beklenir.
  c.subscribe(`/user/${A.id}/queue/messages`, 'spy');
  let spyErr = await c.waitFor((f) => f.command === 'ERROR', 2000);
  check('"/user/{baskasininId}/queue/messages" aboneligi reddedilir', !!spyErr, spyErr && spyErr.headers);
  c.close();

  console.log('== 3) broker-genis /queue/* (kullanici onekisiz) aboneligi');
  c = await Stomp.open(B.token);
  c.subscribe('/queue/messages', 'raw');
  let rawErr = await c.waitFor((f) => f.command === 'ERROR', 2000);
  check('"/queue/messages" (ham, kullanici onekisiz) aboneligi reddedilir', !!rawErr);
  c.close();

  console.log('== 4) SEND govdesinde gonderici sahteciligi (senderId/userId alani)');
  const ca = await Stomp.open(A.token);
  for (const q of ['messages', 'errors']) ca.subscribe('/user/queue/' + q);
  const cb = await Stomp.open(B.token);
  for (const q of ['messages', 'errors']) cb.subscribe('/user/queue/' + q);
  await sleep(300);
  // B, A'nin kimliginden gelmis gibi gorunmeye calisarak mesaj govdesine senderId/userId ekler.
  cb.send('/app/chat.send', { conversationId: conv, text: 'ben Ayim', clientId: 'spoof-1', senderId: A.id, userId: A.id, principal: A.id });
  const delivered = await ca.waitFor((f) => f.command === 'MESSAGE' && f.json && f.json.clientId === 'spoof-1', 2000);
  check('govdedeki sahte senderId/userId yok sayilir (gonderen daima Principal dan alinir)',
    !delivered || (delivered.json.senderId === B.id),
    delivered && delivered.json);

  console.log('== 5) SUBSCRIBE olmadan SEND (sunucu yine de islemeli, ama yanit kaybolabilir)');
  const cc = await Stomp.open(B.token); // abone olmadan dogrudan gonder
  cc.send('/app/chat.send', { conversationId: conv, text: 'abonesiz gonderim', clientId: 'nosub-1' });
  await sleep(500);
  check('abonesiz SEND sunucu tarafinda reddedilmez/çökmez (baglanti acik kalir)', !cc.closed);

  ca.close(); cb.close(); cc.close();
  console.log(failed === 0 ? '\nTUM TESTLER GECTI' : `\n${failed} BULGU (yukarida FINDING olarak isaretli)`);
  process.exit(failed === 0 ? 0 : 1);
})().catch((e) => { console.error('BETIK HATASI', e); process.exit(2); });
