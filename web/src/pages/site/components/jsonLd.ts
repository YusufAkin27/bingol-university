import type { AppInfo } from '../../../api/types';

/**
 * JSON-LD üreticileri (schema.org). Kurallar:
 *  - Yalnızca sayfada görünen/doğrulanabilir bilgi; boş/null alanlar atlanır.
 *  - BÜ Kampüs Bingöl Üniversitesi'nin RESMÎ uygulaması DEĞİLDİR: yayıncı/yazar her yerde "BÜ Kampüs" (Organization);
 *    üniversite adı yalnızca açıklamada ("... öğrencileri için bağımsız uygulama") geçer, kuruluş/yayıncı olarak yazılmaz.
 *  - Mağaza adresi uydurulmaz: `installUrl` yalnızca yönetici ayarından/sürüm kontrolünden gelen gerçek bağlantıyla dolar.
 */
function clean<T extends Record<string, unknown>>(o: T): T {
  return Object.fromEntries(
    Object.entries(o).filter(([, v]) => v !== null && v !== undefined && v !== '' && !(Array.isArray(v) && !v.length)),
  ) as T;
}

const APP_NAME = 'BÜ Kampüs';

/** Kuruluş düğümünün kararlı kimliği: WebSite/MobileApplication/NewsArticle buna `@id` ile bağlanır. */
export const organizationId = (origin: string): string => `${origin}/#organization`;

/** Başka düğümlerde yayıncı/yazar olarak satır içi verilir (sayfada ayrı Organization bloğu olmasa da ad doğrulanabilir). */
const orgRef = (origin: string) => ({
  '@type': 'Organization',
  '@id': organizationId(origin),
  name: APP_NAME,
  url: origin,
});

export function organizationLd(info: AppInfo | undefined, origin: string): Record<string, unknown> {
  const sameAs = [info?.social.instagram, info?.social.twitter, info?.social.youtube].filter(
    (x): x is string => !!x,
  );
  return clean({
    '@context': 'https://schema.org',
    '@type': 'Organization',
    '@id': organizationId(origin),
    name: APP_NAME,
    url: origin,
    logo: `${origin}/icon-512.png`,
    email: info?.contactEmail,
    telephone: info?.phone,
    address: info?.address ? { '@type': 'PostalAddress', streetAddress: info.address } : null,
    sameAs,
  });
}

/** Sitenin kendisi. Sitede arama kutusu olmadığı için SearchAction EKLENMEZ. */
export function websiteLd(origin: string, lang: string, url: string): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    '@id': `${origin}/#website`,
    name: APP_NAME,
    url,
    inLanguage: lang,
    publisher: orgRef(origin),
  };
}

export function mobileAppLd(
  info: AppInfo | undefined,
  links: { android: string | null; ios: string | null },
  origin: string,
  description?: string,
): Record<string, unknown> {
  const installs = [links.android, links.ios].filter((x): x is string => !!x);
  return clean({
    '@context': 'https://schema.org',
    '@type': 'MobileApplication',
    name: info?.appName ?? APP_NAME,
    description,
    applicationCategory: 'EducationalApplication',
    operatingSystem: 'Android, iOS',
    url: origin,
    image: `${origin}/icon-512.png`,
    installUrl: installs[0],
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'TRY' },
    isAccessibleForFree: true,
    author: orgRef(origin),
    publisher: orgRef(origin),
  });
}

/** BreadcrumbList: ilk öğe ana sayfa, sonuncusu geçerli sayfa. */
export function breadcrumbLd(items: { name: string; url: string }[]): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((it, i) => ({ '@type': 'ListItem', position: i + 1, name: it.name, item: it.url })),
  };
}

/** `[metin](/yol)` bağlantılarını görünen metne indirger: sayfada okunan düz metin budur. */
export function plainAnswer(answer: string): string {
  return answer.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '$1');
}

/**
 * FAQPage: soru/yanıt çiftleri. Yanıt, sayfada görünen metinle birebir olmalıdır; sayfa bağlantıyı
 * çizdiği için JSON-LD'ye bağlantı sözdizimi değil bağlantı metni girer (`plainAnswer`).
 */
export function faqLd(entries: { question: string; answer: string }[]): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: entries.map((e) => ({
      '@type': 'Question',
      name: e.question,
      acceptedAnswer: { '@type': 'Answer', text: plainAnswer(e.answer) },
    })),
  };
}

export interface NewsArticleInput {
  url: string;
  headline: string;
  description?: string;
  /** yyyy-MM-dd veya ISO 8601 */
  datePublished?: string | null;
  image?: string | null;
  lang: string;
  /** Haberin özgün kaynağı (üniversite sayfası): isBasedOn olarak verilir, yayıncı yapılmaz. */
  sourceUrl?: string | null;
}

/** NewsArticle: haber ayrıntısı sayfası. Başlık Google sınırı için 110 karaktere kısaltılır. */
export function newsArticleLd(a: NewsArticleInput, origin: string): Record<string, unknown> {
  const headline = a.headline.length > 110 ? `${a.headline.slice(0, 109).trimEnd()}…` : a.headline;
  return clean({
    '@context': 'https://schema.org',
    '@type': 'NewsArticle',
    mainEntityOfPage: { '@type': 'WebPage', '@id': a.url },
    headline,
    description: a.description,
    datePublished: a.datePublished,
    image: a.image ? [a.image] : undefined,
    inLanguage: a.lang,
    isBasedOn: a.sourceUrl,
    author: orgRef(origin),
    publisher: {
      ...orgRef(origin),
      logo: { '@type': 'ImageObject', url: `${origin}/icon-512.png` },
    },
  });
}
