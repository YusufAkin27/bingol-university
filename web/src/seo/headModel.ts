/**
 * `<head>` SEO etiketlerinin saf modeli. Çalışma zamanı (`usePageMeta`, DOM'a yazar) ve derleme zamanı
 * önrender (HTML dizgesi üretir) aynı modeli kullanır; böylece iki çıktı birbirinden ayrışmaz.
 */
import { translate } from '../i18n/registry';
import { LANGS, dirOf, type Lang } from '../i18n/lang';

export const DEFAULT_PUBLIC_URL = 'https://bukampus.net';
/** Paylaşım görseli; dil başına ayrı görsel gelince yalnızca bu işlev değişir (public/og-<lang>.png). */
export function ogImagePath(_lang: Lang): string {
  return '/og.png';
}
export const OG_IMAGE_SIZE = { width: 1200, height: 630 } as const;

export const OG_LOCALE: Record<Lang, string> = { tr: 'tr_TR', en: 'en_US', ar: 'ar_AR' };

/** Kökeni biçimler: sondaki `/` atılır; boşsa varsayılan. */
export function normalizeOrigin(raw: string | undefined | null): string {
  const v = (raw ?? '').trim().replace(/\/+$/, '');
  return v || DEFAULT_PUBLIC_URL;
}

/** Mantıksal yol + dil → mutlak adres (`/privacy`, tr → `https://x/tr/privacy`; ana sayfa `https://x/tr`). */
export function pageUrl(origin: string, lang: Lang, path: string): string {
  const p = path === '/' ? '' : path.replace(/\/+$/, '');
  return `${origin}/${lang}${p}`;
}

export interface MetaTag {
  attr: 'name' | 'property';
  key: string;
  content: string;
}
export interface LinkTag {
  rel: string;
  href: string;
  hreflang?: string;
}
export interface HeadModel {
  lang: Lang;
  dir: 'ltr' | 'rtl';
  title: string;
  canonical: string;
  metas: MetaTag[];
  links: LinkTag[];
}

export interface HeadInput {
  lang: Lang;
  origin: string;
  /** Mantıksal yol (`/privacy`). */
  path: string;
  /** `<title>` içeriği (uygulama adı ekli). */
  title: string;
  description?: string;
  appName: string;
  noindex?: boolean;
  /** Kanonik yol ve alternatifler başka yola işaret edecekse (eş adlar). Varsayılan `path`. */
  canonicalPath?: string;
}

const t = (lang: Lang, key: string): string => translate(lang, key);

export function buildHeadModel(i: HeadInput): HeadModel {
  const canonicalPath = i.canonicalPath ?? i.path;
  const url = pageUrl(i.origin, i.lang, canonicalPath);
  const image = `${i.origin}${ogImagePath(i.lang)}`;
  const alt = t(i.lang, 'seo.og.imageAlt');
  const metas: MetaTag[] = [];
  const meta = (attr: MetaTag['attr'], key: string, content: string | undefined) => {
    if (content) metas.push({ attr, key, content });
  };
  meta('name', 'description', i.description);
  if (i.noindex) meta('name', 'robots', 'noindex');
  meta('property', 'og:type', 'website');
  meta('property', 'og:site_name', i.appName);
  meta('property', 'og:title', i.title);
  meta('property', 'og:description', i.description);
  meta('property', 'og:url', url);
  meta('property', 'og:locale', OG_LOCALE[i.lang]);
  for (const l of LANGS) if (l.code !== i.lang) meta('property', 'og:locale:alternate', OG_LOCALE[l.code]);
  meta('property', 'og:image', image);
  meta('property', 'og:image:width', String(OG_IMAGE_SIZE.width));
  meta('property', 'og:image:height', String(OG_IMAGE_SIZE.height));
  meta('property', 'og:image:alt', alt);
  meta('name', 'twitter:card', 'summary_large_image');
  meta('name', 'twitter:title', i.title);
  meta('name', 'twitter:description', i.description);
  meta('name', 'twitter:image', image);
  meta('name', 'twitter:image:alt', alt);

  const links: LinkTag[] = [{ rel: 'canonical', href: url }];
  if (!i.noindex) {
    for (const l of LANGS) {
      links.push({ rel: 'alternate', hreflang: l.code, href: pageUrl(i.origin, l.code, canonicalPath) });
    }
    links.push({ rel: 'alternate', hreflang: 'x-default', href: pageUrl(i.origin, 'tr', canonicalPath) });
  }
  return { lang: i.lang, dir: dirOf(i.lang), title: i.title, canonical: url, metas, links };
}
