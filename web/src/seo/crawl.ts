/**
 * Tarayıcı (bot) yüzeyi: robots.txt ve sitemap.xml üretimi, sayfa başına gerçek `lastmod` için içerik imzası.
 * Saf işlevler (dosya sistemi scripts/prerender.mjs'te). Mantıksal rota listesi routeMeta.ts'ten gelir.
 * Teknik SEO sözleşmesi ve gerekçeler: docs/SEO_TECHNICAL.md.
 */
import { LANGS, type Lang } from '../i18n/lang';
import { pageUrl } from './headModel';
import { ROUTE_META, type RouteMeta } from './routeMeta';

const esc = (s: string): string =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/**
 * İçeriği yalnız Türkçe sunulan rotalar: hukuki belgeler arka uçtan gelir ve EN/AR çevirisi yoktur (Türkçe gösterilir).
 * Bu sayfaların en/ar sürümü "çeviri" değil kopya olur: hreflang kümesine ve sitemap'e GİRMEZ (docs/SEO_TECHNICAL.md bölüm 3).
 * Kural tek yerde durur; başlık/hreflang tarafı (headModel) ve check-seo.mjs aynı kuralı kullanır.
 */
export function isTurkishOnly(meta: Pick<RouteMeta, 'legalType'>): boolean {
  return Boolean(meta.legalType);
}

/** Rotanın sitemap'e girecek dilleri (Türkçe-only rotada yalnız tr). */
export function sitemapLangs(meta: RouteMeta): Lang[] {
  return isTurkishOnly(meta) ? ['tr'] : LANGS.map((l) => l.code);
}

/** Rota × dil → `lastmod` (YYYY-MM-DD). */
export type LastmodResolver = (routeId: string, lang: Lang) => string;

export function buildSitemap(origin: string, lastmod: string | LastmodResolver): string {
  const mod: LastmodResolver = typeof lastmod === 'function' ? lastmod : () => lastmod;
  const entries: string[] = [];
  for (const r of ROUTE_META) {
    const langs = sitemapLangs(r);
    const alt = [
      ...langs.map((l) => `    <xhtml:link rel="alternate" hreflang="${l}" href="${esc(pageUrl(origin, l, r.path))}" />`),
      `    <xhtml:link rel="alternate" hreflang="x-default" href="${esc(pageUrl(origin, 'tr', r.path))}" />`,
    ].join('\n');
    for (const lang of langs) {
      entries.push(
        `  <url>\n    <loc>${esc(pageUrl(origin, lang, r.path))}</loc>\n    <lastmod>${mod(r.id, lang)}</lastmod>\n    <changefreq>${r.changefreq}</changefreq>\n    <priority>${r.priority.toFixed(1)}</priority>\n${alt}\n  </url>`,
      );
    }
  }
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${entries.join('\n')}\n</urlset>\n`;
}

/**
 * Yalnız eğitim (model eğitimi) amaçlı tarayıcılar: içerik arama/yanıt motoru için değil, veri seti için toplanır.
 * Politika: arama motorları (Googlebot, Bingbot, Yandex…) ve yanıt/arama botları (OAI-SearchBot, ChatGPT-User, PerplexityBot,
 * Claude-SearchBot…) `*` kuralıyla SERBEST; yalnız bunlar kapalıdır. Politika değişirse yalnız bu liste değişir.
 */
export const AI_TRAINING_BOTS = [
  'GPTBot',
  'Google-Extended',
  'CCBot',
  'ClaudeBot',
  'anthropic-ai',
  'Applebot-Extended',
  'Bytespider',
  'meta-externalagent',
  'cohere-ai',
  'Diffbot',
  'ImagesiftBot',
] as const;

/**
 * `/admin` yalnız varsayılan adıyla yazılır: gizli yönetim yolu (VITE_ADMIN_PATH) robots.txt'te ASLA açıklanmaz;
 * o yolu nginx `X-Robots-Tag: noindex` ile kapatır (scripts/prerender.mjs → nginx admin parçası).
 */
export function buildRobots(origin: string): string {
  const star = [
    'User-agent: *',
    'Disallow: /api/',
    'Disallow: /files/',
    'Disallow: /ws',
    'Disallow: /actuator/',
    'Disallow: /admin',
    // destek izleme bağlantısı (token sorgu dizesinde) hiçbir koşulda taranmasın
    'Disallow: /support/track',
    'Disallow: /*/support/track',
    'Allow: /',
  ];
  const ai = AI_TRAINING_BOTS.flatMap((b) => [`User-agent: ${b}`, 'Disallow: /', '']);
  return `${star.join('\n')}\n\n# Yalniz model egitimi icin tarayan botlar kapali; arama ve yanit botlari serbest\n${ai.join('\n')}\nSitemap: ${origin}/sitemap.xml\n`;
}

/** Hızlı, bağımlılıksız 53 bit özet (cyrb53); lastmod değişim algısı için, güvenlik amaçlı değil. */
export function contentHash(text: string): string {
  let h1 = 0xdeadbeef;
  let h2 = 0x41c6ce57;
  for (let i = 0; i < text.length; i++) {
    const ch = text.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(36);
}

/** Derleme tarihi biçimi doğrulaması (YYYY-MM-DD). */
export const isIsoDate = (s: string): boolean => /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(s));
