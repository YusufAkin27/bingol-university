// Derleme sonrası SEO önrender: `vite build` çıktısını (dist/) sayfa başına statik HTML'e çoğaltır.
//   node scripts/prerender.mjs        (npm run build zincirinde otomatik)
// Üretir: dist/<tr|en|ar>/<yol>/index.html (title, description, canonical, hreflang, OG, Twitter, JSON-LD, <noscript> metni),
//         dist/index.html (kök), dist/sitemap.xml, dist/robots.txt, dist/.well-known/security.txt ({{ORIGIN}} doldurulur).
// Köken: PUBLIC_WEB_URL (yoksa VITE_PUBLIC_URL, yoksa https://bukampus.com.tr). Headless tarayıcı gerekmez.
// Mantık src/seo/*.ts içindedir (testli); bu dosya yalnızca dosya sistemi ve doğrulama işini yapar.
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
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

// Parça ipuçları: sözlük ve sayfa parçaları HTML'den önceden istenir (modulepreload), böylece ana paket çalışınca
// sırayla indirme şelalesi oluşmaz. Kaynak: vite manifest'i (build.manifest); yoksa ipucu verilmez, site yine çalışır.
const manifestPath = join(dist, '.vite', 'manifest.json');
const manifest = existsSync(manifestPath) ? JSON.parse(readFileSync(manifestPath, 'utf8')) : null;
const PAGE_SRC = {
  home: 'HomePage', features: 'FeaturesPage', about: 'AboutPage', download: 'DownloadPage', news: 'NewsListPage',
  menu: 'MenuPage', help: 'HelpPage', faq: 'FaqPage', contact: 'ContactPage', brand: 'BrandPage',
  changelog: 'ChangelogPage', deleteAccount: 'DeleteAccountPage', dataRequest: 'DataRequestPage',
  privacy: 'LegalPage', terms: 'LegalPage', legal: 'LegalListPage', legalKvkk: 'LegalPage',
  legalCommunityRules: 'LegalPage', legalExplicitConsent: 'LegalPage', legalContentRemoval: 'LegalPage',
  legalRetention: 'LegalPage', cookies: 'CookiesPage', guidelines: 'CommunityGuidelinesPage',
  accessibility: 'AccessibilityPage', security: 'SecurityPage', sitemap: 'SitemapPage',
};
// girdi paketinin (index.html) zaten yüklediği dosyalar yeniden ipucu olmasın
// (SEO bloğu hariç: betik yeniden çalışınca önceki ipuçları girdi sayılmasın)
const templateNoSeo = template.replace(/<!--seo:start-->[\s\S]*?<!--seo:end-->/, '');
const entryFiles = new Set(
  [...templateNoSeo.matchAll(/(?:src|href)="\/(assets\/[^"]+\.js)"/g)].map((m) => m[1]),
);
function closure(srcKey) {
  const js = [];
  const css = [];
  const seen = new Set();
  const walk = (k) => {
    const c = manifest?.[k];
    if (!c || seen.has(k)) return;
    seen.add(k);
    if (!entryFiles.has(c.file)) js.push('/' + c.file);
    for (const f of c.css ?? []) css.push('/' + f);
    for (const i of c.imports ?? []) walk(i);
  };
  walk(srcKey);
  return { js, css };
}
const hints = manifest
  ? {
      dictionary: (lang) => closure(`src/i18n/bundles/site.${lang}.ts`).js,
      page: (id) => (PAGE_SRC[id] ? closure(`src/pages/site/${PAGE_SRC[id]}.tsx`) : { js: [], css: [] }),
    }
  : undefined;
if (!hints) console.warn('prerender: vite manifest yok, modulepreload ipuçları atlandı');

const buildDate = new Date().toISOString().slice(0, 10);
const result = mod.prerender({ template, origin, buildDate, hints });
const resolvedOrigin = origin.replace(/\/+$/, '') || 'https://bukampus.com.tr';

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

// manifest yalnızca derleme aracıdır; yayına girmesin
rmSync(join(dist, '.vite'), { recursive: true, force: true });

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
