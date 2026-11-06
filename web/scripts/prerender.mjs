// Derleme sonrası SEO önrender: `vite build` çıktısını (dist/) sayfa başına statik HTML'e çoğaltır.
//   node scripts/prerender.mjs        (npm run build zincirinde otomatik)
// Üretir: dist/<tr|en|ar>/<yol>/index.html (title, description, canonical, hreflang, OG, Twitter, JSON-LD, <noscript> metni),
//         dist/index.html (kök), dist/sitemap.xml, dist/robots.txt, dist/.well-known/security.txt ({{ORIGIN}} doldurulur).
// Köken: PUBLIC_WEB_URL (yoksa VITE_PUBLIC_URL, yoksa https://bukampus.com.tr). Headless tarayıcı gerekmez.
// Mantık src/seo/*.ts içindedir (testli); bu dosya yalnızca dosya sistemi ve doğrulama işini yapar.
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
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
  menu: 'MenuPage', help: 'HelpPage', faq: 'FaqPage', contact: 'ContactPage',
  changelog: 'ChangelogPage', deleteAccount: 'DeleteAccountPage', dataRequest: 'DataRequestPage',
  privacy: 'LegalPage', terms: 'LegalPage', legal: 'LegalListPage', legalKvkk: 'LegalPage',
  legalCommunityRules: 'LegalPage', legalExplicitConsent: 'LegalPage', legalContentRemoval: 'LegalPage',
  legalRetention: 'LegalPage', cookies: 'CookiesPage', guidelines: 'CommunityGuidelinesPage', childSafety: 'ChildSafetyPage',
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

// Derleme günü İstanbul saatiyle (sunucu UTC olsa da gece yarısı kayması olmasın)
const buildDate = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });

// --- sitemap lastmod: sayfa BAŞINA, gerçek değişim tarihi ---
// seo-lastmod.json (depoda tutulur): "<rota>:<dil>" -> { hash, lastmod }. Sayfanın içerik imzası (başlık, açıklama, JSON-LD,
// noscript metni; varlık özetleri hariç) değiştiyse lastmod = bugün, değişmediyse eski tarih korunur. Betik dosyayı
// günceller; içerik değiştiren commit'te güncel seo-lastmod.json da commit edilmelidir (docs/SEO_TECHNICAL.md bölüm 4).
// Yeniden üretilebilirlik: Docker derlemesinde dosya depodan gelir; kayıt konteyner içinde kalır ve zararsızdır.
const lastmodPath = join(root, 'seo-lastmod.json');
let lastmodDb = { version: 1, pages: {} };
if (existsSync(lastmodPath)) {
  try {
    lastmodDb = JSON.parse(readFileSync(lastmodPath, 'utf8'));
  } catch {
    fail('seo-lastmod.json okunamadı (geçersiz JSON)');
  }
}
const hasSigs = (r) => r.signatures instanceof Map;
// İmzalar, lastmod çözücüden ÖNCE gerekir: önce imza turu (dosya yazmadan), sonra asıl önrender
const sigRun = mod.prerender({ template, origin, buildDate });
if (!hasSigs(sigRun)) fail('prerender() imza haritası döndürmedi');
const nextPages = {};
let lastmodChanged = false;
for (const [key, hash] of [...sigRun.signatures].sort((a, b) => a[0].localeCompare(b[0]))) {
  const old = lastmodDb.pages?.[key];
  const entry = old && old.hash === hash ? old : { hash, lastmod: buildDate };
  if (!old || old.hash !== hash) lastmodChanged = true;
  nextPages[key] = entry;
}
if (Object.keys(lastmodDb.pages ?? {}).length !== Object.keys(nextPages).length) lastmodChanged = true;
if (lastmodChanged && process.env.SEO_LASTMOD_WRITE !== '0') {
  writeFileSync(lastmodPath, JSON.stringify({ version: 1, pages: nextPages }, null, 2) + '\n', 'utf8');
  console.log('prerender: seo-lastmod.json güncellendi (içeriği değişen sayfalar bugünün tarihini aldı) — commit edin');
}
const lastmodOf = (id, lang) => nextPages[`${id}:${lang}`]?.lastmod ?? buildDate;
const result = mod.prerender({ template, origin, buildDate, hints, lastmod: lastmodOf });
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

// nginx yönetim konumu: yönetim arayüzü yolu (VITE_ADMIN_PATH, derleme sırasında gömülür) nginx'e de bildirilir; böylece
// (1) yönetim kabuğu bu yolda 200 verir ama HER yanıtta X-Robots-Tag noindex taşır, (2) yönetim dışındaki bilinmeyen kök
// yollar gerçek 404 olur (soft 404 yok). Dockerfile bu dosyayı /etc/nginx/snippets/generated-locations.conf'a taşır ve html
// kökünden siler. Yol nginx yapılandırmasına girdiği için yalnız güvenli karakterlere izin verilir.
const rawAdmin = (process.env.VITE_ADMIN_PATH || '').trim().replace(/\/+$/, '');
const adminBase = !rawAdmin ? '/admin' : rawAdmin.startsWith('/') ? rawAdmin : `/${rawAdmin}`;
if (!/^\/[A-Za-z0-9_-]+(\/[A-Za-z0-9_-]+)*$/.test(adminBase)) fail(`VITE_ADMIN_PATH geçersiz karakter içeriyor: ${adminBase}`);
// Derleme kimliği: bu derlemenin giriş HTML'inin (hash'li varlık adları dahil) özeti. Gece yenileme katmanı (refresh-prerender.mjs)
// /var/lib/bu-dyn/<kimlik>/ altına yazar; yeni dağıtım yeni kimlik demektir, eski katman kendiliğinden devre dışı kalır
// (eski HTML'in sildiği hash'li varlıklara bağlanıp sayfayı bozması imkânsız).
const buildSource = templateNoSeo.replace(/<div id="root">[\s\S]*?<\/div>/, '').replace(/<html[^>]*>/, '');
const buildId = createHash('sha1').update(buildSource).digest('hex').slice(0, 10);
writeFileSync(join(dist, 'build-id.txt'), `${buildId}\n`, 'utf8');
const adminConf = [
  '# Otomatik üretildi: web/scripts/prerender.mjs (elle düzenlemeyin). Gece yenileme katmanı kökü + yönetim arayüzü kabuğu (noindex, önbelleksiz).',
  `set $dyn_root /var/lib/bu-dyn/${buildId};`,
  `location = ${adminBase} {`,
  '    add_header Cache-Control "no-cache";',
  '    add_header X-Robots-Tag "noindex, nofollow, noarchive" always;',
  '    include /etc/nginx/snippets/security.conf;',
  '    try_files /index.html =404;',
  '}',
  `location ^~ ${adminBase}/ {`,
  '    add_header Cache-Control "no-cache";',
  '    add_header X-Robots-Tag "noindex, nofollow, noarchive" always;',
  '    include /etc/nginx/snippets/security.conf;',
  '    try_files /index.html =404;',
  '}',
  '',
].join('\n');
writeFileSync(join(dist, '_nginx-generated.conf'), adminConf, 'utf8');

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
  for (const slug of ['privacy', 'delete-account', 'contact', 'child-safety']) {
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
// 404.html: nginx error_page ile bilinmeyen site yollarında sunulur (soft 404 olmasın); noindex + h1 + açıklama şart
const notFoundFile = join(dist, '404.html');
if (!existsSync(notFoundFile)) fail('eksik: dist/404.html');
const notFoundHtml = readFileSync(notFoundFile, 'utf8');
for (const n of ['name="robots" content="noindex', 'name="description"', '<noscript>', '<h1>']) {
  if (!notFoundHtml.includes(n)) fail(`404.html içinde yok: ${n}`);
}
if (/rel="canonical"/.test(notFoundHtml)) fail('404.html canonical içermemeli');
const robots = readFileSync(join(dist, 'robots.txt'), 'utf8');
if (!robots.includes(`Sitemap: ${resolvedOrigin}/sitemap.xml`) || !robots.includes('Disallow: /admin')) {
  fail('robots.txt eksik');
}
if (adminBase !== '/admin' && robots.includes(adminBase)) fail('robots.txt gizli yönetim yolunu açıklıyor');

console.log(
  `prerender: ${result.pageCount} sayfa + kök, sitemap.xml, robots.txt (${resolvedOrigin}) — ${Date.now() - t0} ms`,
);
