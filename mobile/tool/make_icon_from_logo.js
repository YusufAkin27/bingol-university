// BU Kampus simgelerini kaynak logodan uretir (harici paket yok).
// Kullanim: node tool/make_icon_from_logo.js [kaynak_logo.png]   (mobile/ klasorunden)
// Kaynak: varsayilan assets/branding/logo.png (1254x1254, RGB, beyaz zemin + kirmizi yuvarlak kare + beyaz harfler).
// Cikti: assets/branding/{icon_1024,adaptive_foreground,adaptive_monochrome,mark,mark_white}.png
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const OUT = path.join(__dirname, '..', 'assets', 'branding');
const SRC = process.argv[2] || path.join(OUT, 'logo.png');

// ---- PNG cozucu (8 bit RGB/RGBA, interlace yok) ----
function decodePng(buf) {
  let p = 8, w = 0, h = 0, ct = 0; const idat = [];
  while (p < buf.length) {
    const len = buf.readUInt32BE(p), type = buf.toString('ascii', p + 4, p + 8);
    const data = buf.subarray(p + 8, p + 8 + len);
    if (type === 'IHDR') {
      w = data.readUInt32BE(0); h = data.readUInt32BE(4); ct = data[9];
      if (data[8] !== 8 || data[12] !== 0) throw new Error('8 bit, interlace yok olmali');
    } else if (type === 'IDAT') idat.push(data);
    p += 12 + len;
  }
  const bpp = ct === 2 ? 3 : ct === 6 ? 4 : 0;
  if (!bpp) throw new Error('yalnizca RGB/RGBA');
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = w * bpp, px = Buffer.alloc(stride * h);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], so = y * (stride + 1) + 1, o = y * stride;
    for (let i = 0; i < stride; i++) {
      const x = raw[so + i];
      const a = i >= bpp ? px[o + i - bpp] : 0;
      const b = y ? px[o - stride + i] : 0;
      const c = i >= bpp && y ? px[o - stride + i - bpp] : 0;
      let v;
      if (f === 0) v = x;
      else if (f === 1) v = x + a;
      else if (f === 2) v = x + b;
      else if (f === 3) v = x + ((a + b) >> 1);
      else {
        const pp = a + b - c, pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c);
        v = x + (pa <= pb && pa <= pc ? a : pb <= pc ? b : c);
      }
      px[o + i] = v & 255;
    }
  }
  return { w, h, bpp, px };
}

// ---- PNG kodlayici (RGBA) ----
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
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
  ]);
}

// ---- Lanczos3 yeniden orneklemesi (tek kanal, Float32) ----
function lanczos(x) {
  if (x === 0) return 1;
  if (Math.abs(x) >= 3) return 0;
  const t = Math.PI * x;
  return 3 * Math.sin(t) * Math.sin(t / 3) / (t * t);
}
function weights(dst, srcLen, dstLen) {
  const k = srcLen / dstLen, f = Math.max(1, k), c = (dst + 0.5) * k - 0.5;
  const ws = [], is = []; let sum = 0;
  for (let i = Math.floor(c - 3 * f); i <= Math.ceil(c + 3 * f); i++) {
    const w = lanczos((i - c) / f);
    if (w === 0) continue;
    ws.push(w); is.push(Math.min(srcLen - 1, Math.max(0, i))); sum += w;
  }
  return { ws: ws.map((w) => w / sum), is };
}
function resize(src, sw, sh, dw, dh) {
  const tmp = new Float32Array(dw * sh);
  for (let x = 0; x < dw; x++) {
    const { ws, is } = weights(x, sw, dw);
    for (let y = 0; y < sh; y++) { let a = 0; for (let j = 0; j < ws.length; j++) a += src[y * sw + is[j]] * ws[j]; tmp[y * dw + x] = a; }
  }
  const out = new Float32Array(dw * dh);
  for (let y = 0; y < dh; y++) {
    const { ws, is } = weights(y, sh, dh);
    for (let x = 0; x < dw; x++) { let a = 0; for (let j = 0; j < ws.length; j++) a += tmp[is[j] * dw + x] * ws[j]; out[y * dw + x] = a; }
  }
  return out;
}

// ---- Kaynagi analiz et ----
const img = decodePng(fs.readFileSync(SRC));
const W = img.w, H = img.h, B = img.bpp;
const at = (x, y, c) => img.px[(y * W + x) * B + c];
// Marka kirmizisi: yuvarlak karenin sol-orta ic bolgesinden ortalama (harflerden uzak).
let rs = 0, gs = 0, bs = 0, cnt = 0;
for (let y = 600; y < 680; y++) for (let x = 150; x < 200; x++) { rs += at(x, y, 0); gs += at(x, y, 1); bs += at(x, y, 2); cnt++; }
const RED = [rs / cnt, gs / cnt, bs / cnt];
console.log('kirmizi:', RED.map(Math.round), '#' + RED.map((v) => Math.round(v).toString(16).padStart(2, '0')).join('').toUpperCase());
// Beyazlik w (0 = kirmizi, 1 = beyaz): yesil+mavi kanallarindan.
const whiteness = (x, y) => {
  const g = (at(x, y, 1) - RED[1]) / (255 - RED[1]), b = (at(x, y, 2) - RED[2]) / (255 - RED[2]);
  return Math.min(1, Math.max(0, (g + b) / 2));
};
// Dis zemin: kenardan 4-bagli tasirma (w > 0.02). Dis pikselde alfa = 1 - w, ic = 1.
const outside = new Uint8Array(W * H), stack = [];
const push = (x, y) => {
  if (x < 0 || y < 0 || x >= W || y >= H) return;
  const i = y * W + x;
  if (outside[i] || whiteness(x, y) <= 0.02) return;
  outside[i] = 1; stack.push(i);
};
for (let x = 0; x < W; x++) { push(x, 0); push(x, H - 1); }
for (let y = 0; y < H; y++) { push(0, y); push(W - 1, y); }
while (stack.length) { const i = stack.pop(), x = i % W, y = (i / W) | 0; push(x + 1, y); push(x - 1, y); push(x, y + 1); push(x, y - 1); }
const tileA = new Float32Array(W * H), letter = new Float32Array(W * H);
let tx0 = W, ty0 = H, tx1 = 0, ty1 = 0;
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = y * W + x, w = whiteness(x, y);
  tileA[i] = outside[i] ? 1 - w : 1;
  letter[i] = outside[i] ? 0 : w;
  if (tileA[i] > 0.5) { tx0 = Math.min(tx0, x); ty0 = Math.min(ty0, y); tx1 = Math.max(tx1, x); ty1 = Math.max(ty1, y); }
}
// Harf sinirlayici kutusu (nokta/aksan dahil)
let lx0 = W, ly0 = H, lx1 = 0, ly1 = 0;
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  if (letter[y * W + x] > 0.5) { lx0 = Math.min(lx0, x); ly0 = Math.min(ly0, y); lx1 = Math.max(lx1, x); ly1 = Math.max(ly1, y); }
}
lx0 -= 2; ly0 -= 2; lx1 += 2; ly1 += 2;
const LW = lx1 - lx0 + 1, LH = ly1 - ly0 + 1;
console.log('karo:', tx0, ty0, tx1, ty1, ' harf:', lx0, ly0, lx1, ly1);
const crop = new Float32Array(LW * LH);
for (let y = 0; y < LH; y++) for (let x = 0; x < LW; x++) crop[y * LW + x] = letter[(ly0 + y) * W + lx0 + x];

// Harf katmani: size x size tuval, harf genisligi widthFrac*size, kutu ortali.
function letterLayer(size, widthFrac) {
  const dw = Math.round(size * widthFrac), dh = Math.round(dw * LH / LW);
  const s = resize(crop, LW, LH, dw, dh);
  const L = new Float32Array(size * size);
  const ox = Math.round((size - dw) / 2), oy = Math.round((size - dh) / 2);
  for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++) L[(oy + y) * size + ox + x] = Math.min(1, Math.max(0, s[y * dw + x]));
  return L;
}
function write(name, size, fn) {
  const buf = Buffer.alloc(size * size * 4);
  for (let i = 0; i < size * size; i++) {
    const [r, g, b, a] = fn(i);
    buf[i * 4] = Math.round(r); buf[i * 4 + 1] = Math.round(g); buf[i * 4 + 2] = Math.round(b); buf[i * 4 + 3] = Math.round(a * 255);
  }
  fs.writeFileSync(path.join(OUT, name), encodePng(size, size, buf));
  console.log('yazildi', name, size);
}
const mix = (l, a) => [RED[0] + (255 - RED[0]) * l, RED[1] + (255 - RED[1]) * l, RED[2] + (255 - RED[2]) * l, a];

const L1 = letterLayer(1024, 0.62);
write('icon_1024.png', 1024, (i) => mix(L1[i], 1));
const L2 = letterLayer(1024, 0.50);
write('adaptive_foreground.png', 1024, (i) => [255, 255, 255, L2[i]]);
write('adaptive_monochrome.png', 1024, (i) => [255, 255, 255, L2[i]]);
const L3 = letterLayer(1024, 0.90);
write('mark_white.png', 1024, (i) => [255, 255, 255, L3[i]]);

// mark.png: logonun kendi yuvarlak karesi (kare kirpma), 256'ya olcekli, dis zemin seffaf.
{
  const tw = tx1 - tx0 + 1, th = ty1 - ty0 + 1, side = Math.max(tw, th);
  const cx = tx0 + tw / 2, cy = ty0 + th / 2, sx0 = Math.round(cx - side / 2), sy0 = Math.round(cy - side / 2);
  const pick = (arr) => {
    const a = new Float32Array(side * side);
    for (let y = 0; y < side; y++) for (let x = 0; x < side; x++) {
      const X = sx0 + x, Y = sy0 + y;
      a[y * side + x] = X < 0 || Y < 0 || X >= W || Y >= H ? 0 : arr[Y * W + X];
    }
    return a;
  };
  const A = resize(pick(tileA), side, side, 256, 256);
  const Lt = resize(pick(letter), side, side, 256, 256);
  write('mark.png', 256, (i) => mix(Math.min(1, Math.max(0, Lt[i])), Math.min(1, Math.max(0, A[i]))));
}
