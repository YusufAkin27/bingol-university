#!/usr/bin/env node
// Teknik SEO sağlık denetimi (dist/ üzerinde; bağımlılıksız). Genel ve katıdır: sayfa içi meta/JSON-LD (2. iş),
// performans ipuçları (3. iş) ve tarayıcı yüzeyi (robots, sitemap, yönlendirme, 404) birlikte doğrulanır.
//
//   npm run build && npm run check:seo                 # hata varsa çıkış kodu 1
//   node scripts/check-seo.mjs --strict                # uyarılar da hata sayılır (birleştirme sonrası / yayın kapısı)
//   node scripts/check-seo.mjs --dist dist --origin https://bukampus.com.tr
//   node scripts/check-seo.mjs --live https://bukampus.com.tr   # yayındaki siteye KİBAR (GET, ~25 istek) davranış denetimi
//
// Denetlenenler (kurallar docs/SEO_TECHNICAL.md bölüm 8'de):
//   sayfa: tek <title>, description, canonical (mutlak, tek biçim, kendine ya da var olan indekslenebilir sayfaya), robots meta,
//          hreflang (kendine gönderme, x-default, KARŞILIKLILIK, hedef sayfa var ve indekslenebilir), html lang/dir, TEK <h1>,
//          <noscript> içeriği, OG/Twitter (og:url=canonical, görsel var), JSON-LD geçerliliği, bozuk iç bağlantılar, http:// karışık içerik
//   sitemap: loc ↔ sayfa eşleşmesi (noindex/canonical dışı sayfa YOK, indekslenebilir sayfa eksik YOK), alternatifler = sayfa hreflang'ı,
//          lastmod geçerli/gelecekte değil/hepsi aynı değil
//   robots: Sitemap satırı, kapatılması gerekenler kapalı, açık olması gerekenler (sayfalar, /assets) Googlebot/Bingbot için açık
//   diğer: 404.html (noindex, h1, canonical yok), kök sayfa, security.txt, webmanifest, nginx yönetim parçası
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

/**
 * İçeriği yalnız Türkçe sunulan rotalar (hukuki belgeler: arka uçtan gelir, EN/AR çevirisi yok). Bunların en/ar sürümü
 * hreflang kümesinde ve sitemap'te OLMAMALI (src/seo/crawl.ts isTurkishOnly ile aynı kural; seo.test.ts eşitliği doğrular).
 */
export const TR_ONLY_PATH_RE = /^\/(privacy|terms|legal\/(kvkk|community-rules|explicit-consent|content-removal|retention))$/;

/** nginx'in kabuk (200) verdiği ama önrender dosyası olmayan geçerli dinamik iç yollar. */
export const DYNAMIC_PATH_RES = [
  /^\/(tr|en|ar)\/news\/\d+$/,
  /^\/(tr|en|ar)\/support\/track$/,
  /^\/(tr|en|ar)\/legal\/(terms|privacy|kvkk|community-rules|explicit-consent|cookies|content-removal|retention)$/,
];

const AI_TRAINING_BOTS = ['GPTBot', 'Google-Extended', 'CCBot', 'ClaudeBot', 'anthropic-ai', 'Applebot-Extended', 'Bytespider'];
const LANG_CODES = ['tr', 'en', 'ar'];

// ---------------------------------------------------------------- yardımcılar

const decode = (s) => s.replace(/&quot;/g, '"').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');

function attrsOf(tag) {
  const out = {};
  for (const m of tag.matchAll(/([A-Za-z_:][\w:.-]*)\s*=\s*"([^"]*)"/g)) out[m[1].toLowerCase()] = decode(m[2]);
  return out;
}

function tagsOf(html, name) {
  return [...html.matchAll(new RegExp(`<${name}\\b[^>]*>`, 'gi'))].map((m) => attrsOf(m[0]));
}

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}

const textOf = (html) =>
  decode(html.replace(/<script[\s\S]*?<\/script>/gi, ' ').replace(/<style[\s\S]*?<\/style>/gi, ' ').replace(/<[^>]+>/g, ' '))
    .replace(/\s+/g, ' ')
    .trim();

/** robots.txt ayrıştırıcı: { groups: [{agents:[], rules:[{allow, pattern}]}], sitemaps: [] } */
export function parseRobots(text) {
  const groups = [];
  const sitemaps = [];
  let cur = null;
  let lastWasAgent = false;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.replace(/#.*$/, '').trim();
    if (!line) continue;
    const i = line.indexOf(':');
    if (i < 0) continue;
    const key = line.slice(0, i).trim().toLowerCase();
    const val = line.slice(i + 1).trim();
    if (key === 'sitemap') {
      sitemaps.push(val);
    } else if (key === 'user-agent') {
      if (!cur || !lastWasAgent) {
        cur = { agents: [], rules: [] };
        groups.push(cur);
      }
      cur.agents.push(val.toLowerCase());
      lastWasAgent = true;
      continue;
    } else if ((key === 'allow' || key === 'disallow') && cur) {
      cur.rules.push({ allow: key === 'allow', pattern: val });
    }
    lastWasAgent = false;
  }
  return { groups, sitemaps };
}

function patternToRe(p) {
  const anchored = p.endsWith('$');
  const body = (anchored ? p.slice(0, -1) : p).replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*');
  return new RegExp(`^${body}${anchored ? '$' : ''}`);
}

/** Google kuralı: kullanıcı aracına en özgül grup; en uzun desen kazanır, eşitlikte Allow. */
export function robotsAllows(parsed, agent, path) {
  const a = agent.toLowerCase();
  const exact = parsed.groups.filter((g) => g.agents.some((x) => x !== '*' && a.includes(x)));
  const groups = exact.length ? exact : parsed.groups.filter((g) => g.agents.includes('*'));
  let best = null;
  for (const g of groups) {
    for (const r of g.rules) {
      if (!r.pattern) continue; // boş Disallow = her şey serbest
      if (patternToRe(r.pattern).test(path)) {
        if (!best || r.pattern.length > best.pattern.length || (r.pattern.length === best.pattern.length && r.allow)) best = r;
      }
    }
  }
  return best ? best.allow : true;
}

// ---------------------------------------------------------------- denetim çekirdeği

export function runChecks({ dist, origin, adminPath = '', today = new Date().toISOString().slice(0, 10) }) {
  const errors = [];
  const warnings = [];
  const err = (where, msg, cat = 'genel') => errors.push({ where, msg, cat });
  const warn = (where, msg, cat = 'genel') => warnings.push({ where, msg, cat });
  const stats = { pages: 0, indexable: 0, sitemapUrls: 0, links: 0 };

  const files = walk(dist);
  const rel = (f) => relative(dist, f).replace(/\\/g, '/');
  const fileSet = new Set(files.map(rel));

  // --- sayfaları topla ---
  const pages = new Map(); // mantıksal yol ('/tr/privacy', '/') -> sayfa
  for (const f of files) {
    const r = rel(f);
    if (!r.endsWith('index.html') && r !== '404.html') continue;
    const html = readFileSync(f, 'utf8');
    let path;
    if (r === '404.html') path = '/404.html';
    else if (r === 'index.html') path = '/';
    else path = '/' + r.replace(/\/index\.html$/, '');
    const headM = /<head[^>]*>([\s\S]*?)<\/head>/i.exec(html);
    const head = headM ? headM[1] : '';
    const robotsMeta = tagsOf(head, 'meta').filter((m) => (m.name || '').toLowerCase() === 'robots');
    const noindex = robotsMeta.some((m) => /noindex/i.test(m.content || ''));
    const canonicals = tagsOf(head, 'link').filter((l) => (l.rel || '').toLowerCase() === 'canonical');
    pages.set(path, {
      path,
      file: r,
      html,
      head,
      lang: /<html[^>]*\blang="([^"]*)"/i.exec(html)?.[1] ?? '',
      dir: /<html[^>]*\bdir="([^"]*)"/i.exec(html)?.[1] ?? '',
      noindex,
      robotsMeta,
      canonicals,
      canonical: canonicals[0]?.href ?? '',
      alternates: tagsOf(head, 'link').filter((l) => (l.rel || '').toLowerCase() === 'alternate' && l.hreflang),
      metas: tagsOf(head, 'meta'),
    });
  }
  stats.pages = pages.size;
  if (!pages.size) {
    err('dist', 'hiç sayfa bulunamadı; önce `npm run build` çalıştırın');
    return { errors, warnings, stats };
  }

  const urlOf = (path, langPrefix = true) => (path === '/' ? origin + '/' : origin + path);
  const byCanonical = new Map();
  const isRoot = (p) => p.path === '/';
  for (const p of pages.values()) {
    if (p.path === '/404.html' || isRoot(p) || p.noindex) continue;
    byCanonical.set(urlOf(p.path), p);
  }

  const isDynamicOk = (path) =>
    DYNAMIC_PATH_RES.some((re) => re.test(path)) || (adminPath && (path === adminPath || path.startsWith(adminPath + '/')));

  // --- sayfa başına denetimler ---
  const titleSeen = new Map();
  const descSeen = new Map();
  for (const p of pages.values()) {
    const where = p.path === '/404.html' ? '404.html' : p.path;
    const is404 = p.path === '/404.html';
    const isRootPage = isRoot(p);
    const indexable = !is404 && !p.noindex;
    if (indexable && !isRootPage) stats.indexable++;

    // title
    const titles = [...p.head.matchAll(/<title[^>]*>([\s\S]*?)<\/title>/gi)].map((m) => decode(m[1]).trim());
    if (titles.length !== 1) err(where, `tam olarak 1 <title> olmalı (${titles.length})`, 'baslik');
    else {
      if (!titles[0]) err(where, '<title> boş', 'baslik');
      if (titles[0].length > 70) warn(where, `<title> ${titles[0].length} karakter (>70; SERP'te kırpılır)`, 'baslik');
      if (indexable && !isRootPage) {
        const k = `${p.lang}|${titles[0]}`;
        if (titleSeen.has(k)) err(where, `<title> ${titleSeen.get(k)} ile aynı: "${titles[0]}"`, 'yinelenen');
        else titleSeen.set(k, where);
      }
    }

    // description
    const descs = p.metas.filter((m) => (m.name || '').toLowerCase() === 'description');
    if (descs.length !== 1) err(where, `tam olarak 1 meta description olmalı (${descs.length})`, 'aciklama');
    else {
      const d = (descs[0].content || '').trim();
      if (!d) err(where, 'meta description boş', 'aciklama');
      else {
        if (d.length < 50) warn(where, `description kısa (${d.length} < 50)`, 'aciklama');
        if (d.length > 175) warn(where, `description uzun (${d.length} > 175; kırpılır)`, 'aciklama');
        if (indexable && !isRootPage) {
          const k = `${p.lang}|${d}`;
          if (descSeen.has(k)) err(where, `description ${descSeen.get(k)} ile aynı`, 'yinelenen');
          else descSeen.set(k, where);
        }
      }
    }

    // charset / viewport / lang / dir
    if (!/<meta\s+charset="utf-8"/i.test(p.head)) err(where, '<meta charset="UTF-8"> yok', 'head');
    if (!p.metas.some((m) => (m.name || '').toLowerCase() === 'viewport')) err(where, 'viewport meta yok', 'head');
    const folderLang = is404 || isRootPage ? 'tr' : p.path.split('/')[1];
    if (p.lang !== folderLang) err(where, `<html lang="${p.lang}"> beklenen "${folderLang}"`, 'dil');
    const wantDir = folderLang === 'ar' ? 'rtl' : 'ltr';
    if (p.dir !== wantDir) err(where, `<html dir="${p.dir}"> beklenen "${wantDir}"`, 'dil');
    if (p.robotsMeta.length > 1) err(where, `birden çok robots meta (${p.robotsMeta.length}): çelişen yönerge riski`, 'robots');

    // h1 + noscript (JS kapalıyken içerik)
    const h1s = [...p.html.matchAll(/<h1\b[^>]*>([\s\S]*?)<\/h1>/gi)].map((m) => textOf(m[1]));
    // 404.html üç dilde ayrı bölüm taşır (her dilde bir h1); dizine girmediği için en az 1 yeterli
    if (is404 ? h1s.length < 1 : h1s.length !== 1) err(where, `${is404 ? 'en az 1' : 'tam olarak 1'} <h1> olmalı (${h1s.length})`, 'h1');
    else if (!h1s[0]) err(where, '<h1> boş', 'h1');
    const ns = [...p.html.matchAll(/<noscript>([\s\S]*?)<\/noscript>/gi)].map((m) => m[1]);
    const nsText = ns.map(textOf).join(' ');
    if (!ns.length) err(where, '<noscript> içeriği yok (JS kapalıyken boş sayfa)', 'noscript');
    else if (nsText.length < (is404 ? 40 : 120)) err(where, `<noscript> metni çok kısa (${nsText.length} karakter)`, 'noscript');

    // 404 sayfası
    if (is404) {
      if (!p.noindex) err(where, '404.html noindex olmalı', 'soft404');
      if (p.canonicals.length) err(where, '404.html canonical içermemeli', 'soft404');
      if (p.alternates.length) err(where, '404.html hreflang içermemeli', 'soft404');
      continue;
    }

    // canonical
    if (p.noindex) {
      if (p.alternates.length) err(where, 'noindex sayfada hreflang olmamalı', 'hreflang');
    } else if (p.canonicals.length !== 1) {
      err(where, `tam olarak 1 canonical olmalı (${p.canonicals.length})`, 'canonical');
    }
    if (p.canonical) {
      const c = p.canonical;
      if (!c.startsWith(origin + '/') && c !== origin) err(where, `canonical mutlak ${origin} adresi değil: ${c}`, 'canonical');
      if (/[?#]/.test(c)) err(where, `canonical sorgu/parça içeriyor: ${c}`, 'canonical');
      if (c !== origin + '/' && c.endsWith('/')) err(where, `canonical sondaki / ile bitiyor: ${c}`, 'canonical');
      if (c !== c.toLowerCase()) err(where, `canonical büyük harf içeriyor: ${c}`, 'canonical');
      const expected = isRootPage ? origin + '/tr' : urlOf(p.path);
      if (c !== expected) {
        const target = byCanonical.get(c);
        if (!target) err(where, `canonical (${c}) önrender edilmiş indekslenebilir bir sayfaya işaret etmiyor`, 'canonical');
        else if (!isRootPage) warn(where, `canonical başka sayfaya işaret ediyor: ${c} (sayfa sitemap'e girmemeli)`, 'canonical');
        if (isRootPage) err(where, `kök sayfanın canonical'ı ${expected} olmalı: ${c}`, 'canonical');
      }
    }

    // hreflang
    if (indexable && !isRootPage) {
      const seen = new Set();
      for (const a of p.alternates) {
        if (seen.has(a.hreflang)) err(where, `hreflang="${a.hreflang}" yinelenmiş`, 'hreflang');
        seen.add(a.hreflang);
        if (!/^(x-default|[a-z]{2}(-[A-Za-z]{2})?)$/.test(a.hreflang)) err(where, `geçersiz hreflang kodu: ${a.hreflang}`, 'hreflang');
        if (!a.href?.startsWith(origin + '/')) err(where, `hreflang href mutlak ${origin} adresi değil: ${a.href}`, 'hreflang');
      }
      if (!seen.has(p.lang)) err(where, `hreflang kendine gönderme (${p.lang}) yok`, 'hreflang');
      else if (p.alternates.find((a) => a.hreflang === p.lang)?.href !== p.canonical) {
        err(where, `hreflang="${p.lang}" canonical ile aynı değil`, 'hreflang');
      }
      if (!seen.has('x-default')) err(where, 'hreflang x-default yok', 'hreflang');
      for (const a of p.alternates) {
        if (a.href === p.canonical) continue;
        const target = byCanonical.get(a.href);
        if (!target) {
          err(where, `hreflang="${a.hreflang}" hedefi (${a.href}) var olan indekslenebilir bir sayfa değil`, 'hreflang');
          continue;
        }
        if (a.hreflang !== 'x-default' && target.lang !== a.hreflang) {
          err(where, `hreflang="${a.hreflang}" hedefi ${target.lang} dilinde (${a.href})`, 'hreflang');
        }
        // karşılıklılık: hedef sayfa bu sayfaya aynı dil koduyla geri bağlanmalı (x-default hariç)
        if (a.hreflang !== 'x-default') {
          const back = target.alternates.find((b) => b.href === p.canonical);
          if (!back || back.hreflang !== p.lang) err(where, `hreflang karşılıklı değil: ${a.href} bu sayfaya geri bağlanmıyor`, 'hreflang');
        }
      }
      // Türkçe-only kural
      const logical = p.path.replace(/^\/(tr|en|ar)/, '') || '/';
      if (TR_ONLY_PATH_RE.test(logical)) {
        const nonTr = p.alternates.filter((a) => a.hreflang !== 'x-default' && a.hreflang !== 'tr');
        if (p.lang !== 'tr') warn(where, 'içeriği yalnız Türkçe olan sayfanın en/ar sürümü indekslenebilir (noindex ya da canonical→tr olmalı)', 'tr-only');
        else if (nonTr.length) warn(where, `Türkçe-only sayfa en/ar hreflang listeliyor (${nonTr.map((a) => a.hreflang).join(',')})`, 'tr-only');
      }
    }

    // Open Graph / Twitter
    if (indexable && !isRootPage) {
      const m = (n, attr = 'property') => p.metas.find((x) => (x[attr] || '').toLowerCase() === n)?.content;
      for (const k of ['og:title', 'og:description', 'og:url', 'og:image', 'og:type', 'og:locale']) {
        if (!m(k)) err(where, `${k} yok`, 'og');
      }
      if (m('og:url') && m('og:url') !== p.canonical) err(where, `og:url canonical ile aynı değil (${m('og:url')})`, 'og');
      for (const k of ['og:image']) {
        const v = m(k);
        if (v) {
          if (!v.startsWith(origin + '/')) err(where, `${k} mutlak ${origin} adresi değil: ${v}`, 'og');
          else if (!fileSet.has(v.slice(origin.length + 1))) err(where, `${k} dosyası dist'te yok: ${v}`, 'og');
        }
      }
      if (!m('twitter:card', 'name')) err(where, 'twitter:card yok', 'og');
      if (m('og:locale') && m('og:locale') !== ({ tr: 'tr_TR', en: 'en_US', ar: 'ar_AR' }[p.lang] ?? m('og:locale'))) {
        warn(where, `og:locale (${m('og:locale')}) sayfa diliyle (${p.lang}) uyumsuz`, 'og');
      }
    }

    // JSON-LD
    for (const m of p.head.matchAll(/<script[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/gi)) {
      let data;
      try {
        data = JSON.parse(m[1]);
      } catch {
        err(where, 'JSON-LD geçerli JSON değil', 'jsonld');
        continue;
      }
      const stack = [data];
      while (stack.length) {
        const v = stack.pop();
        if (typeof v === 'string') {
          if (/^http:\/\//i.test(v)) err(where, `JSON-LD içinde http:// adres: ${v}`, 'jsonld');
        } else if (v && typeof v === 'object') stack.push(...Object.values(v));
      }
      const first = Array.isArray(data) ? data[0] : data;
      if (!first || !String(first['@context'] ?? '').includes('schema.org')) err(where, "JSON-LD @context schema.org değil", 'jsonld');
    }

    // bağlantılar ve varlıklar
    const refs = [];
    for (const a of tagsOf(p.html, 'a')) if (a.href) refs.push({ kind: 'a', url: a.href });
    for (const l of tagsOf(p.html, 'link')) if (l.href) refs.push({ kind: `link:${l.rel}`, url: l.href });
    for (const s of tagsOf(p.html, 'script')) if (s.src) refs.push({ kind: 'script', url: s.src });
    for (const { kind, url } of refs) {
      stats.links++;
      if (/^(mailto:|tel:|javascript:|#|data:)/i.test(url)) continue;
      if (/^http:\/\//i.test(url)) {
        err(where, `http:// bağlantı (karışık içerik): ${url}`, 'baglanti');
        continue;
      }
      let path = url;
      if (url.startsWith(origin + '/') || url === origin) path = url.slice(origin.length) || '/';
      else if (/^https?:\/\//i.test(url) || url.startsWith('//')) continue; // dış bağlantı
      path = path.replace(/[?#].*$/, '');
      if (!path.startsWith('/')) {
        if (kind === 'a') warn(where, `göreli bağlantı: ${url}`, 'baglanti');
        continue;
      }
      const isStatic = /^\/(assets|fonts|brand|\.well-known)\//.test(path) || /\.[a-z0-9]{2,12}$/i.test(path);
      if (isStatic) {
        if (!fileSet.has(path.slice(1))) err(where, `bozuk ${kind} bağlantısı (dosya yok): ${url}`, 'baglanti');
        continue;
      }
      if (kind === 'a' || kind.startsWith('link:canonical') || kind.startsWith('link:alternate')) {
        if (path.length > 1 && path.endsWith('/')) err(where, `kanonik olmayan bağlantı (sondaki /): ${url}`, 'baglanti');
        if (path !== path.toLowerCase() && !/^\/(tr|en|ar)\/legal\//i.test(path)) err(where, `büyük harfli bağlantı: ${url}`, 'baglanti');
      }
      const logical = path.length > 1 ? path.replace(/\/+$/, '') : path;
      if (logical === '/') continue;
      if (pages.has(logical) || isDynamicOk(logical)) continue;
      // eski öneksiz adresler nginx'te 301 alır; sayfalar kendi içinde onlara bağlanmamalı
      err(where, `bozuk iç bağlantı (önrender sayfası/dinamik rota değil): ${url}`, 'baglanti');
    }
  }

  // --- sitemap ---
  const smPath = join(dist, 'sitemap.xml');
  if (!existsSync(smPath)) err('sitemap.xml', 'dosya yok', 'sitemap');
  else {
    const xml = readFileSync(smPath, 'utf8');
    if (!xml.includes('xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"')) err('sitemap.xml', 'sitemap xmlns yok', 'sitemap');
    if (/\bhreflang=/.test(xml) && !xml.includes('xmlns:xhtml="http://www.w3.org/1999/xhtml"')) err('sitemap.xml', 'xhtml xmlns yok', 'sitemap');
    const blocks = [...xml.matchAll(/<url>([\s\S]*?)<\/url>/g)].map((m) => m[1]);
    stats.sitemapUrls = blocks.length;
    if (blocks.length > 50000) err('sitemap.xml', `50.000 URL sınırı aşıldı (${blocks.length})`, 'sitemap');
    const seenLoc = new Set();
    const lastmods = [];
    const inSitemap = new Set();
    for (const b of blocks) {
      const loc = decode(/<loc>([^<]+)<\/loc>/.exec(b)?.[1] ?? '').trim();
      const where = `sitemap ${loc || '?'}`;
      if (!loc) {
        err('sitemap.xml', '<loc> boş bir <url> bloğu', 'sitemap');
        continue;
      }
      if (seenLoc.has(loc)) err(where, 'yinelenen <loc>', 'sitemap');
      seenLoc.add(loc);
      inSitemap.add(loc);
      if (!loc.startsWith(origin + '/')) err(where, `loc mutlak ${origin} adresi değil`, 'sitemap');
      if (loc.endsWith('/') && loc !== origin + '/') err(where, 'loc sondaki / ile bitiyor', 'sitemap');
      if (/[?#]/.test(loc)) err(where, 'loc sorgu/parça içeriyor', 'sitemap');
      const page = byCanonical.get(loc);
      if (!page) {
        const any = [...pages.values()].find((x) => urlOf(x.path) === loc);
        if (any?.noindex) err(where, 'noindex sayfa sitemap içinde', 'sitemap');
        else if (any) err(where, 'sayfa canonical başka adreste; sitemap yalnız kanonik adres listelemeli', 'sitemap');
        else err(where, 'loc önrender edilmiş bir sayfaya karşılık gelmiyor', 'sitemap');
        continue;
      }
      const lm = /<lastmod>([^<]+)<\/lastmod>/.exec(b)?.[1];
      if (!lm) err(where, 'lastmod yok', 'lastmod');
      else {
        lastmods.push(lm);
        if (!/^\d{4}-\d{2}-\d{2}(T[\d:.+Z-]+)?$/.test(lm) || Number.isNaN(Date.parse(lm))) err(where, `geçersiz lastmod: ${lm}`, 'lastmod');
        else if (lm.slice(0, 10) > today) err(where, `lastmod gelecekte: ${lm}`, 'lastmod');
        else if (lm < '2024-01-01') err(where, `lastmod gerçek dışı eski: ${lm}`, 'lastmod');
      }
      // alternatifler sayfanın head hreflang kümesiyle birebir aynı olmalı
      const smAlts = [...b.matchAll(/<xhtml:link\b[^>]*>/g)].map((m) => attrsOf(m[0]));
      const key = (a) => `${a.hreflang}=${a.href}`;
      const smSet = new Set(smAlts.map(key));
      const headSet = new Set(page.alternates.map(key));
      const onlyHead = [...headSet].filter((x) => !smSet.has(x));
      const onlySm = [...smSet].filter((x) => !headSet.has(x));
      if (onlyHead.length || onlySm.length) {
        const logical = page.path.replace(/^\/(tr|en|ar)/, '') || '/';
        const trOnlyDiff = TR_ONLY_PATH_RE.test(logical) && onlySm.length === 0;
        (trOnlyDiff ? warn : err)(
          where,
          `sitemap alternatifleri sayfa hreflang'ıyla uyuşmuyor (yalnız sayfada: ${onlyHead.join(' ') || '-'}; yalnız sitemap'te: ${onlySm.join(' ') || '-'})`,
          trOnlyDiff ? 'tr-only' : 'sitemap',
        );
      }
    }
    for (const [url, p] of byCanonical) {
      if (inSitemap.has(url)) continue;
      const logical = p.path.replace(/^\/(tr|en|ar)/, '') || '/';
      if (TR_ONLY_PATH_RE.test(logical) && p.lang !== 'tr') warn(`sitemap ${url}`, 'indekslenebilir sayfa sitemap\'te yok (Türkçe-only en/ar: noindex yapılmalı)', 'tr-only');
      else err(`sitemap ${url}`, "indekslenebilir sayfa sitemap'te yok", 'sitemap');
    }
    if (lastmods.length >= 10 && new Set(lastmods).size === 1) {
      warn('sitemap.xml', `tüm lastmod değerleri aynı (${lastmods[0]}): sayfa başına gerçek değişim tarihi kullanılmalı (seo-lastmod.json)`, 'lastmod');
    }
  }

  // --- robots.txt ---
  const rbPath = join(dist, 'robots.txt');
  if (!existsSync(rbPath)) err('robots.txt', 'dosya yok', 'robots');
  else {
    const raw = readFileSync(rbPath, 'utf8');
    if (raw.charCodeAt(0) === 0xfeff) err('robots.txt', 'BOM içeriyor', 'robots');
    const rb = parseRobots(raw);
    if (!rb.sitemaps.includes(origin + '/sitemap.xml')) err('robots.txt', `Sitemap: ${origin}/sitemap.xml satırı yok`, 'robots');
    if (!rb.groups.some((g) => g.agents.includes('*'))) err('robots.txt', "User-agent: * grubu yok", 'robots');
    for (const agent of ['*', 'Googlebot', 'Bingbot', 'Googlebot-Image']) {
      for (const p of ['/', '/tr', '/assets/x.js', '/assets/x.css', '/fonts/x.woff2', '/og.png', '/sitemap.xml']) {
        if (!robotsAllows(rb, agent, p)) err('robots.txt', `${agent} için ${p} engelli (içerik ve görsel/JS/CSS taranabilmeli)`, 'robots');
      }
    }
    for (const p of ['/api/news', '/files/x.png', '/admin', '/admin/users', '/ws', '/support/track?token=a', '/tr/support/track?token=a']) {
      if (robotsAllows(rb, 'Googlebot', p)) err('robots.txt', `Googlebot için ${p} AÇIK; kapalı olmalı`, 'robots');
    }
    for (const u of inSitemapList(dist)) {
      const path = u.slice(origin.length) || '/';
      for (const agent of ['Googlebot', 'Bingbot']) {
        if (!robotsAllows(rb, agent, path)) err('robots.txt', `${agent} sitemap adresini engelliyor: ${path}`, 'robots');
      }
    }
    if (adminPath && adminPath !== '/admin' && raw.includes(adminPath)) err('robots.txt', 'gizli yönetim yolu robots.txt içinde açıklanmış', 'robots');
    const blocked = AI_TRAINING_BOTS.filter((b) => !robotsAllows(rb, b, '/'));
    stats.aiBlocked = blocked;
  }

  // --- diğer dosyalar ---
  const sec = join(dist, '.well-known', 'security.txt');
  if (existsSync(sec) && /\{\{ORIGIN\}\}|ALAN-ADI/.test(readFileSync(sec, 'utf8'))) err('security.txt', 'yer tutucu kalmış', 'diger');
  const wm = join(dist, 'site.webmanifest');
  if (!existsSync(wm)) err('site.webmanifest', 'dosya yok', 'diger');
  else {
    try {
      const m = JSON.parse(readFileSync(wm, 'utf8'));
      for (const i of m.icons ?? []) if (i.src && !fileSet.has(i.src.replace(/^\//, ''))) err('site.webmanifest', `simge dosyası yok: ${i.src}`, 'diger');
    } catch {
      err('site.webmanifest', 'geçerli JSON değil', 'diger');
    }
  }
  if (!fileSet.has('_nginx-generated.conf')) err('_nginx-generated.conf', 'yönetim konumu parçası üretilmemiş (Dockerfile bu dosyayı taşır)', 'diger');
  for (const f of files) {
    if (/\.(html|xml|txt)$/.test(f) && /ALAN-ADI|\{\{ORIGIN\}\}/.test(readFileSync(f, 'utf8'))) err(rel(f), 'yer tutucu kalmış', 'diger');
  }
  return { errors, warnings, stats };
}

function inSitemapList(dist) {
  const p = join(dist, 'sitemap.xml');
  if (!existsSync(p)) return [];
  return [...readFileSync(p, 'utf8').matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => decode(m[1]));
}

// ---------------------------------------------------------------- canlı davranış denetimi (yalnız GET, kibar)

async function liveChecks(base) {
  const errors = [];
  const warnings = [];
  const u = base.replace(/\/+$/, '');
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const get = async (path, host) => {
    const url = host ? u.replace(/\/\/[^/]+/, `//${host}`) + path : u + path;
    const res = await fetch(url, { redirect: 'manual', headers: { 'user-agent': 'bu-check-seo/1 (+kendi sitemiz)' } });
    await res.arrayBuffer().catch(() => undefined);
    await sleep(150);
    return res;
  };
  const expect = async (path, status, extra = {}) => {
    try {
      const r = await get(path, extra.host);
      const loc = r.headers.get('location') ?? '';
      let msg = '';
      if (r.status !== status) msg = `durum ${r.status} (beklenen ${status})`;
      else if (extra.location && !loc.endsWith(extra.location)) msg = `Location "${loc}" (beklenen …${extra.location})`;
      else if (extra.header) {
        const [h, re] = extra.header;
        if (!new RegExp(re, 'i').test(r.headers.get(h) ?? '')) msg = `${h}: "${r.headers.get(h) ?? ''}" (beklenen /${re}/)`;
      } else if (extra.type && !(r.headers.get('content-type') ?? '').includes(extra.type)) msg = `content-type ${r.headers.get('content-type')}`;
      if (msg) errors.push({ where: `${extra.host ?? ''}${path}`, msg, cat: 'canli' });
    } catch (e) {
      errors.push({ where: path, msg: `istek başarısız: ${e.message}`, cat: 'canli' });
    }
  };
  await expect('/', 200);
  await expect('/tr', 200, { header: ['x-robots-tag', 'max-image-preview'] });
  await expect('/tr/', 301, { location: '/tr' });
  await expect('/TR', 301, { location: '/tr' });
  await expect('/index.html', 301, { location: '/' });
  await expect('/tr/privacy/', 301, { location: '/tr/privacy' });
  await expect('/tr//privacy', 301, { location: '/tr/privacy' });
  await expect('/privacy', 301, { location: '/tr/privacy' });
  await expect('/zzz-yok', 404);
  await expect('/tr/zzz-yok', 404);
  await expect('/robots.txt', 200, { type: 'text/plain' });
  await expect('/sitemap.xml', 200, { type: 'xml' });
  await expect('/admin/login', 200, { header: ['x-robots-tag', 'noindex'] });
  await expect('/tr/support/track?token=x', 200, { header: ['x-robots-tag', 'noindex'] });
  await expect('/en/news/1', 200, { header: ['x-robots-tag', 'noindex'] });
  await expect('/api/news', 200, { header: ['x-robots-tag', 'noindex'] });
  await expect('/.env', 404);
  await expect('/tr', 301, { host: u.replace(/^https?:\/\/(www\.)?/, 'www.'), location: '/tr' });
  // assetlinks: dosya yoksa 404, varsa application/json ve yönlendirmesiz 200
  try {
    const r = await get('/.well-known/assetlinks.json');
    if (r.status === 200 && !(r.headers.get('content-type') ?? '').includes('application/json')) {
      errors.push({ where: '/.well-known/assetlinks.json', msg: `200 ama content-type ${r.headers.get('content-type')}`, cat: 'canli' });
    } else if (![200, 404].includes(r.status)) errors.push({ where: '/.well-known/assetlinks.json', msg: `durum ${r.status}`, cat: 'canli' });
  } catch (e) {
    errors.push({ where: '/.well-known/assetlinks.json', msg: e.message, cat: 'canli' });
  }
  // sitemap'ten birkaç örnek adres 200 ve canonical eşleşmesi
  try {
    const xml = await (await fetch(`${u}/sitemap.xml`)).text();
    const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
    if (!locs.length) errors.push({ where: '/sitemap.xml', msg: 'canlı sitemap boş', cat: 'canli' });
    for (const loc of locs.filter((_, i) => i % Math.max(1, Math.floor(locs.length / 5)) === 0).slice(0, 5)) {
      const res = await fetch(loc, { redirect: 'manual' });
      const body = await res.text();
      await sleep(150);
      const canon = /<link[^>]*rel="canonical"[^>]*href="([^"]+)"/.exec(body)?.[1];
      if (res.status !== 200) errors.push({ where: loc, msg: `sitemap adresi ${res.status}`, cat: 'canli' });
      else if (canon !== loc) errors.push({ where: loc, msg: `canonical ${canon} ≠ loc`, cat: 'canli' });
    }
  } catch (e) {
    errors.push({ where: '/sitemap.xml', msg: e.message, cat: 'canli' });
  }
  return { errors, warnings };
}

// ---------------------------------------------------------------- CLI

function report({ errors, warnings, stats }, strict) {
  const group = (list, label) => {
    if (!list.length) return;
    console.log(`\n${label} (${list.length})`);
    const byCat = new Map();
    for (const i of list) byCat.set(i.cat, [...(byCat.get(i.cat) ?? []), i]);
    for (const [cat, items] of byCat) {
      console.log(`  [${cat}] ${items.length}`);
      for (const i of items.slice(0, 25)) console.log(`    - ${i.where}: ${i.msg}`);
      if (items.length > 25) console.log(`    … ve ${items.length - 25} tane daha`);
    }
  };
  group(errors, 'HATA');
  group(warnings, strict ? 'UYARI (strict: hata sayılır)' : 'UYARI');
  if (stats) {
    console.log(
      `\ncheck-seo: ${stats.pages} sayfa (${stats.indexable} indekslenebilir), sitemap ${stats.sitemapUrls} URL, ${stats.links} bağlantı denetlendi` +
        (stats.aiBlocked?.length ? `; robots: eğitim botları kapalı (${stats.aiBlocked.join(', ')})` : ''),
    );
  }
  const failed = errors.length + (strict ? warnings.length : 0);
  console.log(failed ? `\ncheck-seo BAŞARISIZ: ${errors.length} hata, ${warnings.length} uyarı` : `\ncheck-seo tamam: 0 hata, ${warnings.length} uyarı`);
  return failed ? 1 : 0;
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (name) => {
    const i = args.indexOf(name);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const root = join(dirname(fileURLToPath(import.meta.url)), '..');
  const strict = args.includes('--strict');
  const live = opt('--live');
  if (live) {
    const r = await liveChecks(live);
    process.exit(report({ ...r, stats: undefined }, strict));
  }
  const dist = opt('--dist') ? opt('--dist') : join(root, 'dist');
  const origin = (opt('--origin') || process.env.PUBLIC_WEB_URL || process.env.VITE_PUBLIC_URL || 'https://bukampus.com.tr').replace(/\/+$/, '');
  const rawAdmin = (process.env.VITE_ADMIN_PATH || '').trim().replace(/\/+$/, '');
  const adminPath = rawAdmin ? (rawAdmin.startsWith('/') ? rawAdmin : `/${rawAdmin}`) : '/admin';
  if (!existsSync(dist)) {
    console.error(`check-seo: ${dist} yok; önce \`npm run build\``);
    process.exit(1);
  }
  process.exit(report(runChecks({ dist, origin, adminPath }), strict));
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  await main();
}
