#!/usr/bin/env node
// Sozlesme testi: docs/openapi.json ile CANLI sunucunun gercek yanitlarini karsilastirir.
//  1) Canli /v3/api-docs ile docs/openapi.json ayni mi (surum kaymasi)?  (DRIFT=0 ile atlanir)
//  2) Giris gerektirmeyen/yetkili tum parametresiz GET uclari + kimlik akisi cagrilir; durum kodu belgelenmis mi,
//     govde semaya uyuyor mu (tur, zorunlu alan, belgelenmemis alan)?
// Kullanim: BASE=http://localhost:8107 ADMIN_PASSWORD=adminpw123 COMPOSE_PROJECT_NAME=wt_t7 node scripts/openapi-check.js
// Gereken: calisan compose yigini (dogrulama kodu backend log'undan okunur; app.mail.enabled=false).
// Cikis kodu 0 = uyumlu, 1 = uyumsuzluk var.
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const BASE = process.env.BASE || 'http://localhost:8080';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'adminpw123';
const ROOT = path.join(__dirname, '..');
const SPEC = JSON.parse(fs.readFileSync(path.join(ROOT, 'docs', 'openapi.json'), 'utf8'));
const USER_EMAIL = process.env.CHECK_USER || 'contract-user@bingol.edu.tr';
const ADMIN_EMAIL = process.env.CHECK_ADMIN || 'admin1@bingol.edu.tr';
const PASS = 'Sifre1234x';
const FORCE_SEED = process.env.FORCE_SEED === '1'; // her kosuda ornek kayit olusturup POST govdelerini de dogrula

const failures = [];
const warnings = [];
let checked = 0;
const fail = (m) => failures.push(m);
const warn = (m) => warnings.push(m);

// ---------- Basit JSON Schema (OpenAPI 3.1) dogrulayici ----------
function deref(s) {
  while (s && s.$ref) {
    const name = s.$ref.replace('#/components/schemas/', '');
    s = SPEC.components.schemas[name];
    if (!s) throw new Error('cozulemeyen $ref ' + name);
  }
  return s;
}
const typeOf = (v) => (v === null ? 'null' : Array.isArray(v) ? 'array' : Number.isInteger(v) ? 'integer' : typeof v);

function validate(schema, v, at, errs) {
  schema = deref(schema);
  if (!schema || Object.keys(schema).length === 0) return; // serbest
  if (schema.allOf) schema.allOf.forEach((s) => validate(s, v, at, errs));
  if (schema.oneOf || schema.anyOf) {
    const alts = schema.oneOf || schema.anyOf;
    const ok = alts.some((s) => {
      const e = [];
      validate(s, v, at, e);
      return e.length === 0;
    });
    if (!ok) errs.push(`${at}: oneOf/anyOf hicbirine uymuyor`);
    return;
  }
  let types = schema.type ? [].concat(schema.type) : null;
  if (!types) {
    if (schema.properties) types = ['object'];
    else if (schema.items) types = ['array'];
    else return;
  }
  const t = typeOf(v);
  if (v === null) {
    if (!types.includes('null') && schema.nullable !== true) errs.push(`${at}: null ama sema null kabul etmiyor`);
    return;
  }
  const okType = types.some((x) => x === t || (x === 'number' && t === 'integer'));
  if (!okType) {
    errs.push(`${at}: tur ${t}, semada ${types.join('|')}`);
    return;
  }
  if (t === 'object') {
    const props = schema.properties || {};
    for (const r of schema.required || []) if (!(r in v)) errs.push(`${at}: zorunlu alan eksik: ${r}`);
    for (const [k, val] of Object.entries(v)) {
      if (props[k]) validate(props[k], val, `${at}.${k}`, errs);
      else if (!schema.additionalProperties) errs.push(`${at}: belgelenmemis alan: ${k}`);
      else if (typeof schema.additionalProperties === 'object') validate(schema.additionalProperties, val, `${at}.${k}`, errs);
    }
  } else if (t === 'array' && schema.items) {
    v.slice(0, 5).forEach((x, i) => validate(schema.items, x, `${at}[${i}]`, errs));
  } else if (schema.enum && !schema.enum.includes(v)) {
    errs.push(`${at}: enum disi deger ${JSON.stringify(v)}`);
  }
}

// ---------- HTTP ----------
async function call(method, p, { token, basic, body, headers } = {}) {
  const h = { 'Accept-Language': 'tr', ...(headers || {}) };
  if (token) h.Authorization = 'Bearer ' + token;
  if (basic) h.Authorization = 'Basic ' + Buffer.from('admin:' + ADMIN_PASSWORD).toString('base64');
  if (body !== undefined) h['Content-Type'] = 'application/json';
  const res = await fetch(BASE + p, { method, headers: h, body: body !== undefined ? JSON.stringify(body) : undefined });
  const text = await res.text();
  let json;
  try { json = text ? JSON.parse(text) : undefined; } catch { json = undefined; }
  return { status: res.status, json, text, type: res.headers.get('content-type') || '' };
}

function responseSchema(op, status) {
  const r = (op.responses || {})[String(status)];
  if (!r) return { documented: false };
  const c = r.content && (r.content['application/json'] || r.content['*/*']);
  return { documented: true, schema: c && c.schema };
}

function checkBody(label, method, p, res) {
  checked++;
  const op = (SPEC.paths[p] || {})[method.toLowerCase()];
  if (!op) return fail(`${label}: belgede yok (${method} ${p})`);
  const { documented, schema } = responseSchema(op, res.status);
  if (!documented) {
    // 2xx belgelenmeli; 4xx icin ortak ApiError varsayilir
    if (res.status < 300) return fail(`${label}: ${res.status} belgelenmemis`);
    if (res.json && (typeof res.json.code !== 'string' || typeof res.json.message !== 'string'))
      fail(`${label}: ${res.status} hata govdesi {code,message} degil: ${res.text.slice(0, 120)}`);
    else warn(`${label}: ${res.status} belgede listelenmemis (hata govdesi tamam)`);
    return;
  }
  if (!schema || res.status === 204 || res.text === '') return;
  if (!res.type.includes('json')) return; // csv/dosya
  const errs = [];
  validate(schema, res.json, '$', errs);
  errs.slice(0, 6).forEach((e) => fail(`${label}: ${e}`));
}

// ---------- Kullanici hazirlama ----------
function codeFromLog(email) {
  const log = execSync('docker compose logs backend', { cwd: ROOT, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  const m = [...log.matchAll(new RegExp(email.replace(/[.]/g, '\\.') + ' icin[^\\n]*?kodu: (\\d+)', 'g'))].pop();
  return m && m[1];
}

async function login(email) {
  const r = await call('POST', '/api/auth/login', { body: { email, password: PASS } });
  checkBody('login ' + email, 'POST', '/api/auth/login', r);
  return r.status === 200 ? r.json : null;
}

async function ensureUser(email, name) {
  let t = await login(email);
  if (t) return t;
  const reg = await call('POST', '/api/auth/register', { body: { email, password: PASS, displayName: name, acceptTerms: true } });
  checkBody('register ' + email, 'POST', '/api/auth/register', reg);
  await new Promise((r) => setTimeout(r, 1200));
  const code = codeFromLog(email);
  if (!code) throw new Error('dogrulama kodu log\'da yok: ' + email + ' (register=' + reg.status + ')');
  const v = await call('POST', '/api/auth/verify-email', { body: { email, code } });
  checkBody('verify ' + email, 'POST', '/api/auth/verify-email', v);
  if (v.status !== 200) throw new Error('verify basarisiz ' + v.status + ' ' + v.text);
  return v.json;
}

// ---------- Semadan ornek govde uretici (yalnizca zorunlu alanlar) ----------
let seq = 0;
function sample(schema, name) {
  schema = deref(schema);
  const t = [].concat(schema.type || (schema.properties ? 'object' : 'string')).filter((x) => x !== 'null')[0];
  if (schema.enum) return schema.enum[0];
  if (t === 'object') {
    const o = {};
    for (const r of schema.required || []) o[r] = sample(schema.properties[r], r);
    return o;
  }
  if (t === 'array') return [];
  if (t === 'integer' || t === 'number') return schema.minimum || 1;
  if (t === 'boolean') return true;
  if (schema.format === 'date-time') {
    const h = name === 'endsAt' ? 49 : 24; // baslangic yarin, bitis +25 saat sonra
    return new Date(Date.now() + h * 3600e3).toISOString();
  }
  if (schema.format === 'email') return 'ornek@bingol.edu.tr';
  const n = Math.max(schema.minLength || 0, 8);
  return ('Sozlesme ' + name + ' ' + Date.now() + ' ' + 'x'.repeat(n)).slice(0, Math.min(schema.maxLength || 60, 60));
}
function bodyOf(method, p) {
  const op = SPEC.paths[p][method];
  return sample(op.requestBody.content['application/json'].schema, 'body');
}
async function post(p, token, body, tpl) {
  const r = await call('POST', p, { token, body: body === undefined ? bodyOf('post', p) : body });
  checkBody('POST ' + (tpl || p), 'POST', tpl || p, r);
  return r;
}

// ---------- Yol parametresi ornekleri ----------
function firstId(json) {
  const list = Array.isArray(json) ? json : json && (json.items || json.content || json.data);
  const x = Array.isArray(list) ? list[0] : undefined;
  return x && (x.id ?? x.type ?? x.token);
}

(async () => {
  // 1) Surum kaymasi
  if (process.env.DRIFT !== '0') {
    const live = await call('GET', '/v3/api-docs', { basic: true });
    if (live.status !== 200) fail('canli /v3/api-docs ' + live.status);
    else {
      const sortKeys = (v) => Array.isArray(v) ? v.map(sortKeys) : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys(v[k])])) : v;
      const a = JSON.stringify(sortKeys({ ...live.json, servers: null }));
      const b = JSON.stringify(sortKeys({ ...SPEC, servers: null }));
      if (a !== b) fail('docs/openapi.json canli belgeden farkli; yenileyin: node scripts/openapi-gen.js');
    }
  }

  // 2) Yetkisiz erisim: Swagger/belge uclari ADMIN'e kapali olmali
  for (const u of ['/v3/api-docs', '/swagger-ui.html']) {
    const r = await call('GET', u);
    if (r.status !== 401 && r.status !== 403) fail(`${u} kimliksiz erisimde ${r.status} dondu (401/403 beklenir)`);
  }
  const ui = await call('GET', '/swagger-ui.html', { basic: true });
  if (ui.status === 200 && process.env.EXPECT_UI !== '1') fail('Swagger arayuzu acik (uretimde kapali olmali; dev icin EXPECT_UI=1)');

  // 3) Kimlik akisi
  const u = await ensureUser(USER_EMAIL, 'Sozlesme Kullanici');
  const a = await ensureUser(ADMIN_EMAIL, 'Sozlesme Yonetici');
  if (u && u.refreshToken) {
    const rf = await call('POST', '/api/auth/refresh', { body: { refreshToken: u.refreshToken } });
    checkBody('refresh', 'POST', '/api/auth/refresh', rf);
    if (rf.status === 200) u.accessToken = rf.json.accessToken, u.refreshToken = rf.json.refreshToken;
    const again = await call('POST', '/api/auth/refresh', { body: { refreshToken: u.refreshToken ? 'gecersiz' : 'x' } });
    if (again.status !== 401) fail('gecersiz refresh 401 donmedi: ' + again.status);
    else checkBody('refresh-invalid', 'POST', '/api/auth/refresh', again);
  }
  const bad = await call('POST', '/api/auth/login', { body: { email: USER_EMAIL, password: 'yanlis' } });
  checkBody('login-bad', 'POST', '/api/auth/login', bad);
  const val = await call('POST', '/api/auth/login', { body: { email: 'x' } });
  checkBody('login-validation', 'POST', '/api/auth/login', val);
  if (val.status !== 400) fail('gecersiz giris govdesi 400 donmedi: ' + val.status);

  const ids = {};
  // 3b) Tohum veri: yoksa olustur (bildirilen tum POST govdeleri de belgeyle dogrulanir)
  const meU = await call('GET', '/api/users/me', { token: u.accessToken });
  const meA = await call('GET', '/api/users/me', { token: a.accessToken });
  ids.adminUser = meA.json && meA.json.id;
  const mine = await call('GET', '/api/me/communities', { token: u.accessToken });
  if (FORCE_SEED || !firstId(mine.json)) {
    const c = await post('/api/communities', u.accessToken);
    if (c.status < 300) await post('/api/admin/communities/' + (c.json.id) + '/approve', a.accessToken, {}, '/api/admin/communities/{id}/approve');
  }
  const ev = await call('GET', '/api/me/events', { token: u.accessToken });
  if (FORCE_SEED || !firstId(ev.json)) {
    const e = await post('/api/events', u.accessToken);
    if (e.status < 300) await post('/api/admin/events/' + e.json.id + '/approve', a.accessToken, {}, '/api/admin/events/{id}/approve');
  }
  const tk = await call('GET', '/api/support/tickets', { token: u.accessToken });
  if (FORCE_SEED || !firstId(tk.json)) await post('/api/support/tickets', u.accessToken);
  const fb = await call('GET', '/api/feedback/mine', { token: u.accessToken });
  if (FORCE_SEED || !firstId(fb.json)) await post('/api/feedback', u.accessToken);
  const cv = await call('GET', '/api/conversations', { token: u.accessToken });
  if ((FORCE_SEED || !firstId(cv.json)) && ids.adminUser) {
    const c = await post('/api/conversations', u.accessToken, { userId: ids.adminUser }, undefined);
    if (c.status < 300) await post('/api/conversations/' + c.json.id + '/messages', u.accessToken, { clientId: 'contract-' + Date.now(), text: 'merhaba' }, '/api/conversations/{id}/messages');
  }

  // 4) Parametresiz GET uclari
  const tok = { user: u.accessToken, admin: a.accessToken };
  const sampleQuery = { q: 'bingol', type: 'NEWS', size: '5', limit: '5', lang: 'tr', from: null };
  const paths = Object.keys(SPEC.paths).sort();
  const todo = [];
  for (const p of paths) if (SPEC.paths[p].get) todo.push(p);
  // listeleri once cagir ki id'ler toplanabilsin
  todo.sort((x, y) => x.includes('{') - y.includes('{'));
  const skipped = [];
  for (const p of todo) {
    const op = SPEC.paths[p].get;
    let url = p;
    const pathParams = (op.parameters || []).filter((x) => x.in === 'path').map((x) => x.name);
    if (pathParams.length) {
      const byPrefix = [
        ['/api/news/', ids.news], ['/api/communities/', ids.communities], ['/api/events/', ids.events],
        ['/api/users/', ids.adminUser], ['/api/legal/', ids.legal], ['/api/conversations/', ids.conversations],
        ['/api/support/tickets/', ids.ticket], ['/api/admin/support/tickets/', ids.ticket],
        ['/api/admin/users/', ids.me], ['/api/admin/legal/', ids.legal],
        ['/api/admin/push/campaigns/', ids.campaign],
      ];
      const hit = byPrefix.find(([pre]) => p.startsWith(pre));
      const m = hit && hit[1];
      if (m === undefined || m === null) { skipped.push(p); continue; }
      url = p.replace(/\{[^}]+\}/, encodeURIComponent(m));
    }
    const qs = [];
    for (const q of (op.parameters || []).filter((x) => x.in === 'query' && x.required)) {
      const val = sampleQuery[q.name] ?? (q.schema && q.schema.enum ? q.schema.enum[0] : q.schema && q.schema.type === 'integer' ? '1' : 'bingol');
      if (val !== null) qs.push(`${q.name}=${encodeURIComponent(val)}`);
    }
    if (qs.length) url += '?' + qs.join('&');
    const isAdmin = p.startsWith('/api/admin/');
    const isPublic = Array.isArray(op.security) && op.security.length === 0;
    const r = await call('GET', url, { token: isPublic ? undefined : isAdmin ? tok.admin : tok.user });
    checkBody('GET ' + p, 'GET', p, r);
    if (r.status >= 500) fail(`GET ${p}: sunucu hatasi ${r.status}`);
    if (r.status === 404 && !pathParams.length) fail(`GET ${p}: belgelenmis ama sunucuda yok (404)`);
    if (r.status === 200 && r.json) {
      if (p === '/api/news') ids.news = firstId(r.json);
      if (p === '/api/communities') ids.communities = firstId(r.json);
      if (p === '/api/events') ids.events = firstId(r.json);
      if (p === '/api/legal') ids.legal = firstId(r.json);
      if (p === '/api/conversations') ids.conversations = firstId(r.json);
      if (p === '/api/support/tickets') ids.ticket = firstId(r.json);
      if (p === '/api/admin/push/campaigns') ids.campaign = firstId(r.json);
      if (p === '/api/users/me') ids.me = r.json.id;
    }
  }

  // 4b) Dosya yukleme sozlesmesi: belge multipart/form-data demeli ve gercek yukleme calismali
  for (const [p, item] of Object.entries(SPEC.paths)) {
    const op = item.post;
    if (op && /\/(avatar|cover|upload)$/.test(p)) {
      const ct = Object.keys((op.requestBody || {}).content || {});
      if (!ct.includes('multipart/form-data')) fail('POST ' + p + ': multipart/form-data bekleniyor, belgede ' + ct.join(','));
    }
  }
  {
    // 1x1 PNG
    const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
    const fd = new FormData();
    fd.append('file', new Blob([png], { type: 'image/png' }), 'a.png');
    const res = await fetch(BASE + '/api/users/me/avatar', { method: 'POST', headers: { Authorization: 'Bearer ' + tok.user }, body: fd });
    const txt = await res.text();
    checkBody('POST /api/users/me/avatar', 'POST', '/api/users/me/avatar', { status: res.status, json: txt ? JSON.parse(txt) : undefined, text: txt, type: 'application/json' });
    if (res.status === 200) {
      const url = JSON.parse(txt).avatarUrl;
      const img = await fetch(BASE + url);
      if (img.status !== 200 || !(img.headers.get('content-type') || '').startsWith('image/')) fail('yuklenen avatar indirilemedi: ' + url + ' ' + img.status);
    } else if (res.status !== 429) fail('avatar yukleme ' + res.status + ' ' + txt.slice(0, 100));
    const bad = new FormData();
    bad.append('file', new Blob(['not an image'], { type: 'text/plain' }), 'a.txt');
    const rb = await fetch(BASE + '/api/users/me/avatar', { method: 'POST', headers: { Authorization: 'Bearer ' + tok.user }, body: bad });
    const jb = await rb.json().catch(() => ({}));
    if (rb.status !== 400 || jb.code !== 'INVALID_FILE') fail('gecersiz dosya INVALID_FILE(400) donmedi: ' + rb.status + ' ' + JSON.stringify(jb));
  }

  // 5) Yetki: kullanici tokeni ile admin ucu 403, kimliksiz kimlikli uc 401
  const fa = await call('GET', '/api/admin/me', { token: tok.user });
  if (fa.status !== 403) fail('normal kullanici /api/admin/me -> ' + fa.status + ' (403 beklenir)');
  const na = await call('GET', '/api/users/me');
  if (na.status !== 401 && na.status !== 403) fail('kimliksiz /api/users/me -> ' + na.status);

  // ---------- Rapor ----------
  console.log(`openapi-check: ${checked} yanit dogrulandi; atlanan (ornek id yok): ${skipped.length ? skipped.join(', ') : '-'}`);
  warnings.slice(0, 15).forEach((w) => console.log('  uyari: ' + w));
  if (warnings.length > 15) console.log(`  ... ${warnings.length - 15} uyari daha`);
  if (failures.length) {
    console.log(`BASARISIZ: ${failures.length} uyumsuzluk`);
    failures.forEach((f) => console.log('  - ' + f));
    process.exit(1);
  }
  console.log('TAMAM: belge ile gercek yanitlar uyumlu');
})().catch((e) => {
  console.error('openapi-check hata:', e.message);
  process.exit(2);
});
