/**
 * Tarayıcı yüzeyi (robots, sitemap, lastmod, nginx URL hijyeni) sözleşme testleri. check-seo.mjs'in kendisi de burada
 * sentetik bir dist üzerinde sınanır: bozuk girdiyi yakalayamayan bir denetim güven vermez.
 */
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { afterAll, describe, expect, it } from 'vitest';
import { DYNAMIC_PATH_RES, TR_ONLY_PATH_RE, parseRobots, robotsAllows, runChecks } from '../../scripts/check-seo.mjs';
import { LANGS } from '../i18n/lang';
import { AI_TRAINING_BOTS, buildRobots, buildSitemap, contentHash, isTurkishOnly, sitemapLangs } from './crawl';
import { SEO_END, SEO_START, prerender, routeSignature } from './prerender';
import { ROUTE_META } from './routeMeta';

const ORIGIN = 'https://example.org';
const NGINX = readFileSync(join(process.cwd(), 'nginx.conf'), 'utf-8');

describe('Türkçe-only kuralı', () => {
  it('check-seo.mjs düzenli ifadesi routeMeta legalType ile birebir aynı rotaları kapsar', () => {
    for (const r of ROUTE_META) {
      expect(TR_ONLY_PATH_RE.test(r.path), r.id).toBe(isTurkishOnly(r));
    }
  });

  it('sitemapLangs: hukuki belge yalnız tr, diğerleri üç dil', () => {
    expect(sitemapLangs(ROUTE_META.find((r) => r.id === 'privacy')!)).toEqual(['tr']);
    expect(sitemapLangs(ROUTE_META.find((r) => r.id === 'faq')!)).toEqual(['tr', 'en', 'ar']);
  });

  it('sitemap: Türkçe-only sayfanın en/ar adresi ve alternatifi yok', () => {
    const xml = buildSitemap(ORIGIN, '2026-01-01');
    expect(xml).toContain(`<loc>${ORIGIN}/tr/privacy</loc>`);
    expect(xml).not.toContain(`${ORIGIN}/en/privacy`);
    expect(xml).not.toContain(`${ORIGIN}/ar/legal/kvkk`);
    expect(xml).toContain(`<loc>${ORIGIN}/ar/faq</loc>`);
  });
});

describe('sitemap lastmod', () => {
  it('sayfa başına çözücü kullanılır ve hepsi aynı değildir', () => {
    const xml = buildSitemap(ORIGIN, (id, lang) => (id === 'home' && lang === 'tr' ? '2026-02-03' : '2026-01-01'));
    expect(xml).toMatch(/<loc>https:\/\/example\.org\/tr<\/loc>\s*<lastmod>2026-02-03<\/lastmod>/);
    expect(xml).toMatch(/<loc>https:\/\/example\.org\/en<\/loc>\s*<lastmod>2026-01-01<\/lastmod>/);
  });

  it('içerik imzası içerik değişince değişir, aynı girdide kararlıdır', () => {
    const meta = ROUTE_META.find((r) => r.id === 'faq')!;
    expect(routeSignature(meta, 'tr', ORIGIN)).toBe(routeSignature(meta, 'tr', ORIGIN));
    expect(routeSignature(meta, 'tr', ORIGIN)).not.toBe(routeSignature(meta, 'en', ORIGIN));
    expect(routeSignature(meta, 'tr', ORIGIN)).not.toBe(routeSignature(meta, 'tr', 'https://other.example'));
    expect(contentHash('a')).not.toBe(contentHash('b'));
  });

  it('prerender() her rota×dil için imza döndürür ve çözücüyü sitemap\'e uygular', () => {
    const template = `<!doctype html><html lang="tr"><head><meta charset="UTF-8" />${SEO_START}${SEO_END}</head><body><div id="root"></div></body></html>`;
    const r = prerender({ template, origin: ORIGIN, buildDate: '2026-11-01', lastmod: () => '2026-03-04' });
    expect(r.signatures.size).toBe(ROUTE_META.length * LANGS.length);
    expect(r.files.get('sitemap.xml')).toContain('<lastmod>2026-03-04</lastmod>');
  });
});

describe('robots.txt', () => {
  const rb = parseRobots(buildRobots(ORIGIN));

  it('arama motorları sayfaları, JS/CSS ve görselleri tarayabilir', () => {
    for (const agent of ['Googlebot', 'Bingbot', 'Googlebot-Image', '*']) {
      for (const p of ['/', '/tr', '/en/faq', '/assets/index-abc.js', '/fonts/inter.woff2', '/og.png', '/sitemap.xml']) {
        expect(robotsAllows(rb, agent, p), `${agent} ${p}`).toBe(true);
      }
    }
  });

  it('api, files, ws, yönetim ve destek izleme kapalıdır', () => {
    for (const p of ['/api/news', '/files/a.png', '/ws', '/admin', '/admin/users', '/support/track?token=a', '/tr/support/track?token=a', '/en/support/track']) {
      expect(robotsAllows(rb, 'Googlebot', p), p).toBe(false);
    }
  });

  it('yalnız eğitim botları tümüyle kapalıdır; arama/yanıt botları serbesttir', () => {
    for (const b of AI_TRAINING_BOTS) expect(robotsAllows(rb, b, '/tr'), b).toBe(false);
    for (const b of ['OAI-SearchBot', 'ChatGPT-User', 'PerplexityBot', 'Claude-SearchBot', 'Yandex', 'DuckDuckBot']) {
      expect(robotsAllows(rb, b, '/tr'), b).toBe(true);
    }
  });

  it('Sitemap satırı mutlak, dosya ASCII (BOM yok)', () => {
    const txt = buildRobots(ORIGIN);
    expect(rb.sitemaps).toEqual([`${ORIGIN}/sitemap.xml`]);
    expect(txt.charCodeAt(0)).not.toBe(0xfeff);
    // eslint-disable-next-line no-control-regex
    expect(/^[\x00-\x7f]*$/.test(txt)).toBe(true);
  });
});

describe('nginx.conf URL hijyeni', () => {
  it('kanonik olmayan biçimler için harita kuralları var (çift /, /index.html, sondaki /, büyük harf dil)', () => {
    expect(NGINX).toContain('map $request_uri $site_canon');
    expect(NGINX).toContain('index\\.html');
    expect(NGINX).toContain('map $request_uri $lang_case_fix');
    expect(NGINX).toContain('map $request_uri $legacy_target');
    // her dil önekli konum kanonik yönlendirmeyi uygular
    const locs = NGINX.match(/location ~\*? \^\/\(tr\|en\|ar\)[^\n]*\{[\s\S]*?\n {4}\}/g) ?? [];
    expect(locs.length).toBeGreaterThanOrEqual(4);
    for (const l of locs) expect(l, l.slice(0, 60)).toContain('if ($site_canon) { return 301 $site_canon; }');
  });

  it('yönlendirmelerde çözülmüş $uri değil ham $request_uri kullanılır (satır sonu enjeksiyonu)', () => {
    const returns = NGINX.match(/return 30[12] [^;]*;/g) ?? [];
    expect(returns.length).toBeGreaterThan(5);
    for (const r of returns) expect(r, r).not.toMatch(/\$uri\b/);
  });

  it('bilinmeyen kök yollar 404 olur: son konum try_files $uri =404, SPA düşüşü (/index.html) yok', () => {
    const last = NGINX.slice(NGINX.lastIndexOf('    location / {'));
    expect(last).toContain('try_files $uri =404;');
    expect(last).not.toContain('/index.html');
  });

  it('/index.html köke 301; kök dosyası doğrudan sunulur (yönlendirme döngüsü yok)', () => {
    expect(NGINX).toMatch(/location = \/index\.html \{\s*return 301 \/;\s*\}/);
    expect(NGINX).toMatch(/location = \/ \{[\s\S]*?try_files \/index\.html =404;/);
  });

  it('api/files/ws konumları ^~ ile regex konumlarından korunur', () => {
    for (const p of ['/api/', '/files/', '/ws']) expect(NGINX).toContain(`location ^~ ${p}`);
  });

  it('yönetim parçası include edilir; noindex başlıkları: api/files/ws, haber ayrıntısı, destek izleme, 404', () => {
    expect(NGINX).toContain('include /etc/nginx/snippets/generated-locations.conf;');
    expect((NGINX.match(/X-Robots-Tag "noindex, nofollow" always;/g) ?? []).length).toBeGreaterThanOrEqual(5);
    const news = NGINX.slice(NGINX.indexOf('location ~ ^/(tr|en|ar)/news/[0-9]+/?$'));
    expect(news.slice(0, 500)).toContain('X-Robots-Tag "noindex, follow" always;');
  });

  it('uygulama bağlantısı doğrulama dosyaları: JSON, yoksa yalın 404 (SPA HTML değil)', () => {
    for (const p of ['/.well-known/assetlinks.json', '/.well-known/apple-app-site-association', '/apple-app-site-association']) {
      const at = NGINX.indexOf(`location = ${p} {`);
      expect(at, p).toBeGreaterThan(0);
      const block = NGINX.slice(at, at + 400);
      expect(block).toContain('default_type application/json;');
      expect(block).toContain('error_page 404 = @plain404;');
      expect(block).not.toContain('index.html');
    }
  });

  it('menü/haber ve sitemap: gece yenileme katmanı ($dyn_root) varsa o, yoksa derleme çıktısı; katman yoksa hata yok', () => {
    const menu = NGINX.slice(NGINX.indexOf('location ~ ^/(tr|en|ar)/(menu|news)/?$'));
    expect(menu.slice(0, 600)).toContain('root $dyn_root;');
    expect(menu.slice(0, 600)).toContain('try_files /$1/$2/index.html @static_html;');
    expect(NGINX).toContain('location @static_html {');
    expect(NGINX).toContain('try_files /sitemap.xml @static_sitemap;');
    // $dyn_root derlemede üretilen parçadan gelir; sabit yazılmaz
    expect(NGINX).not.toMatch(/set \$dyn_root/);
  });

  it('sitemap.xml application/xml, robots.txt text/plain, gizli dosyalar 404', () => {
    expect(NGINX).toMatch(/location = \/sitemap\.xml \{\s*types \{ \}\s*default_type application\/xml;/);
    expect(NGINX).toMatch(/location = \/robots\.txt \{\s*default_type text\/plain;/);
    expect(NGINX).toContain('location ~ /\\.(?!well-known/)');
  });
});

describe('check-seo.mjs (sentetik dist)', () => {
  const root = mkdtempSync(join(tmpdir(), 'seo-dist-'));
  afterAll(() => rmSync(root, { recursive: true, force: true }));
  const template = `<!doctype html>
<html lang="tr" dir="ltr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    ${SEO_START}
    <title>BÜ Kampüs</title>
    ${SEO_END}
    <script type="module" src="/assets/index-abc.js"></script>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>`;

  function makeDist(name: string): string {
    const dist = join(root, name);
    const r = prerender({ template, origin: ORIGIN, buildDate: '2026-10-31', lastmod: (id) => (id === 'home' ? '2026-10-30' : '2026-10-31') });
    const put = (rel: string, body: string) => {
      mkdirSync(dirname(join(dist, rel)), { recursive: true });
      writeFileSync(join(dist, rel), body);
    };
    for (const [rel, body] of r.files) put(rel, body);
    put('assets/index-abc.js', '//');
    put('og.png', 'png');
    put('site.webmanifest', '{"icons":[]}');
    put('_nginx-generated.conf', '# x\n');
    return dist;
  }
  const run = (dist: string) => runChecks({ dist, origin: ORIGIN, adminPath: '/admin', today: '2026-11-01' });

  it('temiz çıktıda hata yok (yalnız Türkçe-only uyarıları olabilir)', () => {
    const { errors, warnings } = run(makeDist('ok'));
    expect(errors).toEqual([]);
    // Başka uyarı kategorisi (örn. kısa description) bu testin konusu değil; tr-only dışı yeni kategori çıkarsa gözden geçirilsin
    expect(new Set(warnings.map((w) => w.cat)).size).toBeLessThanOrEqual(4);
  });

  it('bozuk girdileri yakalar: ikinci h1, canonical yok, bozuk iç bağlantı, noindex sayfa sitemap içinde, http bağlantı', () => {
    const dist = makeDist('bad');
    const faq = join(dist, 'tr', 'faq', 'index.html');
    let html = readFileSync(faq, 'utf-8');
    html = html.replace('</main></noscript>', '<h1>ikinci</h1><a href="/tr/yok-boyle-sayfa">x</a><a href="http://evil.test/">y</a></main></noscript>');
    html = html.replace(/<link rel="canonical"[^>]*>/, '');
    writeFileSync(faq, html);
    const about = join(dist, 'en', 'about', 'index.html');
    writeFileSync(about, readFileSync(about, 'utf-8').replace('<title>', '<meta name="robots" content="noindex" data-pre="1" />\n<title>'));
    const { errors } = run(dist);
    const text = errors.map((e) => `${e.where} ${e.cat} ${e.msg}`).join('\n');
    expect(text).toMatch(/\/tr\/faq .*h1/);
    expect(text).toMatch(/\/tr\/faq .*canonical/);
    expect(text).toMatch(/\/tr\/faq .*bozuk iç bağlantı.*yok-boyle-sayfa/);
    expect(text).toMatch(/\/tr\/faq .*http:\/\/ bağlantı/);
    expect(text).toMatch(/sitemap .*\/en\/about.*noindex sayfa sitemap içinde/);
  });

  it('hreflang karşılıksızlığını ve robots engelini yakalar', () => {
    const dist = makeDist('hreflang');
    const f = join(dist, 'ar', 'faq', 'index.html');
    writeFileSync(f, readFileSync(f, 'utf-8').replace(/<link rel="alternate" hreflang="tr"[^>]*>/, ''));
    writeFileSync(join(dist, 'robots.txt'), 'User-agent: *\nDisallow: /\n');
    const { errors } = run(dist);
    const text = errors.map((e) => `${e.where} ${e.cat} ${e.msg}`).join('\n');
    expect(text).toMatch(/\/tr\/faq .*karşılıklı değil/);
    expect(text).toMatch(/robots\.txt .*engelli/);
    expect(text).toMatch(/robots\.txt .*Sitemap/);
  });

  it('DYNAMIC_PATH_RES haber kimliği, destek izleme ve hukuki tür yollarını kabul eder', () => {
    for (const p of ['/tr/news/12', '/en/support/track', '/ar/legal/kvkk']) {
      expect(DYNAMIC_PATH_RES.some((re) => re.test(p)), p).toBe(true);
    }
    expect(DYNAMIC_PATH_RES.some((re) => re.test('/tr/news/abc'))).toBe(false);
  });
});
