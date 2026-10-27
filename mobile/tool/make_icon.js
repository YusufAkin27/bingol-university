// BU Kampus uygulama simgesi uretici (harici paket yok).
// Kullanim: node tool/make_icon.js   (mobile/ klasorunden)
// Cikti: assets/branding/{icon_1024,adaptive_foreground,adaptive_monochrome,mark,mark_white}.png
// Tasarim: marka kirmizisi gradyan zemin uzerinde beyaz mezuniyet kepi (mortarboard).
// Sekiller imzali mesafe fonksiyonlariyla (SDF) cizilir; kenarlar analitik anti-aliasing'lidir.
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const OUT = path.join(__dirname, '..', 'assets', 'branding');

// ---- PNG kodlayici (RGBA, 8 bit) ----
function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function encodePng(w, h, rgba) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; // 8 bit, RGBA
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
  ]);
}

// ---- SDF ilkelleri (1024 tasarim uzayi) ----
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
function sdRhombus(px, py, bx, by) { // yari-kosegenler bx, by
  px = Math.abs(px); py = Math.abs(py);
  const nd = (ax, ay, cx, cy) => ax * cx - ay * cy;
  const h = clamp(nd(bx - 2 * px, by - 2 * py, bx, by) / (bx * bx + by * by), -1, 1);
  const d = Math.hypot(px - 0.5 * bx * (1 - h), py - 0.5 * by * (1 + h));
  return d * Math.sign(px * by + py * bx - bx * by);
}
function sdRoundRhombus(px, py, bx, by, r) {
  const inr = (bx * by) / Math.hypot(bx, by);
  const k = (inr - r) / inr;
  return sdRhombus(px, py, bx * k, by * k) - r;
}
function sdEllipse(px, py, rx, ry) { // yaklasik, kenar yakininda dogru
  const k0 = Math.hypot(px / rx, py / ry);
  const k1 = Math.hypot(px / (rx * rx), py / (ry * ry));
  return k1 === 0 ? -Math.min(rx, ry) : (k0 * (k0 - 1)) / k1;
}
function sdCapsule(px, py, ax, ay, bx, by, r) {
  const pax = px - ax, pay = py - ay, bax = bx - ax, bay = by - ay;
  const h = clamp((pax * bax + pay * bay) / (bax * bax + bay * bay), 0, 1);
  return Math.hypot(pax - bax * h, pay - bay * h) - r;
}

// Kep: tasarim merkezi (512,512) etrafinda; genislik ~640 (merkez %66 guvenli alan icinde).
const GAP = 26; // levha ile alt kasnak arasi bosluk
function capSdf(x, y) {
  const cx = 512, cy = 490;
  const px = x - cx, py = y - cy;
  // levha (eşkenar dörtgen, yuvarlatilmis kosegen uclari)
  const dia = sdRoundRhombus(px, py + 22, 320, 168, 22);
  // alt kasnak: elips, levhanin altina GAP kadar ofsetli, ust kismi kesilmis
  const ell = sdEllipse(px, py - 8, 188, 196);
  const clip = 34 - py; // py > 34
  const band = Math.max(ell, -(dia - GAP), clip);
  // puskul: sag uctan sarkan ince serit + uc dolgusu
  const tx = 276;
  const cord = sdCapsule(px, py, tx, -22, tx, 120, 12);
  const tuft = sdCapsule(px, py, tx, 112, tx, 170, 24);
  return Math.min(dia, band, cord, tuft);
}

// ---- Cizim ----
function render(size, fn) {
  const buf = Buffer.alloc(size * size * 4);
  for (let j = 0; j < size; j++) for (let i = 0; i < size; i++) {
    const c = fn((i + 0.5) / size * 1024, (j + 0.5) / size * 1024, size / 1024);
    const o = (j * size + i) * 4;
    buf[o] = c[0]; buf[o + 1] = c[1]; buf[o + 2] = c[2]; buf[o + 3] = c[3];
  }
  return buf;
}
const cov = (d, px) => clamp(0.5 - d * px, 0, 1); // d tasarim birimi, px = piksel/birim
const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const C1 = hex('#FF5A47'), C2 = hex('#E02D22');
function grad(x, y) { // capraz gradyan sol-ust -> sag-alt
  const t = clamp((x + y) / 2048, 0, 1);
  return [0, 1, 2].map((k) => C1[k] + (C2[k] - C1[k]) * t);
}
// olcek s: tasarimi merkezden buyutur (s>1 daha buyuk)
const scaled = (s) => (x, y) => capSdf(512 + (x - 512) / s, 512 + (y - 512) / s) * s;

// Beyaz isaret icin hafif "levha uzerinde golge" yok: duz, minimal.
function iconFull(size, s) {
  const f = scaled(s);
  return render(size, (x, y, px) => {
    const g = grad(x, y), a = cov(f(x, y), px);
    return [g[0] + (255 - g[0]) * a, g[1] + (255 - g[1]) * a, g[2] + (255 - g[2]) * a, 255].map(Math.round);
  });
}
function markOnly(size, s, color) {
  const f = scaled(s);
  return render(size, (x, y, px) => [color[0], color[1], color[2], Math.round(255 * cov(f(x, y), px))]);
}
function tile(size, s, radius) { // yuvarlak kose kirmizi karo + beyaz kep (mark.png)
  const f = scaled(s);
  return render(size, (x, y, px) => {
    const dx = Math.abs(x - 512) - (512 - radius), dy = Math.abs(y - 512) - (512 - radius);
    const dt = Math.hypot(Math.max(dx, 0), Math.max(dy, 0)) + Math.min(Math.max(dx, dy), 0) - radius;
    const t = cov(dt, px), g = grad(x, y), a = cov(f(x, y), px);
    return [0, 1, 2].map((k) => Math.round(g[k] + (255 - g[k]) * a)).concat(Math.round(255 * t));
  });
}

const write = (name, size, buf) => {
  fs.writeFileSync(path.join(OUT, name), encodePng(size, size, buf));
  console.log('yazildi', name, size + 'x' + size);
};

const WHITE = [255, 255, 255];
write('icon_1024.png', 1024, iconFull(1024, 1.18));
write('adaptive_foreground.png', 1024, markOnly(1024, 1.0, WHITE));
write('adaptive_monochrome.png', 1024, markOnly(1024, 1.0, WHITE));
write('mark.png', 256, tile(256, 1.12, 232));
// mark_white: kirmizi hero uzerinde beyaz; bos kenar payi az (BuMark yukseklik verir)
write('mark_white.png', 1024, markOnly(1024, 1.55, WHITE));
