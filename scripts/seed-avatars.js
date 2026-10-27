#!/usr/bin/env node
// Yerel gelistirme: avatari olmayan tum kullanicilara ve gruplara uretilmis profil fotografi atar.
// Kullanim (repo kokunden, compose yigini calisirken): node scripts/seed-avatars.js [--force]
//   --force: mevcut avatarlari da yeniden uretir. Yalnizca yerel/demo verisi icindir, uretimde calistirmayin.
// Dosyalar backend konteynerinin /data/uploads/avatars klasorune kopyalanir, URL'ler veritabanina yazilir.
const { execSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const zlib = require('node:zlib');

const FORCE = process.argv.includes('--force');
const SIZE = 256;

const sh = (cmd, input) => execSync(cmd, { encoding: 'utf8', input, maxBuffer: 1 << 26 });
const psql = (sql) => sh('docker compose exec -T postgres psql -U bingol -d bingol -At -F "|" -q', sql);

// ---- PNG kodlayici (harici kutuphane yok) ----
const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function encodePng(rgb, w, h) {
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 3 + 1)] = 0;
    rgb.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// ---- Cizim ----
const PALETTE = [
  [[198, 40, 40], [236, 110, 90]], // kirmizi
  [[21, 101, 192], [100, 170, 235]], // mavi
  [[46, 125, 50], [126, 200, 110]], // yesil
  [[106, 27, 154], [180, 120, 220]], // mor
  [[239, 108, 0], [255, 184, 77]], // turuncu
  [[0, 131, 143], [90, 205, 215]], // turkuaz
  [[173, 20, 87], [240, 120, 170]], // pembe
  [[69, 90, 100], [150, 180, 195]], // gri-mavi
  [[121, 85, 72], [200, 160, 135]], // kahve
  [[40, 53, 147], [120, 140, 230]], // lacivert
];
const SKIN = [[255, 224, 196], [241, 194, 160], [224, 172, 130], [198, 134, 94], [141, 85, 54]];

const mix = (a, b, t) => a.map((v, i) => Math.round(v + (b[i] - v) * t));
const smooth = (d, edge) => Math.max(0, Math.min(1, 0.5 - d / edge)); // 1 ic, 0 dis, ~1px yumusak kenar

function drawAvatar(seed, kind) {
  const rnd = crypto.createHash('sha256').update(`${kind}:${seed}`).digest();
  const [c1, c2] = PALETTE[rnd[0] % PALETTE.length];
  const skin = SKIN[rnd[1] % SKIN.length];
  const shirt = mix(c1, [255, 255, 255], 0.15 + (rnd[2] % 40) / 100);
  const buf = Buffer.alloc(SIZE * SIZE * 3);
  const put = (x, y, col, a) => {
    if (a <= 0) return;
    const i = (y * SIZE + x) * 3;
    for (let k = 0; k < 3; k++) buf[i + k] = Math.round(buf[i + k] * (1 - a) + col[k] * a);
  };
  // Arka plan: capraz gradyan + hafif isik
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const t = (x + y) / (2 * SIZE);
      const bg = mix(c1, c2, t);
      const glow = Math.max(0, 1 - Math.hypot(x - SIZE * 0.3, y - SIZE * 0.25) / (SIZE * 0.7)) * 0.18;
      const i = (y * SIZE + x) * 3;
      for (let k = 0; k < 3; k++) buf[i + k] = Math.min(255, Math.round(bg[k] + 255 * glow));
    }
  }
  const circle = (cx, cy, r, col) => {
    for (let y = Math.max(0, Math.floor(cy - r - 2)); y < Math.min(SIZE, Math.ceil(cy + r + 2)); y++)
      for (let x = Math.max(0, Math.floor(cx - r - 2)); x < Math.min(SIZE, Math.ceil(cx + r + 2)); x++)
        put(x, y, col, smooth(Math.hypot(x + 0.5 - cx, y + 0.5 - cy) - r, 1.6));
  };
  const ellipse = (cx, cy, rx, ry, col) => {
    for (let y = Math.max(0, Math.floor(cy - ry - 2)); y < Math.min(SIZE, Math.ceil(cy + ry + 2)); y++)
      for (let x = Math.max(0, Math.floor(cx - rx - 2)); x < Math.min(SIZE, Math.ceil(cx + rx + 2)); x++) {
        const d = Math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry) - 1;
        put(x, y, col, smooth(d * Math.min(rx, ry), 1.6));
      }
  };
  if (kind === 'user') {
    ellipse(SIZE / 2, SIZE + 28, 100, 104, shirt); // omuzlar
    ellipse(SIZE / 2, 176, 22, 28, mix(skin, [0, 0, 0], 0.1)); // boyun
    const hair = [[40, 30, 25], [90, 60, 40], [20, 20, 22], [150, 100, 55], [185, 140, 80]][rnd[3] % 5];
    ellipse(SIZE / 2, 100, 56, 62, hair); // sac
    ellipse(SIZE / 2, 112, 46, 54, skin); // yuz
  } else {
    // Grup: uc kisilik silueti
    const people = [
      [SIZE * 0.30, SIZE * 0.52, 30, mix(c1, [255, 255, 255], 0.25)],
      [SIZE * 0.70, SIZE * 0.52, 30, mix(c2, [255, 255, 255], 0.1)],
      [SIZE * 0.50, SIZE * 0.44, 38, [255, 255, 255]],
    ];
    for (const [cx, cy, r, col] of people) {
      ellipse(cx, cy + r * 2.4, r * 1.7, r * 1.9, mix(col, [0, 0, 0], 0.03));
      circle(cx, cy, r, col);
    }
  }
  return encodePng(buf, SIZE, SIZE);
}

// ---- Calistir ----
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'bu-avatars-'));
const updates = [];
try {
  const where = FORCE ? 'true' : 'avatar_url is null';
  const users = psql(`select id from app_user where ${where} order by id;`).trim().split('\n').filter(Boolean);
  const groups = psql(`select id from conversation where type = 'GROUP' and ${where} order by id;`).trim().split('\n').filter(Boolean);
  console.log(`kullanici: ${users.length}, grup: ${groups.length}`);

  const add = (table, id, kind) => {
    const name = crypto.createHash('sha1').update(`seed-${kind}-${id}`).digest('hex') + '.png';
    fs.writeFileSync(path.join(tmp, name), drawAvatar(id, kind));
    updates.push(`update ${table} set avatar_url = '/files/avatars/${name}' where id = ${Number(id)};`);
  };
  users.forEach((id) => add('app_user', id, 'user'));
  groups.forEach((id) => add('conversation', id, 'group'));

  if (updates.length) {
    sh(`docker compose cp "${tmp}/." backend:/data/uploads/avatars/`);
    psql(`begin;\n${updates.join('\n')}\ncommit;`);
  }
  console.log(`tamam: ${updates.length} avatar atandi`);
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
