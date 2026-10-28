/**
 * Derleme zamanı SEO önrender (saf işlevler; dosya yazımı scripts/prerender.mjs'te).
 * Her herkese açık rota × dil için `dist/<lang>/<yol>/index.html` üretir: <title>, description, canonical, hreflang,
 * Open Graph, Twitter kartı, JSON-LD ve <noscript> içinde sayfanın temel metni. SPA kabuğu aynı HTML'e yüklenir
 * (hydrate yok; createRoot mevcut kök içeriğini değiştirir). Headless tarayıcı gerekmez: metinler routeMeta + sözlükten gelir.
 */
import type { TranslationKey } from '../i18n';
import { dictionaries } from '../i18n/all'; // önrender tüm dilleri eşzamanlı ister (çalışma zamanı paketine girmez)
import { LANGS, dirOf, type Lang } from '../i18n/lang';
import { buildNewFaq } from '../pages/site/components/newFaq';
import { breadcrumbLd, faqLd, mobileAppLd, organizationLd } from '../pages/site/components/jsonLd';
import { buildHeadModel, normalizeOrigin, pageUrl, type HeadModel } from './headModel';
import { ROUTE_META, resolveMeta, type RouteMeta } from './routeMeta';

export const SEO_START = '<!--seo:start-->';
export const SEO_END = '<!--seo:end-->';
/** Kök kap; yeniden çalıştırmada önceki noscript çıktısı da eşleşir (betik tekrar çalıştırılabilir). */
const ROOT_DIV = /<div id="root">(?:<noscript>[\s\S]*?<\/noscript>)?<\/div>/;

const esc = (s: string): string =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** JSON-LD gövdesi: `</script>` kapatmasını ve HTML ayrıştırmasını bozmayacak biçimde. */
const jsonForScript = (o: unknown): string => JSON.stringify(o).replace(/</g, '\\u003c');

const tr = (lang: Lang) => {
  const dict = dictionaries[lang] as Record<string, string>;
  const fallback = dictionaries.tr as Record<string, string>;
  return (key: string): string => dict[key] ?? fallback[key] ?? key;
};

function serializeHead(model: HeadModel, ld: unknown[]): string {
  const out: string[] = [`<title>${esc(model.title)}</title>`];
  for (const m of model.metas) out.push(`<meta ${m.attr}="${esc(m.key)}" content="${esc(m.content)}" data-pre="1" />`);
  for (const l of model.links) {
    out.push(
      `<link rel="${l.rel}"${l.hreflang ? ` hreflang="${l.hreflang}"` : ''} href="${esc(l.href)}" data-pre="1" />`,
    );
  }
  for (const o of ld) out.push(`<script type="application/ld+json" data-pre="1">${jsonForScript(o)}</script>`);
  return out.join('\n    ');
}

/** Rota için JSON-LD blokları (statik; uygulama bilgisi gerektirmeyen alanlar). */
export function routeJsonLd(meta: RouteMeta, lang: Lang, origin: string): unknown[] {
  const t = tr(lang);
  const resolved = resolveMeta(meta, lang);
  const blocks: unknown[] = [];
  const stores = { android: null, ios: null };
  if (meta.id === 'home') blocks.push(organizationLd(undefined, origin), mobileAppLd(undefined, stores, origin));
  if (meta.id === 'about' || meta.id === 'contact') blocks.push(organizationLd(undefined, origin));
  if (meta.id === 'download') blocks.push(mobileAppLd(undefined, stores, origin));
  if (meta.faq) {
    blocks.push(faqLd(buildNewFaq((k: TranslationKey) => t(k))));
  }
  if (!meta.home) {
    blocks.push(
      breadcrumbLd([
        { name: t('site.nav.home'), url: pageUrl(origin, lang, '/') },
        { name: resolved.title, url: pageUrl(origin, lang, meta.path) },
      ]),
    );
  }
  return blocks;
}

/** Bilgi sayfası bölümleri: `pg.<slug>.sN.(h|pN|lN|oN)` anahtarlarından noscript HTML'i. */
function infoSections(slug: string, t: (k: string) => string, tableHtml: string, tableAfter?: string): string {
  const dict = dictionaries.tr as Record<string, string>;
  const re = new RegExp(`^pg\\.${slug}\\.(s\\d+)\\.([hplo])(\\d*)$`);
  const sections = new Map<string, { h?: string; p: [number, string][]; l: [number, string][]; o: [number, string][] }>();
  for (const key of Object.keys(dict)) {
    const m = re.exec(key);
    if (!m) continue;
    const sec = sections.get(m[1]) ?? { p: [], l: [], o: [] };
    const text = esc(t(key));
    if (m[2] === 'h') sec.h = text;
    else sec[m[2] as 'p' | 'l' | 'o'].push([Number(m[3]), text]);
    sections.set(m[1], sec);
  }
  const num = (id: string) => Number(id.slice(1));
  const html: string[] = [];
  for (const id of [...sections.keys()].sort((a, b) => num(a) - num(b))) {
    const sec = sections.get(id)!;
    const sorted = (a: [number, string][]) => a.sort((x, y) => x[0] - y[0]).map((x) => x[1]);
    if (sec.h) html.push(`<h2>${sec.h}</h2>`);
    for (const p of sorted(sec.p)) html.push(`<p>${p}</p>`);
    if (sec.l.length) html.push(`<ul>${sorted(sec.l).map((x) => `<li>${x}</li>`).join('')}</ul>`);
    if (sec.o.length) html.push(`<ol>${sorted(sec.o).map((x) => `<li>${x}</li>`).join('')}</ol>`);
    if (tableHtml && tableAfter === id) html.push(tableHtml);
  }
  return html.join('\n');
}

function tableHtml(meta: RouteMeta, t: (k: string) => string): string {
  const tb = meta.table;
  if (!tb) return '';
  const head = tb.headKeys.map((k) => `<th scope="col">${esc(t(k))}</th>`).join('');
  const rows: string[] = [];
  for (let i = 1; i <= tb.rows; i++) {
    const cells = (['a', 'b', 'c'] as const).map((c, idx) => {
      const text = esc(t(`${tb.prefix}${i}.${c}`));
      return idx === 0 ? `<th scope="row">${text}</th>` : `<td>${text}</td>`;
    });
    rows.push(`<tr>${cells.join('')}</tr>`);
  }
  return `<table border="1" cellpadding="6"><caption>${esc(t(tb.captionKey))}</caption><thead><tr>${head}</tr></thead><tbody>${rows.join('')}</tbody></table>`;
}

/** Çıplak sayfa için `<noscript>`: başlık, özet, (varsa) tam özet metin, ilgili sayfalar ve diğer diller. */
export function renderNoscript(meta: RouteMeta, lang: Lang): string {
  const t = tr(lang);
  const resolved = resolveMeta(meta, lang);
  const parts: string[] = [`<h1>${esc(resolved.title)}</h1>`];
  if (meta.leadKey) parts.push(`<p>${esc(t(meta.leadKey))}</p>`);
  if (meta.infoSlug) {
    parts.push(infoSections(meta.infoSlug, t, tableHtml(meta, t), meta.table ? 's6' : undefined));
  }
  if (meta.legalType) parts.push(`<p>${esc(t('seo.legal.note'))}</p>`);
  if (meta.privacySummary) {
    parts.push(
      `<h2>${esc(t('seo.privacy.h'))}</h2><ul>${[1, 2, 3, 4, 5].map((i) => `<li>${esc(t(`seo.privacy.l${i}`))}</li>`).join('')}</ul>`,
    );
  }
  parts.push(`<p>${esc(t('seo.noscript.js'))}</p>`);
  const related = ['home', 'privacy', 'deleteAccount', 'dataRequest', 'contact']
    .map((id) => ROUTE_META.find((r) => r.id === id)!)
    .filter((r) => r.id !== meta.id);
  parts.push(
    `<nav aria-label="${esc(t('seo.noscript.related'))}"><h2>${esc(t('seo.noscript.related'))}</h2><ul>${related
      .map((r) => `<li><a href="/${lang}${r.path === '/' ? '' : r.path}">${esc(resolveMeta(r, lang).title)}</a></li>`)
      .join('')}</ul></nav>`,
  );
  parts.push(
    `<nav aria-label="${esc(t('seo.noscript.langs'))}"><h2>${esc(t('seo.noscript.langs'))}</h2><ul>${LANGS.map(
      (l) =>
        `<li><a href="/${l.code}${meta.path === '/' ? '' : meta.path}" hreflang="${l.code}" lang="${l.code}">${esc(l.label)}</a></li>`,
    ).join('')}</ul></nav>`,
  );
  return `<noscript><main style="max-width:48rem;margin:0 auto;padding:1.5rem 1rem;font:16px/1.6 system-ui,sans-serif">\n${parts.filter(Boolean).join('\n')}\n</main></noscript>`;
}

/**
 * Derleme çıktısındaki parça adresleri (scripts/prerender.mjs, vite manifest'inden): sayfanın sözlük parçası ve sayfa parçası
 * HTML'den ÖNCEDEN istenir; aksi halde ana paket çalışıp rota ve sözlük açılana dek bu parçalar indirilmez (şelale).
 */
export interface AssetHints {
  /** Dilin site sözlüğü parçası (ve statik bağımlılıkları). */
  dictionary(lang: Lang): string[];
  /** Sayfanın JS parçaları ve CSS dosyaları (statik bağımlılıklar dahil, girdi paketinin zaten yüklediği parçalar hariç). */
  page(metaId: string): { js: string[]; css: string[] };
}

function renderHints(hints: AssetHints, meta: RouteMeta, lang: Lang): string[] {
  const page = hints.page(meta.id);
  const js = [...new Set([...hints.dictionary(lang), ...page.js])];
  return [
    ...page.css.map((href) => `<link rel="stylesheet" crossorigin href="${esc(href)}" data-pre="1" />`),
    ...js.map((href) => `<link rel="modulepreload" crossorigin href="${esc(href)}" data-pre="1" />`),
  ];
}

/** Şablona (dist/index.html) bir sayfanın head + noscript içeriğini işler. */
export function applyTemplate(
  template: string,
  meta: RouteMeta,
  lang: Lang,
  origin: string,
  hints?: AssetHints,
): string {
  const start = template.indexOf(SEO_START);
  const end = template.indexOf(SEO_END);
  if (start < 0 || end < start) throw new Error(`Şablonda ${SEO_START} ... ${SEO_END} işaretleri yok`);
  if (!ROOT_DIV.test(template)) throw new Error(`Şablonda <div id="root"> yok`);
  const resolved = resolveMeta(meta, lang);
  const model = buildHeadModel({
    lang,
    origin,
    path: meta.path,
    title: resolved.fullTitle,
    description: resolved.description,
    appName: resolved.appName,
  });
  const lines = [serializeHead(model, routeJsonLd(meta, lang, origin)), ...(hints ? renderHints(hints, meta, lang) : [])];
  const head = `${SEO_START}\n    ${lines.join('\n    ')}\n    ${SEO_END}`;
  return (
    template.slice(0, start) +
    head +
    template.slice(end + SEO_END.length)
  )
    .replace(/<html[^>]*>/, `<html lang="${lang}" dir="${dirOf(lang)}">`)
    .replace(ROOT_DIV, () => `<div id="root">${renderNoscript(meta, lang)}</div>`);
}

/** `/privacy` + `tr` → `tr/privacy/index.html`. */
export function pageFile(lang: Lang, path: string): string {
  return `${lang}${path === '/' ? '' : path}/index.html`;
}

export function buildSitemap(origin: string, lastmod: string): string {
  const urls = LANGS.flatMap((l) => ROUTE_META.map((r) => ({ lang: l.code, r })));
  const entries = urls.map(({ lang, r }) => {
    const alt = [
      ...LANGS.map(
        (l) => `    <xhtml:link rel="alternate" hreflang="${l.code}" href="${esc(pageUrl(origin, l.code, r.path))}" />`,
      ),
      `    <xhtml:link rel="alternate" hreflang="x-default" href="${esc(pageUrl(origin, 'tr', r.path))}" />`,
    ].join('\n');
    return `  <url>\n    <loc>${esc(pageUrl(origin, lang, r.path))}</loc>\n    <lastmod>${lastmod}</lastmod>\n    <changefreq>${r.changefreq}</changefreq>\n    <priority>${r.priority.toFixed(1)}</priority>\n${alt}\n  </url>`;
  });
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${entries.join('\n')}\n</urlset>\n`;
}

/** `/admin` yolu yalnız varsayılan adıyla yazılır: gizli yönetim yolu (VITE_ADMIN_PATH) robots.txt'te ASLA açıklanmaz. */
export function buildRobots(origin: string): string {
  return `User-agent: *\nDisallow: /api/\nDisallow: /files/\nDisallow: /admin\nAllow: /\n\nSitemap: ${origin}/sitemap.xml\n`;
}

/** public/.well-known/security.txt şablonundaki `{{ORIGIN}}` yer tutucusunu doldurur. */
export function renderSecurityTxt(template: string, origin: string): string {
  return template.replace(/\{\{ORIGIN\}\}/g, origin);
}

export interface PrerenderResult {
  /** dist'e göre göreli yol → içerik (kök `index.html` dahil). */
  files: Map<string, string>;
  pageCount: number;
}

export function prerender(opts: {
  template: string;
  origin?: string;
  buildDate: string;
  hints?: AssetHints;
}): PrerenderResult {
  const origin = normalizeOrigin(opts.origin);
  const files = new Map<string, string>();
  for (const l of LANGS) {
    for (const meta of ROUTE_META) {
      files.set(pageFile(l.code, meta.path), applyTemplate(opts.template, meta, l.code, origin, opts.hints));
    }
  }
  // Kök: dil seçimi istemcide yapılır (kayıtlı dil / tarayıcı dili); JS'siz botlar Türkçe ana sayfa üstverisini görür
  const home = ROUTE_META.find((r) => r.home)!;
  files.set('index.html', applyTemplate(opts.template, home, 'tr', origin, opts.hints));
  files.set('sitemap.xml', buildSitemap(origin, opts.buildDate));
  files.set('robots.txt', buildRobots(origin));
  return { files, pageCount: LANGS.length * ROUTE_META.length };
}
