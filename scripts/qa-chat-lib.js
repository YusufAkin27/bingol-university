'use strict';
// Sohbet QA betikleri icin ortak yardimcilar (REST, kullanici hazirlama, JWT, minimal STOMP istemcisi).
// Onkosul: Node 22+ (yerlesik fetch/WebSocket), compose'ta MAIL_ENABLED=false, COMPOSE_PROJECT_NAME ortamda.
const { execSync } = require('node:child_process');
const crypto = require('node:crypto');

const BASE = process.env.BASE || 'http://localhost:8102';
const WS_URL = BASE.replace(/^http/, 'ws') + '/ws';
const SECRET = process.env.JWT_SECRET || 'test-secret-test-secret-test-secret-9999';
const ADMIN_PW = process.env.ADMIN_PASSWORD || 'adminpw123';
const WS = typeof WebSocket !== 'undefined' ? WebSocket : require('ws');

const state = { failed: 0, passed: 0 };
function check(name, cond, extra) {
  if (cond) { state.passed++; console.log('  ok   ' + name); }
  else { state.failed++; console.log('  FAIL ' + name + (extra !== undefined ? ' -> ' + JSON.stringify(extra) : '')); }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function api(method, path, token, body, extraHeaders) {
  const res = await fetch(BASE + '/api' + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}), ...(extraHeaders || {}) },
    body: body === undefined ? undefined : (typeof body === 'string' ? body : JSON.stringify(body)),
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* JSON degil */ }
  return { status: res.status, json, text };
}

// Yonetici uclari: Basic auth admin:$ADMIN_PASSWORD
async function admin(method, path, body) {
  const res = await fetch(BASE + '/api/admin' + path, {
    method,
    headers: { 'Content-Type': 'application/json', Authorization: 'Basic ' + Buffer.from('admin:' + ADMIN_PW).toString('base64') },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: res.status, text: await res.text() };
}

function redis(cmd) {
  return execSync('docker compose exec -T redis redis-cli ' + cmd, { encoding: 'utf8' }).trim();
}

async function register(email, name) {
  await api('POST', '/auth/register', null, { email, password: 'Sifre1234', displayName: name, acceptTerms: true });
  let code = null;
  for (let i = 0; i < 10 && !code; i++) {
    await sleep(500);
    const logs = execSync('docker compose logs backend', { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 });
    const m = [...logs.matchAll(new RegExp(email.replace(/\./g, '\\.') + ' icin dogrulama kodu: (\\d+)', 'g'))].pop();
    code = m && m[1];
  }
  let r = await api('POST', '/auth/verify-email', null, { email, code });
  if (!r.json || !r.json.accessToken) r = await api('POST', '/auth/login', null, { email, password: 'Sifre1234' });
  if (!r.json || !r.json.accessToken) throw new Error('kayit basarisiz: ' + email + ' ' + r.text);
  const token = r.json.accessToken;
  const me = await api('GET', '/users/me', token);
  return { email, token, id: me.json.id, name };
}

function forgeJwt(userId, expEpoch, role) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const head = b64({ alg: 'HS256' });
  const body = b64({ sub: String(userId), role: role || 'USER', iat: Math.floor(Date.now() / 1000) - 10, exp: expEpoch });
  const sig = crypto.createHmac('sha256', Buffer.from(SECRET, 'utf8')).update(head + '.' + body).digest('base64url');
  return head + '.' + body + '.' + sig;
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
  constructor() { this.frames = []; this.closed = false; this.waiters = []; this.closeCode = null; }
  static open(token, opts) {
    const o = opts || {};
    const c = new Stomp();
    return new Promise((resolve) => {
      c.ws = new WS(WS_URL, ['v12.stomp']);
      c.ws.onerror = () => {};
      c.ws.onclose = (ev) => { c.closed = true; c.closeCode = ev && ev.code; c.notify(); resolve(c); };
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
        const h = { 'accept-version': '1.2', host: 'localhost', 'heart-beat': o.heartbeat || '0,0' };
        if (token) h.Authorization = 'Bearer ' + token;
        c.ws.send(encode('CONNECT', h));
      };
      setTimeout(() => resolve(c), o.timeout || 8000);
    });
  }
  get connected() { return this.frames.some((f) => f.command === 'CONNECTED'); }
  notify() { this.waiters.forEach((w) => w()); }
  send(dest, obj) { this.ws.send(encode('SEND', { destination: dest, 'content-type': 'application/json' }, typeof obj === 'string' ? obj : JSON.stringify(obj))); }
  subscribe(dest, id) { this.ws.send(encode('SUBSCRIBE', { id: id || dest, destination: dest })); }
  waitFor(pred, ms = 4000) {
    return new Promise((resolve) => {
      const test = () => { const f = this.frames.find(pred); if (f) { done(f); return true; } return false; };
      const done = (v) => { clearTimeout(t); this.waiters = this.waiters.filter((w) => w !== test); resolve(v); };
      const t = setTimeout(() => done(null), ms);
      if (!test()) this.waiters.push(test);
    });
  }
  on(dest, extra, ms) { return this.waitFor((f) => f.command === 'MESSAGE' && f.headers.destination === '/user/queue/' + dest && (!extra || extra(f.json)), ms); }
  count(dest, extra) { return this.frames.filter((f) => f.command === 'MESSAGE' && f.headers.destination === '/user/queue/' + dest && (!extra || extra(f.json))).length; }
  close() { try { this.ws.close(); } catch { /* kapali */ } }
}

async function login(token, opts) {
  const c = await Stomp.open(token, opts);
  if (c.connected) for (const q of ['messages', 'read-receipts', 'typing', 'errors']) c.subscribe('/user/queue/' + q);
  await sleep(200);
  return c;
}

function summary(title) {
  console.log(state.failed === 0 ? `\nTUM ${title} KONTROLLERI GECTI (${state.passed})` : `\n${state.failed} ${title} KONTROLU BASARISIZ (${state.passed} gecti)`);
  process.exit(state.failed === 0 ? 0 : 1);
}

module.exports = { BASE, WS_URL, check, sleep, api, admin, redis, register, forgeJwt, Stomp, login, state, summary };
