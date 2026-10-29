#!/usr/bin/env node
// Yuk testi hazirligi: veritabanindan test verisi (kullanici/sohbet/etkinlik/anket kimlikleri) ve ayni JWT_SECRET ile
// uretilmis access token'lari (kayit/giris hiz siniri ve bcrypt maliyeti olcumu bozmasin) yazar.
// Cikti: <OUT>/fixtures.json, <OUT>/tokens.json (k6 betikleri /load/fixtures altindan okur).
// Ortam: JWT_SECRET (zorunlu; sunucudakiyle ayni), OUT (varsayilan scripts/perf/load/.fixtures),
//        PSQL_CMD (varsayilan: "docker exec -i bu_ld_pg psql -U bingol -d bingol"; VPS'te kendi komutunuz)
// Uyari: tokenlar sunucu sirriyla imzalanir; YALNIZ test yigininda calistirin.
'use strict';
const { execSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const SECRET = process.env.JWT_SECRET;
if (!SECRET || SECRET.length < 32) { console.error('JWT_SECRET (>=32 karakter) gerekli'); process.exit(2); }
const OUT = process.env.OUT || path.join(__dirname, '.fixtures');
const PSQL = process.env.PSQL_CMD || 'docker exec -i bu_ld_pg psql -U bingol -d bingol';
const TTL_S = Number(process.env.TOKEN_TTL_S || 3 * 3600);

function q(sql) {
  const out = execSync(`${PSQL} -AtF "|" -c "${sql.replace(/"/g, '\\"').replace(/\n/g, ' ')}"`, { encoding: 'utf8', maxBuffer: 512 * 1024 * 1024 });
  return out.split('\n').filter(Boolean).map((l) => l.split('|'));
}
function forge(id, email, role, extra) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const nowMs = Date.now();
  const iat = Math.floor(nowMs / 1000) - 5;
  const head = b64({ alg: 'HS256' });
  // cl=web: mobil token'lar tek-oturum kuralina tabidir; A senaryosundaki mobil girisler ayni kullanicilarin forge token'larini gecersiz kilar
  const body = b64({ sub: String(id), email, role, cl: 'web', iatms: nowMs - 5000, iat, exp: iat + TTL_S, ...extra });
  const sig = crypto.createHmac('sha256', Buffer.from(SECRET, 'utf8')).update(head + '.' + body).digest('base64url');
  return head + '.' + body + '.' + sig;
}

fs.mkdirSync(OUT, { recursive: true });
const users = q("SELECT id, email FROM app_user WHERE email LIKE 'seed%@bingol.edu.tr' ORDER BY id");
const idx = new Map(users.map((u, i) => [Number(u[0]), i]));
const tokens = users.map((u) => forge(u[0], u[1], 'USER'));
const admin = q("SELECT id, email FROM app_user WHERE email = 'ld.admin@bingol.edu.tr'")[0];
if (!admin) { console.error('ld.admin@bingol.edu.tr yok: seed-load-extra.sql calistirilmamis'); process.exit(2); }

// DIRECT sohbet ornekleri: [konusmaId, kullaniciIdxA, kullaniciIdxB]; iki taraf da seed kullanicisi
const pairsRaw = q(`SELECT c.id, split_part(c.direct_key, ':', 1), split_part(c.direct_key, ':', 2) FROM conversation c
  WHERE c.direct_key IS NOT NULL AND c.created_by IN (SELECT id FROM app_user WHERE email LIKE 'seed%@bingol.edu.tr')
  ORDER BY c.id`);
// Her kullanici en cok bir ciftte (WebSocket testinde ayni kullanici birden fazla baglanti kurmasin); 6000 cift
const usedU = new Set();
const pairs = [];
for (const r of pairsRaw) {
  const a = idx.get(Number(r[1]));
  const b = idx.get(Number(r[2]));
  if (a === undefined || b === undefined || usedU.has(a) || usedU.has(b)) continue;
  usedU.add(a); usedU.add(b);
  pairs.push([Number(r[0]), a, b]);
  if (pairs.length >= 6000) break;
}

const col = (sql) => q(sql).map((r) => Number(r[0]));
const fx = {
  userCount: users.length,
  userIds: users.map((u) => Number(u[0])),
  adminId: Number(admin[0]),
  adminToken: forge(admin[0], admin[1], 'ADMIN', { ap: 'FULL' }),
  pairs,
  postRange: q("SELECT min(id), max(id) FROM post WHERE body LIKE 'ldx %'")[0].map(Number),
  eventIds: col("SELECT id FROM user_event WHERE title LIKE 'ldx Etkinlik %' ORDER BY id"),
  raceEventId: col("SELECT id FROM user_event WHERE title = 'ldx Kapasite Yarisi'")[0],
  pollIds: col("SELECT id FROM poll WHERE title LIKE 'ldx Anket %' ORDER BY id"),
  communityIds: col("SELECT id FROM community WHERE slug LIKE 'ldx-%' ORDER BY id"),
  raceUserFrom: 999, // seed n=1000..1099 -> idx 999..1098 (kapasite yarisi kullanicilari; dolu koltuklar n=2000..2089)
  generatedAt: new Date().toISOString(),
};
fs.writeFileSync(path.join(OUT, 'tokens.json'), JSON.stringify(tokens));
fs.writeFileSync(path.join(OUT, 'fixtures.json'), JSON.stringify(fx));
console.log(`fixtures: users=${users.length} pairs=${pairs.length} events=${fx.eventIds.length} polls=${fx.pollIds.length} ` +
  `communities=${fx.communityIds.length} raceEvent=${fx.raceEventId} -> ${OUT}`);
