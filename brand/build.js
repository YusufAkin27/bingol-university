// Tum marka cikti dosyalarini source/logo.png'den uretir.  Kullanim: cd brand && npm install && node build.js
// Yazi tipi: source/wordmark.json onbellekte (yazi tipi dosyasi gerekmez); bkz. tools/text.js
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { buildMaster, buildMono, MASTER } = require('./tools/mark');
const { loadWordmark, block } = require('./tools/text');

const ROOT = path.resolve(__dirname, '..');
const DIST = path.join(__dirname, 'dist');
const NAVY = '#10264A';
const NAVY_DEEP = '#0B1B36';
const TAG_LIGHT = '#53607A';
const TAG_DARK = '#B7C6E4';
const S = 512; // lockup'larda ikon kenari (px)

const write = (file, buf) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, buf);
};
const hex = (c) => '#' + c.map((v) => v.toString(16).padStart(2, '0')).join('').toUpperCase();
const b64 = (b) => b.toString('base64');

async function palettePng(buf, size) {
  return sharp(buf).resize(size, size, { kernel: 'lanczos3' }).png({ palette: true, quality: 100, effort: 10, colours: 64, dither: 0.4 }).toBuffer();
}
const resize = (buf, size) => sharp(buf).resize(size, size, { kernel: 'lanczos3' }).png().toBuffer();

async function flatBleed(master, red, size) {
  // Kose yuvarlatmasiz, tam kare (store/iOS): koseler ayni kirmizi ile dolar
  return sharp(master)
    .flatten({ background: { r: red[0], g: red[1], b: red[2] } })
    .resize(size, size, { kernel: 'lanczos3' })
    .removeAlpha()
    .png()
    .toBuffer();
}

async function onCanvas(w, h, items, background = { r: 0, g: 0, b: 0, alpha: 0 }) {
  return sharp({ create: { width: w, height: h, channels: 4, background } })
    .composite(items)
    .png()
    .toBuffer();
}

function buildIco(pngs /* [{size, buf}] */) {
  const head = Buffer.alloc(6);
  head.writeUInt16LE(1, 2);
  head.writeUInt16LE(pngs.length, 4);
  let offset = 6 + pngs.length * 16;
  const entries = pngs.map(({ size, buf }) => {
    const e = Buffer.alloc(16);
    e[0] = size >= 256 ? 0 : size;
    e[1] = size >= 256 ? 0 : size;
    e.writeUInt16LE(1, 4);
    e.writeUInt16LE(32, 6);
    e.writeUInt32LE(buf.length, 8);
    e.writeUInt32LE(offset, 12);
    offset += buf.length;
    return e;
  });
  return Buffer.concat([head, ...entries, ...pngs.map((p) => p.buf)]);
}

const TONES = {
  light: { text: NAVY, tag: TAG_LIGHT, mark: 'color' },
  dark: { text: '#FFFFFF', tag: TAG_DARK, mark: 'color' },
  white: { text: '#FFFFFF', tag: '#FFFFFF', mark: 'white' },
  black: { text: '#000000', tag: '#000000', mark: 'black' },
};

/** Lockup govdesi: { w, h, body } (kok svg disinda); marks: {color, white, black} = base64 PNG (gomulu) */
function lockup(wm, { orient, tagline, tone }, marks) {
  const T = TONES[tone];
  const img = (x, y) =>
    `<image x="${x}" y="${y}" width="${S}" height="${S}" href="data:image/png;base64,${marks[T.mark]}"/>`;
  if (orient === 'horizontal') {
    const gap = 0.24 * S;
    const x = S + gap;
    if (!tagline) {
      const name = block(wm, 'name', { fontSize: 0.5 * S });
      const base = S / 2 + name.capH / 2;
      return { w: Math.ceil(x + name.inkW), h: S, body: img(0, 0) + name.svg(x, base, T.text) };
    }
    const name = block(wm, 'name', { fontSize: 0.42 * S });
    const tag = block(wm, 'tagline', { inkW: name.inkW });
    const gapV = 0.15 * S;
    const bh = name.capH + gapV + tag.capH;
    const base = S / 2 - bh / 2 + name.capH;
    return {
      w: Math.ceil(x + name.inkW),
      h: S,
      body: img(0, 0) + name.svg(x, base, T.text) + tag.svg(x, base + gapV + tag.capH, T.tag),
    };
  }
  // dikey
  const name = block(wm, 'name', { fontSize: (tagline ? 0.3 : 0.36) * S });
  const W = Math.ceil(Math.max(S, name.inkW));
  const base = S + 0.2 * S + name.capH;
  const mx = (W - S) / 2;
  const tx = (W - name.inkW) / 2;
  if (!tagline) {
    return { w: W, h: Math.ceil(base + name.descent), body: img(mx, 0) + name.svg(tx, base, T.text) };
  }
  const tag = block(wm, 'tagline', { inkW: name.inkW });
  const tb = base + 0.13 * S + tag.capH;
  return {
    w: W,
    h: Math.ceil(tb),
    body: img(mx, 0) + name.svg(tx, base, T.text) + tag.svg(tx, tb, T.tag),
  };
}

const svgRoot = (w, h, body) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${body}</svg>`;

async function main() {
  fs.mkdirSync(DIST, { recursive: true });
  const wm = loadWordmark();
  const { png: master, red, box } = await buildMaster();
  const RED = hex(red);
  console.log('Olculen kirmizi:', RED, 'kaynak kutu:', JSON.stringify(box));
  const white = await buildMono(master, red, [255, 255, 255]);
  const black = await buildMono(master, red, [0, 0, 0]);

  // ---- dist: isaret ----
  write(path.join(DIST, 'colors.json'), JSON.stringify({ red: RED, navy: NAVY, navyDeep: NAVY_DEEP, taglineLight: TAG_LIGHT, taglineDark: TAG_DARK }, null, 2) + '\n');
  write(path.join(DIST, 'mark.png'), master);
  write(path.join(DIST, 'mark-fullbleed-1024.png'), await flatBleed(master, red, 1024));
  write(path.join(DIST, 'mark-white.png'), white.knockout);
  write(path.join(DIST, 'mark-black.png'), black.knockout);
  write(path.join(DIST, 'mark-letters-white.png'), white.letters);
  write(path.join(DIST, 'mark-letters-black.png'), black.letters);

  const embed = async (size) => ({
    color: b64(await palettePng(master, size)),
    white: b64(await palettePng(white.knockout, size)),
    black: b64(await palettePng(black.knockout, size)),
  });
  const marks512 = await embed(512);
  const marks256 = await embed(256);
  const markSvg = (m) => svgRoot(512, 512, `<image width="512" height="512" href="data:image/png;base64,${m}"/>`);
  write(path.join(DIST, 'mark.svg'), markSvg(marks512.color));

  // ---- dist: lockup'lar ----
  const sizes = {};
  const webAssets = {}; // web icin 256 gomuluk surum
  for (const orient of ['horizontal', 'vertical']) {
    for (const tagline of [false, true]) {
      for (const tone of Object.keys(TONES)) {
        const name = `${orient}${tagline ? '-tagline' : ''}-${tone}`;
        const L = lockup(wm, { orient, tagline, tone }, marks512);
        const svg = svgRoot(L.w, L.h, L.body);
        write(path.join(DIST, name + '.svg'), svg);
        write(path.join(DIST, name + '.png'), await sharp(Buffer.from(svg)).png({ palette: true, quality: 100, effort: 10, colours: 64, dither: 0.4 }).toBuffer());
        sizes[name] = [L.w, L.h];
        if (tone === 'light' || tone === 'dark') {
          const LW = lockup(wm, { orient, tagline, tone }, marks256);
          webAssets[name] = { svg: svgRoot(LW.w, LW.h, LW.body), w: LW.w, h: LW.h };
        }
      }
    }
  }
  write(path.join(DIST, 'sizes.json'), JSON.stringify(sizes, null, 2) + '\n');

  // ---- Web ----
  const pub = path.join(ROOT, 'web', 'public');
  const fav = {};
  for (const s of [16, 32, 48]) fav[s] = await resize(master, s);
  write(path.join(pub, 'favicon.ico'), buildIco([16, 32, 48].map((s) => ({ size: s, buf: fav[s] }))));
  write(path.join(pub, 'favicon.svg'), markSvg(b64(await palettePng(master, 128))).replace('width="512" height="512"', 'width="64" height="64"').replace(/<image width="512" height="512"/, '<image width="512" height="512"'));
  write(path.join(pub, 'apple-touch-icon.png'), await flatBleed(master, red, 180));
  write(path.join(pub, 'icon-192.png'), await palettePng(master, 192));
  write(path.join(pub, 'icon-512.png'), await palettePng(master, 512));
  // maskable: guvenli bolge icin isaret %76'ya kuculur, kenarlar ayni kirmizi
  {
    const inner = await resize(master, Math.round(512 * 0.76));
    const off = Math.round((512 - 512 * 0.76) / 2);
    write(path.join(pub, 'icon-maskable-512.png'), await onCanvas(512, 512, [{ input: inner, left: off, top: off }], { r: red[0], g: red[1], b: red[2], alpha: 1 }).then((b) => sharp(b).png({ palette: true, quality: 100, effort: 10, colours: 64, dither: 0.4 }).toBuffer()));
  }

  const assetsDir = path.join(ROOT, 'web', 'src', 'assets', 'brand');
  write(path.join(assetsDir, 'mark.svg'), markSvg(marks256.color).replace('width="512" height="512"', 'width="256" height="256"'));
  const idx = ["// OTOMATIK URETILDI: brand/build.js (elle duzenlemeyin)"];
  const entries = [];
  idx.push("import mark from './mark.svg';");
  for (const [name, a] of Object.entries(webAssets)) {
    write(path.join(assetsDir, name + '.svg'), a.svg);
    const v = name.replace(/-/g, '_');
    idx.push(`import ${v} from './${name}.svg';`);
    entries.push(`  '${name}': { src: ${v}, width: ${a.w}, height: ${a.h} },`);
  }
  idx.push('', 'export const markAsset = { src: mark, width: 256, height: 256 };', '', 'export const lockupAssets: Record<string, { src: string; width: number; height: number }> = {', ...entries, '};', '');
  write(path.join(assetsDir, 'index.ts'), idx.join('\n'));

  // og.png 1200x630: lacivert zemin, ortada yatay lockup (tagline'li, koyu ton), alt kirmizi serit
  {
    const OW = 1200, OH = 630;
    const L = lockup(wm, { orient: 'horizontal', tagline: true, tone: 'dark' }, marks512);
    const k = 0.5;
    const tx = (OW - L.w * k) / 2, ty = (OH - L.h * k) / 2 - 10;
    const svg = svgRoot(OW, OH,
      `<rect width="${OW}" height="${OH}" fill="${NAVY}"/><rect y="${OH - 14}" width="${OW}" height="14" fill="${RED}"/>` +
      `<g transform="translate(${tx.toFixed(1)} ${ty.toFixed(1)}) scale(${k})">${L.body}</g>`);
    write(path.join(pub, 'og.png'), await sharp(Buffer.from(svg)).png({ palette: true, quality: 100, effort: 10 }).toBuffer());
  }

  // ---- Mobil: Android ----
  const res = path.join(ROOT, 'mobile', 'branding', 'android', 'res');
  const dens = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
  const full = await flatBleed(master, red, MASTER);
  const circleMask = (d) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${d}" height="${d}"><circle cx="${d / 2}" cy="${d / 2}" r="${d / 2}" fill="#fff"/></svg>`);
  for (const [d, m] of Object.entries(dens)) {
    const dir = path.join(res, 'mipmap-' + d);
    const px = Math.round(48 * m);
    // eski ikon: kare isaret, 1dp kenar bosluk
    const inner = await resize(master, Math.round(px * 44 / 48));
    const o = Math.round((px - px * 44 / 48) / 2);
    write(path.join(dir, 'ic_launcher.png'), await onCanvas(px, px, [{ input: inner, left: o, top: o }]));
    // yuvarlak: tam daire, ayni kirmizi + harfler
    const rd = Math.round(px * 46 / 48);
    const rbase = await sharp(full).resize(rd, rd, { kernel: 'lanczos3' }).png().toBuffer();
    const rround = await sharp(rbase).ensureAlpha().composite([{ input: circleMask(rd), blend: 'dest-in' }]).png().toBuffer();
    const ro = Math.round((px - rd) / 2);
    write(path.join(dir, 'ic_launcher_round.png'), await onCanvas(px, px, [{ input: rround, left: ro, top: ro }]));
    // adaptive: 108dp tuval, isaret 72dp (kirmizi kare on planda; guvenli bolge 66dp dairesi icinde harfler)
    const fpx = Math.round(108 * m), ipx = Math.round(72 * m), fo = Math.round((fpx - ipx) / 2);
    write(path.join(dir, 'ic_launcher_foreground.png'), await onCanvas(fpx, fpx, [{ input: await resize(master, ipx), left: fo, top: fo }]));
    write(path.join(dir, 'ic_launcher_monochrome.png'), await onCanvas(fpx, fpx, [{ input: await resize(black.letters, ipx), left: fo, top: fo }]));
    // bildirim: beyaz oyuk silÃ¼et, 24dp tuval, 20dp govde
    const npx = Math.round(24 * m), gpx = Math.round(20 * m), no = Math.round((npx - gpx) / 2);
    write(path.join(res, 'drawable-' + d, 'ic_stat_notification.png'), await onCanvas(npx, npx, [{ input: await resize(white.knockout, gpx), left: no, top: no }]));
  }
  write(path.join(res, 'mipmap-anydpi-v26', 'ic_launcher.xml'),
    '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/ic_launcher_background"/>\n    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n</adaptive-icon>\n');
  write(path.join(res, 'mipmap-anydpi-v26', 'ic_launcher_round.xml'),
    fs.readFileSync(path.join(res, 'mipmap-anydpi-v26', 'ic_launcher.xml')));
  write(path.join(res, 'values', 'ic_launcher_background.xml'),
    `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">${RED}</color>\n</resources>\n`);
  write(path.join(res, 'values', 'strings.xml'),
    '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <string name="app_name">BÃœ KampÃ¼s</string>\n</resources>\n');
  // Android 12 acilis ekrani ikonu: 288dp tuval (3x = 864 px), 136dp isaret
  {
    const cpx = 864, ipx = 408, o = (cpx - ipx) / 2;
    write(path.join(res, 'drawable', 'splash_icon.png'), await onCanvas(cpx, cpx, [{ input: await resize(master, ipx), left: o, top: o }]));
  }

  // ---- Mobil: uygulama ici varliklar + launcher_icons kaynaklari ----
  const as = path.join(ROOT, 'mobile', 'assets', 'branding');
  const hLight = lockup(wm, { orient: 'horizontal', tagline: false, tone: 'light' }, marks512);
  const hDark = lockup(wm, { orient: 'horizontal', tagline: false, tone: 'dark' }, marks512);
  const hh = 192; // yukseklik px (3x icin yeterli)
  const flat = (L, h) => sharp(Buffer.from(svgRoot(L.w, L.h, L.body))).resize({ height: h }).png({ palette: true, quality: 100, effort: 10 }).toBuffer();
  write(path.join(as, 'logo_horizontal.png'), await flat(hLight, hh));
  write(path.join(as, 'logo_horizontal_dark.png'), await flat(hDark, hh));
  write(path.join(as, 'mark.png'), await palettePng(master, 256));
  write(path.join(as, 'icon_1024.png'), await flatBleed(master, red, 1024));
  {
    const fpx = 432, ipx = 288, fo = 72;
    write(path.join(as, 'adaptive_foreground.png'), await onCanvas(fpx, fpx, [{ input: await resize(master, ipx), left: fo, top: fo }]));
    write(path.join(as, 'adaptive_monochrome.png'), await onCanvas(fpx, fpx, [{ input: await resize(black.letters, ipx), left: fo, top: fo }]));
  }

  // ---- Store ----
  const store = path.join(ROOT, 'mobile', 'branding', 'store');
  write(path.join(store, 'play-store-512.png'), await flatBleed(master, red, 512));
  {
    const FW = 1024, FH = 500;
    const name = block(wm, 'name', { fontSize: 128 });
    const tag = block(wm, 'tagline', { inkW: name.inkW });
    const ms = 250, gap = 56;
    const gw = ms + gap + name.inkW;
    const x0 = (FW - gw) / 2;
    const gapV = 28;
    const bh = name.capH + gapV + tag.capH;
    const base = FH / 2 - 8 - bh / 2 + name.capH;
    const body =
      `<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${NAVY}"/><stop offset="1" stop-color="${NAVY_DEEP}"/></linearGradient></defs>` +
      `<rect width="${FW}" height="${FH}" fill="url(#g)"/><rect y="${FH - 12}" width="${FW}" height="12" fill="${RED}"/>` +
      `<image x="${x0}" y="${(FH - ms) / 2 - 8}" width="${ms}" height="${ms}" href="data:image/png;base64,${marks512.color}"/>` +
      name.svg(x0 + ms + gap, base, '#FFFFFF') + tag.svg(x0 + ms + gap, base + gapV + tag.capH, TAG_DARK);
    write(path.join(store, 'feature-graphic-1024x500.png'), await sharp(Buffer.from(svgRoot(FW, FH, body))).png({ palette: true, quality: 100, effort: 10 }).toBuffer());
  }

  // ---- iOS ----
  const ios = path.join(ROOT, 'mobile', 'branding', 'ios', 'AppIcon.appiconset');
  const defs = [
    ['iphone', 20, 2], ['iphone', 20, 3], ['iphone', 29, 2], ['iphone', 29, 3], ['iphone', 40, 2], ['iphone', 40, 3], ['iphone', 60, 2], ['iphone', 60, 3],
    ['ipad', 20, 1], ['ipad', 20, 2], ['ipad', 29, 1], ['ipad', 29, 2], ['ipad', 40, 1], ['ipad', 40, 2], ['ipad', 76, 1], ['ipad', 76, 2], ['ipad', 83.5, 2],
    ['ios-marketing', 1024, 1],
  ];
  const images = [];
  for (const [idiom, size, scale] of defs) {
    const px = Math.round(size * scale);
    const file = `Icon-App-${size}x${size}@${scale}x.png`;
    write(path.join(ios, file), await flatBleed(master, red, px));
    images.push({ size: `${size}x${size}`, idiom, filename: file, scale: `${scale}x` });
  }
  write(path.join(ios, 'Contents.json'), JSON.stringify({ images, info: { version: 1, author: 'xcode' } }, null, 2) + '\n');

  console.log('Tamam. Lockup boyutlari:', JSON.stringify(sizes['horizontal-light']), JSON.stringify(sizes['vertical-light']));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

