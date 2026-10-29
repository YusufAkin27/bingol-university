/**
 * Herkese açık site rotalarının SEO meta TEK KAYNAĞI.
 * Hem çalışma zamanındaki `usePageMeta` hem de derleme zamanındaki önrender/sitemap üretimi (scripts/prerender.mjs)
 * başlık, açıklama ve JavaScript'siz yedek metni (noscript) buradan okur. Yeni herkese açık sayfa:
 * (1) routes.tsx'e rota, (2) paths.ts'e yol, (3) buraya satır (başlık/açıklama çeviri anahtarlarıyla).
 * Yönetim paneli (/admin/**) burada YER ALMAZ: yalnız Türkçedir ve arama motorlarına kapalıdır.
 */
import type { TranslationKey } from '../i18n';
import { translate } from '../i18n/registry';
import type { Lang } from '../i18n/lang';
import type { LegalType } from '../api/types';
import { paths } from '../paths';

export type RouteChangefreq = 'daily' | 'weekly' | 'monthly' | 'yearly';

export interface RouteMeta {
  id: string;
  /** Mantıksal yol (dil öneksiz): `/privacy`. */
  path: string;
  titleKey: TranslationKey;
  descKey: TranslationKey;
  /** noscript girişi: başlıktan sonra gösterilen paragraf. */
  leadKey?: TranslationKey;
  /** `pg.<slug>.sN.*` bölümleri noscript metnine girer (bilgi sayfaları). */
  infoSlug?: string;
  /** Hesap silme gibi tablolu sayfalar için noscript tablosu. */
  table?: { captionKey: TranslationKey; headKeys: [TranslationKey, TranslationKey, TranslationKey]; prefix: string; rows: number };
  /** Yasal belge sayfaları: noscript'e "tam metin sunucudan yüklenir" notu eklenir. */
  legalType?: LegalType;
  /** Gizlilik sayfası: noscript'e kısa özet maddeleri eklenir. */
  privacySummary?: boolean;
  /** Ana sayfa: başlık "BÜ Kampüs · slogan" biçiminde kurulur. */
  home?: boolean;
  /** SSS sayfası: FAQPage JSON-LD. */
  faq?: boolean;
  changefreq: RouteChangefreq;
  priority: number;
}

const legal = (type: LegalType, id: string, path: string, titleKey?: TranslationKey): RouteMeta => ({
  id,
  path,
  titleKey: titleKey ?? (`legal.title.${type}` as TranslationKey),
  descKey: `seo.legal.${type}.desc` as TranslationKey,
  leadKey: `seo.legal.${type}.desc` as TranslationKey,
  legalType: type,
  privacySummary: type === 'PRIVACY',
  changefreq: 'yearly',
  priority: type === 'PRIVACY' || type === 'TERMS' ? 0.6 : 0.4,
});

/** Sitemap'e ve önrendera giren rotalar (sıra = sitemap sırası). */
export const ROUTE_META: RouteMeta[] = [
  { id: 'home', path: paths.site.home, titleKey: 'site.home.heroTitle', descKey: 'site.meta.home', leadKey: 'site.home.heroLead', home: true, changefreq: 'weekly', priority: 1 },
  { id: 'features', path: paths.site.features, titleKey: 'site.features.title', descKey: 'site.meta.features', leadKey: 'site.features.lead', changefreq: 'monthly', priority: 0.8 },
  { id: 'about', path: paths.site.about, titleKey: 'site.about.title', descKey: 'site.meta.about', leadKey: 'site.about.lead', changefreq: 'monthly', priority: 0.6 },
  { id: 'download', path: paths.site.download, titleKey: 'site.download.title', descKey: 'site.meta.download', leadKey: 'site.download.lead', changefreq: 'monthly', priority: 0.9 },
  { id: 'news', path: paths.site.news, titleKey: 'pg.news.title', descKey: 'pg.news.meta', leadKey: 'pg.news.lead', changefreq: 'daily', priority: 0.7 },
  { id: 'menu', path: paths.site.menu, titleKey: 'pg.menu.title', descKey: 'pg.menu.meta', leadKey: 'pg.menu.lead', changefreq: 'daily', priority: 0.7 },
  { id: 'help', path: paths.site.help, titleKey: 'pg.help.title', descKey: 'pg.help.meta', leadKey: 'pg.help.lead', changefreq: 'monthly', priority: 0.6 },
  { id: 'faq', path: paths.site.faq, titleKey: 'site.faq.title', descKey: 'site.meta.faq', leadKey: 'site.faq.lead', faq: true, changefreq: 'monthly', priority: 0.6 },
  { id: 'contact', path: paths.site.contact, titleKey: 'site.contact.title', descKey: 'site.meta.contact', leadKey: 'site.contact.lead', changefreq: 'yearly', priority: 0.7 },
  { id: 'brand', path: paths.site.brand, titleKey: 'pg.brand.title', descKey: 'pg.brand.meta', leadKey: 'pg.brand.lead', changefreq: 'yearly', priority: 0.3 },
  { id: 'changelog', path: paths.site.changelog, titleKey: 'pg.changelog.title', descKey: 'pg.changelog.meta', leadKey: 'pg.changelog.lead', changefreq: 'weekly', priority: 0.4 },
  {
    id: 'deleteAccount',
    path: paths.site.deleteAccount,
    titleKey: 'pg.delete.title',
    descKey: 'pg.delete.meta',
    leadKey: 'pg.delete.lead',
    infoSlug: 'delete',
    table: {
      captionKey: 'pg.delete.t.caption',
      headKeys: ['pg.delete.t.data', 'pg.delete.t.action', 'pg.delete.t.period'],
      prefix: 'pg.delete.t.r',
      rows: 10,
    },
    changefreq: 'yearly',
    priority: 0.5,
  },
  { id: 'dataRequest', path: paths.site.dataRequest, titleKey: 'site.dataRequest.title', descKey: 'site.meta.dataRequest', leadKey: 'site.dataRequest.lead', changefreq: 'yearly', priority: 0.5 },
  legal('PRIVACY', 'privacy', paths.site.privacy),
  legal('TERMS', 'terms', paths.site.terms),
  { id: 'legal', path: paths.site.legalIndex, titleKey: 'legal.list.title', descKey: 'site.meta.legal', leadKey: 'legal.list.lead', changefreq: 'yearly', priority: 0.4 },
  legal('KVKK', 'legalKvkk', paths.site.legal('KVKK')),
  legal('COMMUNITY_RULES', 'legalCommunityRules', paths.site.legal('COMMUNITY_RULES'), 'seo.legal.COMMUNITY_RULES.title'),
  legal('EXPLICIT_CONSENT', 'legalExplicitConsent', paths.site.legal('EXPLICIT_CONSENT')),
  legal('CONTENT_REMOVAL', 'legalContentRemoval', paths.site.legal('CONTENT_REMOVAL')),
  legal('RETENTION', 'legalRetention', paths.site.legal('RETENTION')),
  { id: 'cookies', path: paths.site.cookies, titleKey: 'pg.cookies.title', descKey: 'pg.cookies.meta', leadKey: 'pg.cookies.lead', infoSlug: 'cookies', changefreq: 'yearly', priority: 0.3 },
  { id: 'guidelines', path: paths.site.guidelines, titleKey: 'pg.guidelines.title', descKey: 'pg.guidelines.meta', leadKey: 'pg.guidelines.lead', infoSlug: 'guidelines', changefreq: 'yearly', priority: 0.4 },
  { id: 'childSafety', path: paths.site.childSafety, titleKey: 'pg.childsafety.title', descKey: 'pg.childsafety.meta', leadKey: 'pg.childsafety.lead', infoSlug: 'childsafety', changefreq: 'yearly', priority: 0.5 },
  { id: 'accessibility', path: paths.site.accessibility, titleKey: 'pg.accessibility.title', descKey: 'pg.accessibility.meta', leadKey: 'pg.accessibility.lead', infoSlug: 'accessibility', changefreq: 'yearly', priority: 0.3 },
  { id: 'security', path: paths.site.security, titleKey: 'pg.security.title', descKey: 'pg.security.meta', leadKey: 'pg.security.lead', infoSlug: 'security', changefreq: 'yearly', priority: 0.3 },
  { id: 'sitemap', path: paths.site.sitemap, titleKey: 'pg.sitemap.title', descKey: 'pg.sitemap.meta', leadKey: 'pg.sitemap.lead', changefreq: 'monthly', priority: 0.2 },
];

export type RouteId = string;

const BY_ID = new Map(ROUTE_META.map((r) => [r.id, r]));
const BY_PATH = new Map(ROUTE_META.map((r) => [r.path, r]));

/** Kanonik yolu başka sayfa olan eş adlar (/legal/privacy → /privacy; /legal/cookies → /cookies). */
const ALIASES: Record<string, string> = {
  [paths.site.legal('PRIVACY')]: paths.site.privacy,
  [paths.site.legal('TERMS')]: paths.site.terms,
  [paths.site.legal('COOKIES')]: paths.site.cookies,
};

export function routeById(id: RouteId): RouteMeta {
  const r = BY_ID.get(id);
  if (!r) throw new Error(`Bilinmeyen SEO rotası: ${id}`);
  return r;
}

/** Mantıksal yola (dil öneksiz, sonda `/` yok) uyan rota; yoksa `undefined` (haber ayrıntısı, 404…). */
export function matchRouteMeta(logicalPath: string): RouteMeta | undefined {
  const p = logicalPath.length > 1 ? logicalPath.replace(/\/+$/, '') : logicalPath;
  return BY_PATH.get(ALIASES[p] ?? p);
}

/** Yasal belge türünün rota kimliği (COOKIES ve bilinmeyenler çerez sayfasına/yasal listeye düşer). */
export function legalRouteId(type: LegalType): RouteId {
  if (type === 'COOKIES') return 'cookies';
  return ROUTE_META.find((r) => r.legalType === type)?.id ?? 'legal';
}

/** InfoPage dilimi (`delete`, `cookies`…) → rota kimliği. */
export function infoRouteId(slug: string): RouteId {
  const r = ROUTE_META.find((m) => m.infoSlug === slug);
  if (!r) throw new Error(`Bilinmeyen bilgi sayfası: ${slug}`);
  return r.id;
}

export interface ResolvedMeta {
  /** Sayfa başlığı (uygulama adı eki olmadan). */
  title: string;
  /** `<title>` metni: "Başlık · BÜ Kampüs" (ana sayfada "BÜ Kampüs · Slogan"). */
  fullTitle: string;
  description: string;
  appName: string;
}

/** Dile göre başlık/açıklama çözümü. */
export function resolveMeta(meta: RouteMeta, lang: Lang): ResolvedMeta {
  const t = (k: string) => translate(lang, k);
  const appName = t('common.appName');
  const title = t(meta.titleKey);
  return {
    title,
    fullTitle: meta.home ? `${appName} · ${title}` : `${title} · ${appName}`,
    description: t(meta.descKey),
    appName,
  };
}
