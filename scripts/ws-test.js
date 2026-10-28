#!/usr/bin/env node
// Mesajlasma WebSocket/STOMP uctan uca testi (STOMP cerceveleri elle yazilir).
// Kullanim: BASE=http://localhost:8080 JWT_SECRET=<sunucudaki> node scripts/ws-test.js
//   SLOW=1  -> token suresi dolunca SEND reddi testi de calisir (~70 sn ekler)
// Onkosul: compose'ta MAIL_ENABLED=false (dogrulama kodu docker compose logs'tan okunur), Node 22+ (yerlesik WebSocket/fetch).
// Harici paket gerekmez; yerlesik WebSocket yoksa scripts/ icinde `npm install ws` ile yedek kullanilir.
'use strict';
const { execSync } = require('node:child_process');
const crypto = require('node:crypto');

const BASE = process.env.BASE || 'http://localhost:8080';
const WS_URL = BASE.replace(/^http/, 'ws') + '/ws';
const SECRET = process.env.JWT_SECRET || 'test-secret-test-secret-test-secret-9999';
const WS = typeof WebSocket !== 'undefined' ? WebSocket : require('ws');
let failed = 0;

function check(name, cond, extra) {
  if (cond) console.log('  ok   ' + name);
  else { failed++; console.log('  FAIL ' + name + (extra !== undefined ? ' -> ' + JSON.stringify(extra) : '')); }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---- REST yardimcilari ----
async function api(method, path, token, body) {
  const res = await fetch(BASE + '/api' + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* govde JSON degil */ }
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

// ---- JWT uretimi (yalnizca test: ayni gizli anahtarla suresi kisa/dolmus token) ----
function forgeJwt(userId, expEpoch) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const head = b64({ alg: 'HS256' });
  const body = b64({ sub: String(userId), role: 'USER', iat: Math.floor(Date.now() / 1000) - 10, exp: expEpoch });
  const sig = crypto.createHmac('sha256', Buffer.from(SECRET, 'utf8')).update(head + '.' + body).digest('base64url');
  return head + '.' + body + '.' + sig;
}

// ---- Minimal STOMP istemcisi ----
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
          if (!part.trim()) continue; // heartbeat
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
  subscribe(dest, id) { this.ws.send(encode('SUBSCRIBE', { id: id || dest, destination: dest })); }
  // Kosulu saglayan ilk cerceveyi bekler (zaman asimi: null)
  waitFor(pred, ms = 4000) {
    return new Promise((resolve) => {
      const test = () => { const f = this.frames.find(pred); if (f) { done(f); return true; } return false; };
      const done = (v) => { clearTimeout(t); this.waiters = this.waiters.filter((w) => w !== test); resolve(v); };
      const t = setTimeout(() => done(null), ms);
      if (!test()) this.waiters.push(test);
    });
  }
  on(dest, extra) { return this.waitFor((f) => f.command === 'MESSAGE' && f.headers.destination === '/user/queue/' + dest && (!extra || extra(f.json))); }
  count(dest, extra) { return this.frames.filter((f) => f.command === 'MESSAGE' && f.headers.destination === '/user/queue/' + dest && (!extra || extra(f.json))).length; }
  close() { try { this.ws.close(); } catch { /* kapali */ } }
}

async function login(token) {
  const c = await Stomp.open(token);
  if (c.connected) for (const q of ['messages', 'read-receipts', 'typing', 'errors']) c.subscribe('/user/queue/' + q);
  await sleep(300);
  return c;
}

(async () => {
  const sfx = Math.floor(Math.random() * 1e6);
  console.log('== kullanicilar');
  const A = await register(`wa${sfx}@bingol.edu.tr`, 'Ws Ali');
  const B = await register(`wb${sfx}@bingol.edu.tr`, 'Ws Ayse');
  const C = await register(`wc${sfx}@bingol.edu.tr`, 'Ws Can');
  const conv = (await api('POST', '/conversations', A.token, { userId: B.id })).json.id;
  const convBC = (await api('POST', '/conversations', C.token, { userId: B.id })).json.id;

  console.log('== CONNECT kimlik dogrulamasi');
  let c = await Stomp.open(null);
  check('token yok -> ERROR, baglanti yok', !c.connected && c.frames.some((f) => f.command === 'ERROR'), c.frames);
  c = await Stomp.open('abc.def.ghi');
  check('gecersiz token -> ERROR', !c.connected && c.frames.some((f) => f.command === 'ERROR'));
  await sleep(300);
  check('gecersiz token sonrasi baglanti kapanir', c.closed);
  c = await Stomp.open(forgeJwt(A.id, Math.floor(Date.now() / 1000) - 3600));
  check('suresi dolmus token -> ERROR', !c.connected && c.frames.some((f) => f.command === 'ERROR'));
  c = await Stomp.open(forgeJwt(A.id, Math.floor(Date.now() / 1000) + 600).replace(/.$/, (x) => (x === 'A' ? 'B' : 'A')));
  check('imzasi bozuk token -> ERROR', !c.connected);
  c = await Stomp.open(A.token);
  check('gecerli token -> CONNECTED', c.connected);
  c.close();

  console.log('== yetkisiz SUBSCRIBE / SEND hedefleri');
  c = await Stomp.open(A.token);
  c.subscribe('/topic/chat');
  check('/topic aboneligi reddedilir', !!(await c.waitFor((f) => f.command === 'ERROR', 3000)));
  c = await Stomp.open(A.token);
  c.subscribe('/user/queue/messages');
  c.send('/topic/chat', { x: 1 });
  check('/topic SEND reddedilir', !!(await c.waitFor((f) => f.command === 'ERROR', 3000)));
  c = await Stomp.open(A.token);
  c.send('/user/queue/messages', { x: 1 });
  check('kuyruga dogrudan SEND reddedilir', !!(await c.waitFor((f) => f.command === 'ERROR', 3000)));

  console.log('== mesaj teslimi A -> B');
  const ca = await login(A.token);
  const cb = await login(B.token);
  check('A ve B bagli', ca.connected && cb.connected);
  const pr = await api('GET', `/users/${B.id}/presence`, A.token);
  check('B cevrimici gorunur', pr.status === 200 && pr.json.online === true, pr);
  ca.send('/app/chat.send', { conversationId: conv, text: 'Merhaba <b>Ayse</b>', clientId: 'ws-1' });
  const got = await cb.on('messages', (m) => m.clientId === 'ws-1');
  check('B mesaji aldi', !!got && got.json.text === 'Merhaba <b>Ayse</b>' && got.json.senderId === A.id, got && got.json);
  const ack = await ca.on('messages', (m) => m.clientId === 'ws-1');
  check('A gonderim onayi (echo) aldi', !!ack && ack.json.id === got.json.id);
  ca.send('/app/chat.send', { conversationId: conv, text: 'Merhaba <b>Ayse</b>', clientId: 'ws-1' });
  await sleep(800);
  check('ayni clientId tekrar: ikinci teslimat yok', cb.count('messages', (m) => m.clientId === 'ws-1') === 1);
  const hist = await api('GET', `/conversations/${conv}/messages`, B.token);
  check('gecmiste tek kayit', hist.json.items.filter((m) => m.clientId === 'ws-1').length === 1);
  const rest = await api('POST', `/conversations/${conv}/messages`, B.token, { text: 'REST ile cevap', clientId: 'rest-1' });
  check('REST gonderim 201', rest.status === 201);
  check('REST mesaji A\'ya WebSocket ile ulasir', !!(await ca.on('messages', (m) => m.clientId === 'rest-1')));

  console.log('== yaziyor ve okundu');
  ca.send('/app/chat.typing', { conversationId: conv });
  const ty = await cb.on('typing');
  check('B yaziyor bilgisi aldi', !!ty && ty.json.userId === A.id && ty.json.conversationId === conv, ty && ty.json);
  // B'nin kendi mesaji (rest-1) imlecini ilerletti; A bir mesaj daha yazinca B icin 1 okunmamis olur
  ca.send('/app/chat.send', { conversationId: conv, text: 'okunacak', clientId: 'ws-2' });
  const got2 = await cb.on('messages', (m) => m.clientId === 'ws-2');
  const unread = (await api('GET', '/conversations', B.token)).json.items.find((x) => x.id === conv).unreadCount;
  check('B icin okunmamis 1', unread === 1, unread);
  cb.send('/app/chat.read', { conversationId: conv, lastMessageId: got2.json.id });
  const rr = await ca.on('read-receipts');
  check('A okundu bilgisi aldi', !!rr && rr.json.userId === B.id && rr.json.lastMessageId === got2.json.id, rr && rr.json);
  const unread2 = (await api('GET', '/conversations', B.token)).json.items.find((x) => x.id === conv).unreadCount;
  check('B icin okunmamis 0', unread2 === 0, unread2);
  cb.send('/app/chat.read', { conversationId: conv, lastMessageId: 1 });
  await sleep(600);
  check('geri giden imlec bildirim uretmez', ca.count('read-receipts') === 1);
  cb.send('/app/chat.read', { conversationId: conv, lastMessageId: got.json.id + 100000 });
  const bad = await cb.on('errors', (m) => m.code === 'INVALID_MESSAGE_ID');
  check('son mesaji asan imlec reddedilir', !!bad);

  console.log('== hatalar /user/queue/errors');
  ca.send('/app/chat.send', { conversationId: conv, text: '   ', clientId: 'ws-e1' });
  const e1 = await ca.on('errors', (m) => m.clientId === 'ws-e1');
  check('bos mesaj -> EMPTY_MESSAGE', !!e1 && e1.json.code === 'EMPTY_MESSAGE', e1 && e1.json);
  ca.send('/app/chat.send', { conversationId: conv, text: 'a'.repeat(2001), clientId: 'ws-e2' });
  const e2 = await ca.on('errors', (m) => m.clientId === 'ws-e2');
  check('2001 karakter -> MESSAGE_TOO_LONG', !!e2 && e2.json.code === 'MESSAGE_TOO_LONG');
  const cc = await login(C.token);
  cc.send('/app/chat.send', { conversationId: conv, text: 'icerdeyim', clientId: 'ws-e3' });
  const e3 = await cc.on('errors', (m) => m.clientId === 'ws-e3');
  check('katilimci olmayan -> CONVERSATION_NOT_FOUND', !!e3 && e3.json.code === 'CONVERSATION_NOT_FOUND', e3 && e3.json);
  check('katilimci olmayan mesaji kimseye gitmedi', cb.count('messages', (m) => m.clientId === 'ws-e3') === 0);
  ca.send('/app/chat.send', 'bozuk-yuk');
  const e4 = await ca.on('errors', (m) => m.code === 'BAD_REQUEST');
  check('bozuk yuk -> BAD_REQUEST (baglanti acik kalir)', !!e4 && !ca.closed);

  console.log('== engelleme');
  await api('POST', `/users/${A.id}/block`, B.token);
  const before = cb.count('messages');
  ca.send('/app/chat.send', { conversationId: conv, text: 'engelliyim', clientId: 'ws-b1' });
  const eb = await ca.on('errors', (m) => m.clientId === 'ws-b1');
  check('engelli gonderim -> BLOCKED', !!eb && eb.json.code === 'BLOCKED', eb && eb.json);
  await sleep(500);
  check('engelleyene mesaj ulasmadi', cb.count('messages') === before);
  cb.send('/app/chat.send', { conversationId: conv, text: 'ben engelledim', clientId: 'ws-b2' });
  const eb2 = await cb.on('errors', (m) => m.clientId === 'ws-b2');
  check('engelleyen de gonderemez -> BLOCKED', !!eb2 && eb2.json.code === 'BLOCKED');
  const pr2 = await api('GET', `/users/${B.id}/presence`, A.token);
  check('engelli kullanicinin presence bilgisi gizli', pr2.status === 404);
  await api('DELETE', `/users/${A.id}/block`, B.token);

  console.log('== hiz limiti (kullanici basina dakikada 30)');
  const cb2 = cb; // B, C ile olan konusmada gonderir
  for (let i = 1; i <= 33; i++) cb2.send('/app/chat.send', { conversationId: convBC, text: 'm' + i, clientId: 'rl-' + i });
  await sleep(3500);
  // B bu testte onceden 1 REST + ... mesaj gonderdi (REST de ayni limiti kullanir), bu yuzden esik yaklasik
  const okCount = cc.count('messages', (m) => m.clientId && m.clientId.startsWith('rl-'));
  const limited = cb2.count('errors', (m) => m.code === 'RATE_LIMITED');
  check('limit asilinca RATE_LIMITED hatalari gelir', limited >= 3, { okCount, limited });
  check('en fazla 30 mesaj gecer', okCount <= 30 && okCount >= 25, { okCount });

  console.log('== presence ve cevrimdisi bildirim');
  const bConvPresence = await api('GET', `/users/${B.id}/presence`, C.token);
  check('ortak konusmali C, B\'nin durumunu gorur', bConvPresence.status === 200 && bConvPresence.json.online === true, bConvPresence);
  const stranger = await api('GET', `/users/${A.id}/presence`, C.token);
  check('ortak konusmasi olmayan 404', stranger.status === 404);
  cb.close();
  await sleep(1500);
  const off = await api('GET', `/users/${B.id}/presence`, C.token);
  check('B kapatinca cevrimdisi + son gorulme', off.json.online === false && !!off.json.lastSeenAt, off);
  ca.send('/app/chat.send', { conversationId: conv, text: 'cevrimdisisin', clientId: 'ws-off' });
  await ca.on('messages', (m) => m.clientId === 'ws-off');
  const notes = await api('GET', '/notifications', B.token);
  check('cevrimdisi alici icin MESSAGE bildirimi olustu',
    !!notes.json && notes.json.items.some((n) => n.type === 'MESSAGE'), notes.json && notes.json.items.map((n) => n.type));
  const cbn = await login(B.token);
  const hb = await api('GET', `/conversations/${conv}/messages?after=${got.json.id}`, B.token);
  check('yeniden baglanan B kacirdigini after= ile ceker', hb.json.items.some((m) => m.clientId === 'ws-off'));
  const notes2 = (await api('GET', '/notifications', B.token)).json.items.filter((n) => n.type === 'MESSAGE').length;
  ca.send('/app/chat.send', { conversationId: conv, text: 'cevrimicisin', clientId: 'ws-on' });
  check('cevrimici B WebSocket ile alir', !!(await cbn.on('messages', (m) => m.clientId === 'ws-on')));
  await sleep(500);
  const notes3 = (await api('GET', '/notifications', B.token)).json.items.filter((n) => n.type === 'MESSAGE').length;
  check('cevrimici alici icin ek bildirim olusmaz', notes3 === notes2, { notes2, notes3 });

  if (process.env.SLOW === '1') {
    console.log('== token suresi dolunca SEND reddi (~70 sn)');
    const soon = await login(forgeJwt(A.id, Math.floor(Date.now() / 1000) + 3));
    soon.send('/app/chat.send', { conversationId: conv, text: 'suresi dolmadan', clientId: 'exp-1' });
    check('suresi dolmadan SEND basarili', !!(await soon.on('messages', (m) => m.clientId === 'exp-1')));
    await sleep(68000);
    soon.send('/app/chat.send', { conversationId: conv, text: 'suresi doldu', clientId: 'exp-2' });
    const er = await soon.waitFor((f) => f.command === 'ERROR', 4000);
    check('sure + tolerans sonrasi SEND -> ERROR (TOKEN_EXPIRED)', !!er && /TOKEN_EXPIRED/.test(JSON.stringify(er)), er);
    await sleep(500);
    check('baglanti kapandi (istemci yeniden baglanmali)', soon.closed);
    const re = await login(A.token);
    check('yeni token ile yeniden baglanilir', re.connected);
    re.close();
  }

  [ca, cc, cbn].forEach((x) => x.close());
  console.log(failed === 0 ? '\nTUM WS KONTROLLERI GECTI' : `\n${failed} WS KONTROLU BASARISIZ`);
  process.exit(failed === 0 ? 0 : 1);
})().catch((e) => { console.error(e); process.exit(2); });
