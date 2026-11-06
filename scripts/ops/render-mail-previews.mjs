// E-posta onizleme ekran goruntuleri (yalniz yerel render; gercek e-posta GONDERILMEZ).
//
// 1) HTML dosyalarini uret (backend/ icinde, Docker Maven ya da yerel JDK 17):
//      mvn -B -q test -Dtest=MailPreviewFilesTest -Dmail.preview.dir=<DIR>
// 2) Ekran goruntulerini al (web/ icinde playwright kurulu olmali: `cd web && npm ci`):
//      node scripts/ops/render-mail-previews.mjs <DIR> [dosyaAdiRegex]
//
// Her *.html icin Chromium'da 600 px genislikte ACIK ve KOYU (colorScheme emulasyonu) tam sayfa PNG, ayrica secili
// dosyalarda 375 px; yatay tasma, gorunen logo, resimlerin yuklenmesi ve metin kontrasti (AA: 4.5, buyuk metin 3)
// denetlenir. Sonuc <DIR>/INDEX.md (tablo) ve konsol ozeti.
import { createRequire } from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
// WEB_DIR: playwright'in kurulu oldugu web/ dizini (baska bir worktree'den kosarken)
const require = createRequire(path.join(process.env.WEB_DIR ?? path.join(here, '../../web'), 'package.json'));
const { chromium } = require('playwright');

const DIR = path.resolve(process.argv[2] ?? 'target/mail-preview');
const only = process.argv[3] ? new RegExp(process.argv[3]) : null;

/** Sayfa icinde calisir: tasma, resimler, kontrast ve font-weight toplar. */
const CHECK = () => {
  const parse = (s) => {
    const m = s.match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    const p = m[1].split(',').map((x) => parseFloat(x));
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
  };
  const bgOf = (el) => {
    let e = el;
    while (e) {
      const c = parse(getComputedStyle(e).backgroundColor);
      if (c && c.a > 0.9) return c;
      e = e.parentElement;
    }
    return { r: 255, g: 255, b: 255, a: 1 };
  };
  const L = (c) => {
    const f = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  };
  const bad = [];
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  const seen = new Set();
  while (walker.nextNode()) {
    const t = walker.currentNode.textContent.trim();
    if (!t) continue;
    const el = walker.currentNode.parentElement;
    if (seen.has(el)) continue;
    seen.add(el);
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden') continue;
    const fg = parse(cs.color);
    if (!fg) continue;
    const l1 = L(fg);
    const l2 = L(bgOf(el));
    const ratio = (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
    const need = parseFloat(cs.fontSize) >= 24 ? 3 : 4.5;
    if (ratio < need) bad.push(`${el.tagName}.${el.className} "${t.slice(0, 24)}" ${ratio.toFixed(2)}`);
  }
  const imgs = [...document.images].map((i) => ({
    cls: i.className,
    shown: i.offsetWidth > 0 && getComputedStyle(i).display !== 'none',
    ok: i.complete && i.naturalWidth > 0,
  }));
  const fonts = [...new Set([...document.querySelectorAll('body *')].map((e) => getComputedStyle(e).fontWeight))];
  return { bad, sw: document.documentElement.scrollWidth, iw: window.innerWidth, imgs, fonts };
};

const files = fs.readdirSync(DIR).filter((f) => f.endsWith('.html')).sort().filter((f) => !only || only.test(f));
const browser = await chromium.launch();
const rows = [];

async function shot(f, width, scheme, suffix) {
  const ctx = await browser.newContext({ viewport: { width, height: 800 }, colorScheme: scheme });
  const page = await ctx.newPage();
  await page.goto(pathToFileURL(path.join(DIR, f)).href);
  await page.waitForTimeout(80);
  const r = await page.evaluate(CHECK);
  const png = f.replace('.html', '') + '-' + suffix + '.png';
  await page.screenshot({ path: path.join(DIR, png), fullPage: true });
  rows.push({
    f, scheme: suffix, overflow: r.sw > r.iw, bad: r.bad,
    shown: r.imgs.filter((i) => i.shown).map((i) => i.cls).join('+') || '-',
    imgsOk: r.imgs.every((i) => i.ok), fonts: r.fonts.join(','), png,
  });
  await ctx.close();
}

for (const f of files) {
  await shot(f, 600, 'light', 'light');
  await shot(f, 600, 'dark', 'dark');
}
for (const f of files.filter((x) => /^(verification-ar|stress-announcement-tr|support-reply-en|custom-tr)\.html$/.test(x))) {
  await shot(f, 375, 'light', '375');
}
await browser.close();

let md = '# E-posta onizleme dizini\n\nUretim: `MailPreviewFilesTest` + `scripts/ops/render-mail-previews.mjs` (Chromium, 600 px; acik/koyu = `prefers-color-scheme`).\n\n';
md += '| dosya | tema | tasma | gorunen logo | resimler yuklendi | AA altinda | font-weight | goruntu |\n|---|---|---|---|---|---|---|---|\n';
for (const r of rows) {
  md += `| ${r.f} | ${r.scheme} | ${r.overflow ? 'EVET' : 'yok'} | ${r.shown} | ${r.imgsOk ? 'evet' : 'HAYIR'} | ${r.bad.length ? r.bad.join('; ') : '-'} | ${r.fonts} | ${r.png} |\n`;
}
fs.writeFileSync(path.join(DIR, 'INDEX.md'), md);
const issues = rows.filter((r) => r.overflow || r.bad.length || !r.imgsOk);
console.log('dosya x tema:', rows.length, 'sorunlu:', issues.length);
for (const r of issues) console.log(r.f, r.scheme, r.overflow ? 'TASMA' : '', r.bad.join('; '), r.imgsOk ? '' : 'IMG');
