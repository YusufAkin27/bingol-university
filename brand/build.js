/**
 * Marka varliklari uretici: 3 logo konsepti -> SVG + PNG + uygulama ikonlari + onizleme sayfasi.
 *   cd brand && node build.js
 * PNG'ler icin web/node_modules icindeki Playwright (Chromium) kullanilir.
 */
const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const NAVY = '#1B3A6B';
const NAVY_DEEP = '#10264A';
const BLUE = '#2B5CA6';
const RED = '#D53E35';

const require2 = createRequire(path.join(__dirname, '..', 'web', 'package.json'));
const { chromium } = require2('@playwright/test');

// ---- Konsept isaretleri (512x512 koordinat, arka plansiz) ----
const concepts = {
  zirve: {
    name: 'Zirve',
    note: 'Dağ zirvesi, kırmızı güneş ve göl dalgaları. En sade ve en okunaklı küçük boyutta.',
    mark: `
      <path d="M40 372 L170 214 L250 300 L336 178 L472 372 Z" fill="#fff" fill-opacity=".22"/>
      <path d="M96 372 L256 148 L416 372 Z" fill="#fff"/>
      <path d="M256 148 L416 372 L256 372 Z" fill="#DCE6F5"/>
      <circle cx="360" cy="146" r="28" fill="${RED}"/>
      <path d="M112 414 q36 -20 72 0 t72 0 t72 0 t72 0" fill="none" stroke="#fff" stroke-opacity=".75" stroke-width="12" stroke-linecap="round"/>`,
  },
  gol: {
    name: 'Göl',
    note: 'Bingöl\'ün "bin göl" kimliği: yuvarlak pencerede dağ, güneş ve su. Daha illüstratif.',
    mark: `
      <defs><clipPath id="win"><circle cx="256" cy="256" r="176"/></clipPath></defs>
      <g clip-path="url(#win)">
        <rect x="80" y="80" width="352" height="352" fill="#EEF4FC"/>
        <circle cx="334" cy="190" r="34" fill="${RED}"/>
        <path d="M80 300 L190 168 L250 240 L322 148 L432 300 Z" fill="#4D7BC2"/>
        <path d="M80 322 L172 214 L256 300 L350 200 L432 322 Z" fill="${NAVY}"/>
        <rect x="80" y="304" width="352" height="130" fill="${BLUE}"/>
        <path d="M110 334 q26 -14 52 0 t52 0 t52 0 t52 0 t52 0 t52 0" fill="none" stroke="#fff" stroke-opacity=".85" stroke-width="9" stroke-linecap="round"/>
        <path d="M150 366 q24 -12 48 0 t48 0 t48 0 t48 0 t48 0" fill="none" stroke="#fff" stroke-opacity=".6" stroke-width="9" stroke-linecap="round"/>
        <path d="M200 396 q20 -10 40 0 t40 0 t40 0 t40 0" fill="none" stroke="#fff" stroke-opacity=".4" stroke-width="9" stroke-linecap="round"/>
      </g>
      <circle cx="256" cy="256" r="176" fill="none" stroke="#fff" stroke-width="10"/>`,
  },
  monogram: {
    name: 'Monogram',
    note: 'Geometrik "B" harfi ve kırmızı vurgu. En kurumsal ve modern görünüm.',
    mark: `
      <path fill-rule="evenodd" fill="#fff" d="M150 112 H274 C334 112 372 148 372 200 C372 232 356 254 332 266 C366 278 392 304 392 346 C392 402 350 432 290 432 H150 Z
        M210 160 V240 H268 C292 240 308 226 308 200 C308 174 292 160 268 160 Z
        M210 286 V384 H280 C312 384 332 370 332 336 C332 302 312 286 280 286 Z"/>
      <circle cx="392" cy="122" r="26" fill="${RED}"/>`,
  },
};

const bgDefs = (id) => `
  <linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#2F63B0"/>
    <stop offset="1" stop-color="${NAVY_DEEP}"/>
  </linearGradient>`;

/** Kare uygulama ikonu. radius=0 → magaza (tam kare). */
function icon(key, { radius = 112, size = 512 } = {}) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 512 512" role="img" aria-label="Bingöl Üniversitesi">
  <defs>${bgDefs('bg')}</defs>
  <rect width="512" height="512" rx="${radius}" fill="url(#bg)"/>
  ${concepts[key].mark}
</svg>`;
}

/** Android uyarlanabilir ikon katmanlari (108dp = 432 birim, guvenli bolge ~264). */
function adaptive(key) {
  const fg = `<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 432 432">
  <g transform="translate(108 108) scale(0.5859375)">${concepts[key].mark}</g>
</svg>`;
  const bg = `<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 432 432">
  <defs>${bgDefs('bg')}</defs>
  <rect width="432" height="432" fill="url(#bg)"/>
</svg>`;
  return { fg, bg };
}

/** Yatay logo (ikon + yazi). */
function lockup(key, dark) {
  const text = dark ? '#FFFFFF' : NAVY_DEEP;
  const sub = dark ? '#FF8A80' : RED;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="360" viewBox="0 0 1200 360" role="img" aria-label="Bingöl Üniversitesi">
  <defs>${bgDefs('bg')}</defs>
  <g transform="translate(0 30) scale(0.5859375)">
    <rect width="512" height="512" rx="112" fill="url(#bg)"/>
    ${concepts[key].mark}
  </g>
  <text x="350" y="190" font-family="'Segoe UI','Helvetica Neue',Arial,sans-serif" font-size="124" font-weight="700" letter-spacing="-2" fill="${text}">Bingöl</text>
  <text x="354" y="262" font-family="'Segoe UI','Helvetica Neue',Arial,sans-serif" font-size="46" font-weight="600" letter-spacing="15" fill="${sub}">ÜNİVERSİTESİ</text>
</svg>`;
}

/** Sadece isaret (arka plansiz, tek renk) — favicon/filigran icin. */
function favicon(key) {
  return icon(key, { radius: 112, size: 64 });
}

// ---- Dosyalari yaz ----
const out = (p) => path.join(__dirname, p);
for (const d of ['svg', 'png', 'app-icons']) fs.mkdirSync(out(d), { recursive: true });

const jobs = []; // {svg, file, w, h, bg?}
for (const key of Object.keys(concepts)) {
  const svgs = {
    [`svg/${key}-icon.svg`]: icon(key),
    [`svg/${key}-icon-store.svg`]: icon(key, { radius: 0 }),
    [`svg/${key}-lockup-light.svg`]: lockup(key, false),
    [`svg/${key}-lockup-dark.svg`]: lockup(key, true),
    [`app-icons/${key}-android-foreground.svg`]: adaptive(key).fg,
    [`app-icons/${key}-android-background.svg`]: adaptive(key).bg,
    [`svg/${key}-favicon.svg`]: favicon(key),
  };
  for (const [f, s] of Object.entries(svgs)) fs.writeFileSync(out(f), s);
  jobs.push({ svg: svgs[`svg/${key}-icon.svg`], file: `png/${key}-icon-1024.png`, w: 1024, h: 1024 });
  jobs.push({ svg: svgs[`svg/${key}-icon-store.svg`], file: `app-icons/${key}-play-store-512.png`, w: 512, h: 512 });
  jobs.push({ svg: svgs[`svg/${key}-icon-store.svg`], file: `app-icons/${key}-app-store-1024.png`, w: 1024, h: 1024 });
  jobs.push({ svg: svgs[`app-icons/${key}-android-foreground.svg`], file: `app-icons/${key}-android-foreground-432.png`, w: 432, h: 432 });
  jobs.push({ svg: svgs[`app-icons/${key}-android-background.svg`], file: `app-icons/${key}-android-background-432.png`, w: 432, h: 432 });
  jobs.push({ svg: svgs[`svg/${key}-lockup-light.svg`], file: `png/${key}-lockup-light.png`, w: 1200, h: 360, bg: '#FFFFFF' });
  jobs.push({ svg: svgs[`svg/${key}-lockup-dark.svg`], file: `png/${key}-lockup-dark.png`, w: 1200, h: 360, bg: '#0D1B33' });
  for (const s of [48, 192, 512]) {
    jobs.push({ svg: icon(key, { size: s }), file: `png/${key}-icon-${s}.png`, w: s, h: s });
  }
}

// ---- Onizleme sayfasi ----
const cards = Object.entries(concepts).map(([key, c], i) => `
  <section class="card">
    <h2>${String.fromCharCode(65 + i)} · ${c.name}</h2>
    <p>${c.note}</p>
    <div class="row">
      <div class="big">${icon(key, { size: 200 })}</div>
      <div class="sizes">
        ${[96, 64, 48, 32].map((s) => `<div>${icon(key, { size: s })}<small>${s}px</small></div>`).join('')}
      </div>
      <div class="phone">
        <div class="home">${[0, 1, 2].map(() => '<i></i>').join('')}<div class="app">${icon(key, { size: 64 })}<small>Bingöl</small></div>${[0, 1].map(() => '<i></i>').join('')}</div>
      </div>
    </div>
    <div class="lock light">${lockup(key, false).replace('width="1200" height="360"', 'width="480" height="144"')}</div>
    <div class="lock dark">${lockup(key, true).replace('width="1200" height="360"', 'width="480" height="144"')}</div>
  </section>`).join('');

const preview = `<!doctype html><html><head><meta charset="utf-8"><style>
  body{margin:0;padding:36px;background:#EEF2F8;font-family:'Segoe UI',Arial,sans-serif;color:#10264A}
  h1{margin:0 0 6px;font-size:30px} .sub{margin:0 0 26px;color:#52607A}
  .grid{display:grid;grid-template-columns:repeat(3,1fr);gap:26px}
  .card{background:#fff;border-radius:22px;padding:24px;box-shadow:0 2px 14px rgba(16,38,74,.08)}
  .card h2{margin:0 0 4px;font-size:22px} .card p{margin:0 0 16px;color:#52607A;font-size:14px;min-height:40px}
  .row{display:flex;gap:18px;align-items:flex-end;margin-bottom:18px}
  .sizes{display:flex;gap:10px;align-items:flex-end} .sizes div{text-align:center} small{display:block;font-size:11px;color:#6B778C;margin-top:4px}
  .phone{margin-inline-start:auto;width:130px;height:150px;border-radius:20px;background:linear-gradient(160deg,#6B8FC7,#1B3A6B);padding:14px;box-sizing:border-box}
  .home{display:grid;grid-template-columns:repeat(2,1fr);gap:10px;align-items:center} .home i{display:block;height:58px;border-radius:14px;background:rgba(255,255,255,.22)}
  .home .app{text-align:center} .home .app small{color:#fff;margin-top:2px} .home .app svg{width:58px;height:58px;border-radius:14px}
  .lock{border-radius:14px;padding:8px 12px;margin-top:10px;display:flex;justify-content:center}
  .lock.light{background:#fff;border:1px solid #E1E7F0} .lock.dark{background:#0D1B33}
</style></head><body>
  <h1>Bingöl Üniversitesi — logo konseptleri</h1>
  <p class="sub">Marka renkleri: lacivert ${NAVY}, mavi ${BLUE}, kırmızı ${RED}</p>
  <div class="grid">${cards}</div>
</body></html>`;
fs.writeFileSync(out('preview.html'), preview);

(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  for (const j of jobs) {
    await page.setViewportSize({ width: j.w, height: j.h });
    const svg = j.svg.replace(/<svg ([^>]*?)width="\d+" height="\d+"/, `<svg $1width="${j.w}" height="${j.h}"`);
    await page.setContent(`<html><body style="margin:0;background:${j.bg || 'transparent'}">${svg}</body></html>`);
    await page.screenshot({ path: out(j.file), omitBackground: !j.bg, clip: { x: 0, y: 0, width: j.w, height: j.h } });
  }
  await page.setViewportSize({ width: 1640, height: 900 });
  await page.goto('file:///' + out('preview.html').replace(/\\/g, '/'));
  await page.waitForTimeout(300);
  await page.screenshot({ path: out('preview.png'), fullPage: true });
  await browser.close();
  console.log('tamam:', jobs.length, 'PNG + onizleme');
})();
