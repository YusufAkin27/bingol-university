#!/usr/bin/env node
// media-attacks.sh icin saldiri/test dosyalari uretir. Kullanim: node scripts/media-fixtures.js <cikti-dizini>
// Yalniz node cekirdek modulleri (zlib/crypto/fs); ASCII.
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const crypto = require('crypto');

const out = process.argv[2];
if (!out) { console.error('cikti dizini gerekli'); process.exit(1); }
fs.mkdirSync(out, { recursive: true });

const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
const SIG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
// colorType 0 = gri (1 bayt/piksel), 2 = RGB
function png(w, h, colorType, rawFn) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = colorType;
  const bpp = colorType === 2 ? 3 : 1;
  const rows = [];
  for (let y = 0; y < h; y++) rows.push(Buffer.concat([Buffer.from([0]), rawFn(y, w * bpp)]));
  const idat = zlib.deflateSync(Buffer.concat(rows), { level: 9 });
  return Buffer.concat([SIG, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))]);
}
const w = (name, data) => fs.writeFileSync(path.join(out, name), data);

// 1) her calistirmada FARKLI icerik (icerik ozetli adlandirma yuzunden paylasimli dosya olmasin)
function unique(tag) {
  const seed = crypto.randomBytes(3);
  w('unique-' + tag + '.png', png(48, 48, 2, (y, n) => {
    const r = Buffer.alloc(n);
    for (let i = 0; i < n; i++) r[i] = (seed[i % 3] + y * 3 + i) & 0xff;
    return r;
  }));
}
unique('a'); unique('b'); unique('c');

// 2) sikistirmasi zor gurultu (600x600 RGB ~1 MB) -> avatar 150 KB siniri icin kalite dusurulmeli
w('noise.png', png(600, 600, 2, (y, n) => crypto.randomBytes(n)));

// 3) piksel bombasi: 20000x20000 gri ilan eden kucuk PNG (400 MP); gercek veri bos
const bombHdr = Buffer.alloc(13);
bombHdr.writeUInt32BE(20000, 0); bombHdr.writeUInt32BE(20000, 4); bombHdr[8] = 8; bombHdr[9] = 0;
w('bomb.png', Buffer.concat([SIG, chunk('IHDR', bombHdr), chunk('IDAT', zlib.deflateSync(Buffer.alloc(64))),
  chunk('IEND', Buffer.alloc(0))]));

// 4) 6000x6000 gri (36 MP > 25 MP), gercekten kodlu ama cok sikisir
w('bigdim.png', png(6000, 6000, 0, (y, n) => Buffer.alloc(n, 128)));

// 5) bozuk PNG: gecerli imza + cop
w('corrupt.png', Buffer.concat([SIG, crypto.randomBytes(3000)]));

// 6) metin tabanli saldirilar
w('evil.svg', '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(document.cookie)</script></svg>');
w('evil.html', '<html><body><script>alert(1)</script></body></html>');
w('polyglot.gif', 'GIF89a/*<script>alert(1)</script>*/=1;');
// PNG sonuna eklenmis betik (gecerli PNG + artik veri): yeniden kodlamayla atilmali
w('png-trailing.png', Buffer.concat([fs.readFileSync(path.join(out, 'unique-c.png')),
  Buffer.from('<script>alert(1)</script><?php system($_GET[0]); ?>')]));

// 7) sihirli bayti dogru ama 3 MB'tan buyuk (avatar siniri 2 MB)
w('huge.png', Buffer.concat([SIG, Buffer.alloc(3 * 1024 * 1024)]));
w('empty.png', Buffer.alloc(0));
console.log('tamam: ' + out);
