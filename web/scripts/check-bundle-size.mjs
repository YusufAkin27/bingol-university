// Paket boyutu bütçesi: node scripts/check-bundle-size.mjs [--report] [--json]
// dist/assets içindeki JS/CSS parçalarının gzip (ve bilgi için brotli) boyutlarını ölçer, web/bundle-budget.json ile karşılaştırır.
//   initialJs  : girdi betiği + vite'ın girdiye bağladığı modulepreload bağımlılıkları (react/router/query; önrender ipuçları HARİÇ)
//   routeJs    : önrender edilmiş her site sayfası için tarayıcının ilk açılışta indirdiği tüm JS (girdi + sözlük + sayfa parçaları); en kötü sayfa
//   initialCss : dist/index.html'in bağladığı stylesheet'ler
//   chunks     : parça adı öneki (hash'siz) -> en çok gzip KB; "*" eşleşmeyen her parça için varsayılan
//   totalJs    : tüm JS parçalarının toplamı
// Bütçe aşılırsa çıkış kodu 1 (CI'da continue-on-error ile uyarı olarak çalışır). --report yalnızca tablo yazar, hep 0 döner.
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { brotliCompressSync, gzipSync, constants } from 'node:zlib';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(root, 'dist');
const assets = join(dist, 'assets');
const reportOnly = process.argv.includes('--report');
const asJson = process.argv.includes('--json');

if (!existsSync(join(dist, 'index.html'))) {
  console.error('check-bundle-size: dist/index.html yok; önce `npm run build` çalıştırın');
  process.exit(2);
}
const budget = JSON.parse(readFileSync(join(root, 'bundle-budget.json'), 'utf8'));

const kb = (n) => Math.round((n / 1024) * 100) / 100;
const sizes = new Map(); // dosya adı -> { raw, gzip, brotli }
function measure(name) {
  if (sizes.has(name)) return sizes.get(name);
  const buf = readFileSync(join(assets, name));
  const s = {
    raw: buf.length,
    gzip: gzipSync(buf, { level: 9 }).length,
    brotli: brotliCompressSync(buf, { params: { [constants.BROTLI_PARAM_QUALITY]: 11 } }).length,
  };
  sizes.set(name, s);
  return s;
}

const files = readdirSync(assets);
const js = files.filter((f) => f.endsWith('.js'));
const css = files.filter((f) => f.endsWith('.css'));

// kök index.html önrender edilmiş olabilir: sayfaya özel (data-pre) etiketleri at, geriye vite'ın girdi etiketleri kalsın
const html = readFileSync(join(dist, 'index.html'), 'utf8').replace(/<(?:link|script)[^>]*data-pre="1"[^>]*>/g, '');
const fileName = (href) => href.slice(href.lastIndexOf('/') + 1);
const refs = (re) => [...html.matchAll(re)].map((m) => fileName(m[1]));
const initialJs = [
  ...new Set([
    ...refs(/<script[^>]+type="module"[^>]+src="([^"]+)"/g),
    ...refs(/<link[^>]+rel="modulepreload"[^>]+href="([^"]+)"/g),
  ]),
].filter((f) => js.includes(f));
const initialCss = [...new Set(refs(/<link[^>]+rel="stylesheet"[^>]+href="([^"]+)"/g))].filter((f) => css.includes(f));

// Sayfa başına toplam JS: önrender edilmiş HTML'deki tüm modül betikleri/ipuçları (sayfaya özel ipuçları dahil)
const routeFiles = [];
(function walk(dir, rel) {
  for (const name of readdirSync(dir, { withFileTypes: true })) {
    if (name.name === 'assets' || name.name === 'brand' || name.name === 'fonts') continue;
    const p = join(dir, name.name);
    if (name.isDirectory()) walk(p, rel ? rel + '/' + name.name : name.name);
    else if (name.name === 'index.html' && rel) routeFiles.push(rel);
  }
})(dist, '');
const routeSizes = routeFiles.map((rel) => {
  const page = readFileSync(join(dist, rel, 'index.html'), 'utf8');
  const list = [
    ...new Set([
      ...[...page.matchAll(/<script[^>]+type="module"[^>]+src="([^"]+)"/g)].map((m) => fileName(m[1])),
      ...[...page.matchAll(/<link[^>]+rel="modulepreload"[^>]+href="([^"]+)"/g)].map((m) => fileName(m[1])),
    ]),
  ].filter((f) => js.includes(f));
  return { rel, kb: kb(list.reduce((a, f) => a + measure(f).gzip, 0)) };
});

const sum = (list, k) => list.reduce((a, f) => a + measure(f)[k], 0);
const baseName = (f) => f.replace(/-[\w-]{8}\.(js|css)$/, '');

const rows = [];
const problems = [];
function check(label, actualKb, limitKb) {
  const ok = limitKb === undefined || actualKb <= limitKb;
  rows.push({ label, gzipKb: actualKb, limitKb: limitKb ?? null, ok });
  if (!ok) problems.push(`${label}: ${actualKb} KB gzip > bütçe ${limitKb} KB`);
}

check('initialJs (girdi + modulepreload)', kb(sum(initialJs, 'gzip')), budget.initialJsGzipKB);
const worst = routeSizes.sort((a, b) => b.kb - a.kb)[0];
if (worst) check(`routeJs (en ağır önrender sayfa: ${worst.rel})`, worst.kb, budget.routeJsGzipKB);
check('initialCss', kb(sum(initialCss, 'gzip')), budget.initialCssGzipKB);
check('totalJs (tüm parçalar)', kb(sum(js, 'gzip')), budget.totalJsGzipKB);

const chunkLimits = budget.chunks ?? {};
const fallback = chunkLimits['*'];
const prefixes = Object.keys(chunkLimits).filter((k) => k !== '*');
for (const f of js) {
  const base = baseName(f);
  const key = prefixes.find((p) => base === p || (p.endsWith('*') && base.startsWith(p.slice(0, -1))));
  const limit = key ? chunkLimits[key] : fallback;
  const g = kb(measure(f).gzip);
  // yalnızca ihlal edenleri ve açıkça bütçelenenleri tabloya koy (238 satır gürültü olmasın)
  if (key || (limit !== undefined && g > limit)) check(`chunk ${base}`, g, limit);
}

if (asJson) {
  console.log(
    JSON.stringify({
      initialJs: initialJs.map((f) => ({ file: f, ...measure(f) })),
      initialCss: initialCss.map((f) => ({ file: f, ...measure(f) })),
      totals: {
        jsRaw: sum(js, 'raw'),
        jsGzip: sum(js, 'gzip'),
        jsBrotli: sum(js, 'brotli'),
        cssGzip: sum(css, 'gzip'),
        chunkCount: js.length,
      },
      rows,
    }),
  );
  process.exit(reportOnly || problems.length === 0 ? 0 : 1);
}

console.log('Paket boyutu (gzip -9, KB; brotli bilgi amaçlı)');
console.log('-'.repeat(78));
console.log(
  `girdi JS    : ${initialJs.map((f) => `${baseName(f)} ${kb(measure(f).gzip)}`).join(', ')}`,
);
console.log(
  `toplam      : JS ham ${kb(sum(js, 'raw'))} / gzip ${kb(sum(js, 'gzip'))} / brotli ${kb(sum(js, 'brotli'))}; CSS gzip ${kb(sum(css, 'gzip'))}; ${js.length} JS parçası`,
);
console.log('-'.repeat(78));
for (const r of rows) {
  console.log(
    `${r.ok ? 'OK  ' : 'ASIM'}  ${r.label.padEnd(44)} ${String(r.gzipKb).padStart(8)} KB  / ${r.limitKb ?? '-'} KB`,
  );
}
if (problems.length && !reportOnly) {
  console.error(`\nBUTCE ASILDI (${problems.length}):\n- ${problems.join('\n- ')}`);
  console.error('Bütçeyi bilinçli yükseltiyorsanız web/bundle-budget.json dosyasını gerekçeyle güncelleyin.');
  process.exit(1);
}
console.log(problems.length ? '\n(rapor kipi: bütçe aşımı yok sayıldı)' : '\nBütçe tamam.');
