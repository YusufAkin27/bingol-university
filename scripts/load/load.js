#!/usr/bin/env node
// REST sicak yol yuk testi (harici arac yok; Node 22+ yerlesik fetch/undici).
// Onkosul: `scripts/load/seed.sh` ile veri tohumlanmis, compose yigini calisiyor.
// Kullanim (repo kokunden):
//   COMPOSE_PROJECT_NAME=wt_t6 BASE=http://localhost:8106 node scripts/load/load.js [senaryo,...]
// Senaryolar: news_list, news_search, search, notifications, conversations, messages, admin_users, admin_users_q,
//   admin_overview, admin_engagement, admin_news, login, mixed (varsayilan: hepsi). ADMIN kullanici yoksa
//   (ADMIN_EMAILS listesindeki e-posta ile make-user.sh) admin_* senaryolari 401 doner.
// Ortam: CONC=32 (esanli istek), DURATION=15 (sn), WARMUP=3 (sn), JWT_SECRET, LABEL=etiket (sonuc dosyasi adi),
//        FLUSH_RL=1 (login senaryosunda Redis rl:* anahtarlarini periyodik siler; yoksa 429'lar olculur).
// Cikti: stdout'ta markdown tablo, scripts/load/results/<LABEL>.json
'use strict';
const { execFileSync, spawn } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const BASE = process.env.BASE || 'http://localhost:8106';
const SECRET = process.env.JWT_SECRET || 'test-secret-test-secret-test-secret-9999';
const CONC = Number(process.env.CONC || 32);
const DURATION = Number(process.env.DURATION || 15) * 1000;
const WARMUP = Number(process.env.WARMUP || 3) * 1000;
const LABEL = process.env.LABEL || 'run';
const FLUSH_RL = process.env.FLUSH_RL === '1';

// ---------- yardimcilar ----------
function psql(sql) {
  return execFileSync('docker', ['compose', 'exec', '-T', 'postgres', 'psql', '-U', 'bingol', '-d', 'bingol', '-AtF', ',', '-c', sql],
    { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 }).trim().split('\n').filter(Boolean);
}
function forgeJwt(userId, role = 'USER') {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'HS256' });
  const body = b64({ sub: String(userId), role, iat: now - 5, exp: now + 3600 });
  const sig = crypto.createHmac('sha256', Buffer.from(SECRET, 'utf8')).update(head + '.' + body).digest('base64url');
  return head + '.' + body + '.' + sig;
}
const rnd = (n) => Math.floor(Math.random() * n);
const pick = (a) => a[rnd(a.length)];
const WORDS = ['universite', 'ogrenci', 'sinav', 'burs', 'yemek', 'kampus', 'kutuphane', 'etkinlik', 'konferans', 'mezuniyet',
  'kayit', 'akademik', 'takvim', 'duyuru', 'fakulte', 'proje', 'staj', 'erasmus', 'seminer', 'laboratuvar'];

// ---------- test verisi (DB'den) ----------
function loadFixtures() {
  const users = psql(`SELECT id FROM app_user WHERE email LIKE 'demoperf.%' ORDER BY id LIMIT 15000`).map(Number);
  // (kullanici, konusma) ciftleri: %70 rastgele, %30 sicak (en cok mesajli konusmalar)
  const rand = psql(`SELECT cm.user_id, cm.conversation_id FROM conversation_member cm
                     WHERE cm.user_id IN (SELECT id FROM app_user WHERE email LIKE 'demoperf.%') ORDER BY random() LIMIT 3000`);
  const hot = psql(`SELECT cm.user_id, cm.conversation_id FROM conversation_member cm
                    WHERE cm.conversation_id IN (SELECT conversation_id FROM message GROUP BY conversation_id ORDER BY count(*) DESC LIMIT 100)
                    AND cm.user_id IN (SELECT id FROM app_user WHERE email LIKE 'demoperf.%')`);
  const emails = psql(`SELECT id, email FROM app_user WHERE email LIKE 'demoperf.%' ORDER BY id LIMIT 5000`).map((l) => l.split(','));
  const pairs = [...rand, ...hot, ...hot].map((l) => l.split(',').map(Number));
  const adminId = Number(psql(`SELECT id FROM app_user WHERE role = 'ADMIN' ORDER BY id LIMIT 1`)[0] || 0);
  return { users, pairs, emails, adminId };
}

// ---------- senaryolar: () => {url, headers?, method?, body?} ----------
function scenarios(fx) {
  const auth = (id) => ({ Authorization: 'Bearer ' + forgeJwt(id) });
  const tokens = new Map();
  const tok = (id) => { let t = tokens.get(id); if (!t) { t = auth(id); tokens.set(id, t); } return t; };
  const types = ['HABER', 'DUYURU', 'ETKINLIK'];
  const admin = { Authorization: 'Bearer ' + forgeJwt(Number(process.env.ADMIN_ID || 0) || fx.adminId, 'ADMIN') };
  return {
    news_list: () => ({ url: `/api/news?type=${pick(types)}&page=${rnd(30)}&size=20` }),
    news_search: () => ({ url: `/api/news?q=${pick(WORDS)}%20${pick(WORDS)}&page=0&size=20` }),
    search: () => ({ url: `/api/search?q=${pick(WORDS)}&limit=5`, headers: tok(pick(fx.users)) }),
    notifications: () => ({ url: '/api/notifications?size=20', headers: tok(pick(fx.users)) }),
    conversations: () => ({ url: '/api/conversations?size=20', headers: tok(pick(fx.users)) }),
    messages: () => {
      const [u, c] = pick(fx.pairs);
      return { url: `/api/conversations/${c}/messages?size=30`, headers: tok(u) };
    },
    // Yonetim paneli (JWT ADMIN; Basic auth her istekte bcrypt calistirdigi icin olcumu bozar)
    admin_users: () => ({ url: `/api/admin/users?page=${rnd(500)}&size=20&sort=createdAt,desc`, headers: admin }),
    admin_users_q: () => ({ url: `/api/admin/users?q=${pick(['Perf%20' + rnd(20000), 'demoperf.' + rnd(2000), 'Deniz', 'Zeynep%20Perf'])}&page=0&size=20`, headers: admin }),
    admin_overview: () => ({ url: '/api/admin/analytics/overview', headers: admin }),
    admin_engagement: () => ({ url: '/api/admin/analytics/engagement', headers: admin }),
    admin_news: () => ({ url: `/api/admin/news?q=${pick(WORDS)}&page=0&size=20`, headers: admin }),
    login: () => {
      const [, email] = pick(fx.emails);
      return { url: '/api/auth/login', method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password: 'Sifre1234' }) };
    },
  };
}
const MIX = { news_list: 25, notifications: 20, conversations: 20, messages: 20, search: 10, news_search: 5 };

// ---------- calistirici ----------
async function runScenario(name, gen) {
  const lat = [];
  const codes = {};
  let errors = 0;
  let measuring = false;
  const t0 = performance.now();
  const tMeasure = t0 + WARMUP;
  const tEnd = tMeasure + DURATION;
  async function worker() {
    while (performance.now() < tEnd) {
      const spec = gen();
      const s = performance.now();
      let code = 0;
      try {
        const res = await fetch(BASE + spec.url, { method: spec.method || 'GET', headers: spec.headers, body: spec.body,
          signal: AbortSignal.timeout(20000) });
        await res.arrayBuffer();
        code = res.status;
      } catch { code = -1; }
      const ms = performance.now() - s;
      if (s >= tMeasure) {
        measuring = true;
        codes[code] = (codes[code] || 0) + 1;
        if (code >= 200 && code < 300) lat.push(ms);
        else if (code >= 500 || code < 0) errors++;
      }
    }
  }
  await Promise.all(Array.from({ length: CONC }, worker));
  lat.sort((a, b) => a - b);
  const q = (p) => (lat.length ? lat[Math.min(lat.length - 1, Math.floor(p * lat.length))] : NaN);
  const total = Object.values(codes).reduce((a, b) => a + b, 0);
  const ok = lat.length;
  return {
    name, conc: CONC, total, ok, rps: +(total / (DURATION / 1000)).toFixed(1),
    p50: +q(0.5).toFixed(1), p95: +q(0.95).toFixed(1), p99: +q(0.99).toFixed(1), max: +(lat[lat.length - 1] || NaN).toFixed(1),
    errPct: total ? +((errors / total) * 100).toFixed(2) : 0,
    limited429: codes[429] || 0, codes,
  };
}

function startRlFlusher() {
  // Kalici bir redis-cli sureci: login/IP rate limit'i olcumu bozmasin diye rl:* anahtarlarini siler.
  const p = spawn('docker', ['compose', 'exec', '-T', 'redis', 'redis-cli'], { stdio: ['pipe', 'ignore', 'ignore'] });
  const t = setInterval(() => p.stdin.write(`EVAL "for _,k in ipairs(redis.call('keys','rl:*')) do redis.call('del',k) end" 0\n`), 200);
  return () => { clearInterval(t); p.stdin.end(); };
}

(async () => {
  const fx = loadFixtures();
  if (!fx.users.length) { console.error('demoperf verisi yok: once scripts/load/seed.sh'); process.exit(1); }
  const sc = scenarios(fx);
  const want = process.argv[2] ? process.argv[2].split(',') : [...Object.keys(sc), 'mixed'];
  const results = [];
  console.log(`# ${LABEL}: BASE=${BASE} CONC=${CONC} sure=${DURATION / 1000}s (+${WARMUP / 1000}s isinma)`);
  console.log('| senaryo | istek | rps | p50 ms | p95 ms | p99 ms | max ms | hata % | 429 |');
  console.log('|---|---|---|---|---|---|---|---|---|');
  for (const name of want) {
    let gen;
    if (name === 'mixed') {
      const bag = Object.entries(MIX).flatMap(([k, w]) => Array(w).fill(k));
      gen = () => sc[pick(bag)]();
    } else if (sc[name]) gen = sc[name]; else { console.error('bilinmeyen senaryo: ' + name); continue; }
    const stop = name === 'login' && FLUSH_RL ? startRlFlusher() : null;
    const r = await runScenario(name, gen);
    if (stop) stop();
    results.push(r);
    console.log(`| ${r.name} | ${r.total} | ${r.rps} | ${r.p50} | ${r.p95} | ${r.p99} | ${r.max} | ${r.errPct} | ${r.limited429} |`);
  }
  // Kabul olcutleri (thresholds.json): asilirsa cikis kodu 1 (CI/kapi icin)
  let th = {};
  try { th = JSON.parse(fs.readFileSync(path.join(__dirname, 'thresholds.json'), 'utf8')); } catch { /* yok */ }
  let bad = 0;
  for (const r of results) {
    const t = th[r.name];
    if (!t) continue;
    if (r.p95 > t.p95 || r.p99 > t.p99 || r.errPct > t.errPct) { bad++; console.log(`ESIK ASILDI: ${r.name} p95=${r.p95}/${t.p95} p99=${r.p99}/${t.p99} hata=${r.errPct}/${t.errPct}`); }
  }
  if (bad) process.exitCode = 1;
  fs.mkdirSync(path.join(__dirname, 'results'), { recursive: true });
  fs.writeFileSync(path.join(__dirname, 'results', LABEL + '.json'), JSON.stringify({ base: BASE, conc: CONC, results }, null, 2));
})();
