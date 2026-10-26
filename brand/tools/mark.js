// Kaynak logo.png -> seffaf ana isaret (master) ve turevleri (mono maskeler).
// Tasarima dokunulmaz: yalnizca disardaki beyaz zeminden ayirma + kare kirpma + olcekleme.
const sharp = require('sharp');
const path = require('path');

const SRC = path.join(__dirname, '..', 'source', 'logo.png');
const MASTER = 1024;

async function loadSource() {
  const { data, info } = await sharp(SRC).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  return { data, w: info.width, h: info.height };
}

// Ic bolgedeki (kirmizi kare) renk: kanal medyani (kenar ve harflerden uzak, saf kirmizi pikseller)
function measureRed({ data, w, h }) {
  const hist = [new Uint32Array(256), new Uint32Array(256), new Uint32Array(256)];
  for (let y = 0; y < h; y += 2) {
    for (let x = 0; x < w; x += 2) {
      const i = (y * w + x) * 3;
      const r = data[i], g = data[i + 1], b = data[i + 2];
      if (r > 225 && g < 80 && b < 80) {
        hist[0][r]++; hist[1][g]++; hist[2][b]++;
      }
    }
  }
  const med = (hh) => {
    let total = 0;
    for (const v of hh) total += v;
    let acc = 0;
    for (let i = 0; i < 256; i++) {
      acc += hh[i];
      if (acc >= total / 2) return i;
    }
    return 0;
  };
  return [med(hist[0]), med(hist[1]), med(hist[2])];
}

// Dis beyaz bolgeyi kose(ler)den tasirarak bul, kenar bandinda beyaz/kirmizi karisimini coz (alfa)
function cutOut(src, red) {
  const { data, w, h } = src;
  const n = w * h;
  const outside = new Uint8Array(n);
  const queue = new Int32Array(n);
  let qh = 0, qt = 0;
  const isBgish = (p) => data[p * 3 + 1] > 150; // yesil kanal: kirmizi ~58, beyaz ~254
  const push = (p) => {
    if (!outside[p] && isBgish(p)) {
      outside[p] = 1;
      queue[qt++] = p;
    }
  };
  for (let x = 0; x < w; x++) { push(x); push((h - 1) * w + x); }
  for (let y = 0; y < h; y++) { push(y * w); push(y * w + w - 1); }
  while (qh < qt) {
    const p = queue[qh++];
    const x = p % w, y = (p / w) | 0;
    if (x > 0) push(p - 1);
    if (x < w - 1) push(p + 1);
    if (y > 0) push(p - w);
    if (y < h - 1) push(p + w);
  }
  // Disa yakin bant: dis maskesinin 3 piksel genislemesi (ic harflere ulasmaz, onlar 100+ px iceride)
  const band = new Uint8Array(n);
  const R = 3;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const p = y * w + x;
      if (outside[p]) continue;
      let near = false;
      for (let dy = -R; dy <= R && !near; dy++) {
        const yy = y + dy;
        if (yy < 0 || yy >= h) continue;
        for (let dx = -R; dx <= R; dx++) {
          const xx = x + dx;
          if (xx < 0 || xx >= w) continue;
          if (outside[yy * w + xx]) { near = true; break; }
        }
      }
      if (near) band[p] = 1;
    }
  }
  const out = Buffer.alloc(n * 4);
  const gR = red[1];
  for (let p = 0; p < n; p++) {
    const g = data[p * 3 + 1];
    let a = 255;
    let r = data[p * 3], gg = g, b = data[p * 3 + 2];
    if (outside[p]) {
      a = 0; r = red[0]; gg = red[1]; b = red[2];
    } else if (band[p]) {
      // piksel = alfa*kirmizi + (1-alfa)*beyaz  -> yesil kanaldan alfa
      const alpha = Math.min(1, Math.max(0, (254 - g) / (254 - gR)));
      a = alpha < 0.01 ? 0 : Math.round(alpha * 255);
      r = red[0]; gg = red[1]; b = red[2];
    }
    out[p * 4] = r; out[p * 4 + 1] = gg; out[p * 4 + 2] = b; out[p * 4 + 3] = a;
  }
  // sinirlayici kutu (alfa >= 128)
  let x0 = w, x1 = 0, y0 = h, y1 = 0;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (out[(y * w + x) * 4 + 3] >= 128) {
        if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
      }
    }
  }
  return { rgba: out, w, h, box: { left: x0, top: y0, width: x1 - x0 + 1, height: y1 - y0 + 1 } };
}

/** Ana isaret: MASTER x MASTER RGBA (seffaf koseler). Kaynak hafif kare degildir (1034x1020): kareye olceklenir. */
async function buildMaster() {
  const src = await loadSource();
  const red = measureRed(src);
  const cut = cutOut(src, red);
  const png = await sharp(cut.rgba, { raw: { width: cut.w, height: cut.h, channels: 4 } })
    .extract(cut.box)
    .resize(MASTER, MASTER, { fit: 'fill', kernel: 'lanczos3' })
    .png()
    .toBuffer();
  return { png, red, box: cut.box };
}

/** Master'dan mono maskeler: harfler (L) ve harfleri oyulmus kare (knockout). Ciktilar tek renkli RGBA. */
async function buildMono(masterPng, red, color /* [r,g,b] */) {
  const { data, info } = await sharp(masterPng).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const n = info.width * info.height;
  const knock = Buffer.alloc(n * 4);
  const letters = Buffer.alloc(n * 4);
  for (let p = 0; p < n; p++) {
    const a = data[p * 4 + 3] / 255;
    // harflilik: yesil kanal kirmiziden beyaza ne kadar gitti
    const L = Math.min(1, Math.max(0, (data[p * 4 + 1] - red[1]) / (255 - red[1])));
    for (const [buf, alpha] of [[knock, a * (1 - L)], [letters, a * L]]) {
      buf[p * 4] = color[0]; buf[p * 4 + 1] = color[1]; buf[p * 4 + 2] = color[2];
      buf[p * 4 + 3] = Math.round(alpha * 255);
    }
  }
  const raw = { raw: { width: info.width, height: info.height, channels: 4 } };
  return {
    knockout: await sharp(knock, raw).png().toBuffer(),
    letters: await sharp(letters, raw).png().toBuffer(),
  };
}

module.exports = { buildMaster, buildMono, MASTER };
