#!/usr/bin/env node
// Varsayilan profil/grup gorsellerini uretir (saf Node, harici paket yok).
// Kullanim: node tool/make_default_avatar.js  -> assets/branding/default_avatar.png, default_group.png
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

const SIZE = 256;
const BG = [199, 204, 214]; // #C7CCD6
const FG = [139, 147, 164]; // #8B93A4

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

// Bir kisi: kafa (daire) + omuz (elips). cx, bas merkezi y, olcek s, renk.
function person(cx, headY, s, col) {
  return [
    { cx, cy: headY, rx: 38 * s, ry: 38 * s, col },
    { cx, cy: headY + 112 * s, rx: 78 * s, ry: 70 * s, col },
  ];
}

function render(shapes) {
  const buf = Buffer.alloc(SIZE * SIZE * 3);
  const SS = 3;
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      let r = 0, g = 0, b = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const px = x + (sx + 0.5) / SS, py = y + (sy + 0.5) / SS;
          let col = BG;
          for (const s of shapes) {
            const dx = (px - s.cx) / s.rx, dy = (py - s.cy) / s.ry;
            if (dx * dx + dy * dy <= 1) col = s.col;
          }
          r += col[0]; g += col[1]; b += col[2];
        }
      }
      const i = (y * SIZE + x) * 3, n = SS * SS;
      buf[i] = Math.round(r / n); buf[i + 1] = Math.round(g / n); buf[i + 2] = Math.round(b / n);
    }
  }
  return encodePng(buf, SIZE, SIZE);
}

const out = path.join(__dirname, '..', 'assets', 'branding');
fs.writeFileSync(path.join(out, 'default_avatar.png'), render(person(128, 92, 1, FG)));
// Grup: arkada iki kucuk (daha acik ton), onde biri buyuk.
const SIDE = [160, 167, 182];
fs.writeFileSync(
  path.join(out, 'default_group.png'),
  render([...person(60, 104, 0.62, SIDE), ...person(196, 104, 0.62, SIDE), ...person(128, 88, 0.9, FG)]),
);
console.log('ok');
