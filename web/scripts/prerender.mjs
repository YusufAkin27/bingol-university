// Derleme sonrası SEO önrender: `vite build` çıktısını (dist/) sayfa başına statik HTML'e çoğaltır.
//   node scripts/prerender.mjs        (npm run build zincirinde otomatik)
// Üretir: dist/<tr|en|ar>/<yol>/index.html (title, description, canonical, hreflang, OG, Twitter, JSON-LD, <noscript> metni),
//         dist/index.html (kök), dist/sitemap.xml, dist/robots.txt, dist/.well-known/security.txt ({{ORIGIN}} doldurulur).
// Köken: PUBLIC_WEB_URL (yoksa VITE_PUBLIC_URL, yoksa https://bukampus.net). Headless tarayıcı gerekmez.
// Mantık src/seo/*.ts içindedir (testli); bu dosya yalnızca dosya sistemi ve doğrulama işini yapar.
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'vite';

const t0 = Date.now();
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(root, 'dist');
const origin = (process.env.PUBLIC_WEB_URL || process.env.VITE_PUBLIC_URL || '').trim();

function fail(msg) {
  console.error(`prerender HATASI: ${msg}`);
  process.exit(1);
}

const indexPath = join(dist, 'index.html');
if (!existsSync(indexPath)) fail('dist/index.html yok; önce `vite build` çalıştırın');
const template = readFileSync(indexPath, 'utf8');

// TypeScript kaynaklarını (sözlükler, routeMeta) Vite'ın SSR yükleyicisiyle okur; paketleme gerekmez
const server = await createServer({
  root,
  mode: 'production',
  logLevel: 'error',
  appType: 'custom',
  server: { middlewareMode: true, hmr: false, watch: null },
  optimizeDeps: { noDiscovery: true, include: [] },
});
let mod;
try {
  mod = await server.ssrLoadModule('/src/seo/prerender.ts');
} finally {
  await server.close();
}

const buildDate = new Date().toISOString().slice(0, 10);
const result = mod.prerender({ template, origin, buildDate });
const resolvedOrigin = origin.replace(/\/+$/, '') || 'https://bukampus.net';

for (const [rel, html] of result.files) {
  const file = join(dist, rel);
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, html, 'utf8');
}

// security.txt: {{ORIGIN}} → gerçek köken
const secPath = join(dist, '.well-known', 'security.txt');
if (existsSync(secPath)) {
  writeFileSync(secPath, mod.renderSecurityTxt(readFileSync(secPath, 'utf8'), resolvedOrigin), 'utf8');
}

// --- doğrulama: yer tutucu kalmamalı, kritik sayfalar eksiksiz olmalı ---
function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}
const textFiles = walk(dist).filter((f) => /\.(html|xml|txt)$/.test(f));
for (const f of textFiles) {
  const body = readFileSync(f, 'utf8');
  if (/ALAN-ADI|\{\{ORIGIN\}\}/.test(body)) fail(`yer tutucu kalmış: ${f}`);
}
for (const lang of ['tr', 'en', 'ar']) {
  for (const slug of ['privacy', 'delete-account', 'contact']) {
    const f = join(dist, lang, slug, 'index.html');
    if (!existsSync(f)) fail(`eksik: ${f}`);
    const h = readFileSync(f, 'utf8');
    const need = [
      '<title>',
      'name="description"',
      `rel="canonical" href="${resolvedOrigin}/${lang}/${slug}"`,
      'hreflang="x-default"',
      'property="og:image" content="' + resolvedOrigin + '/og.png"',
      '<noscript>',
      `<html lang="${lang}"`,
    ];
    for (const n of need) if (!h.includes(n)) fail(`${f} içinde yok: ${n}`);
  }
}
const robots = readFileSync(join(dist, 'robots.txt'), 'utf8');
if (!robots.includes(`Sitemap: ${resolvedOrigin}/sitemap.xml`) || !robots.includes('Disallow: /admin')) {
  fail('robots.txt eksik');
}

console.log(
  `prerender: ${result.pageCount} sayfa + kök, sitemap.xml, robots.txt (${resolvedOrigin}) — ${Date.now() - t0} ms`,
);
