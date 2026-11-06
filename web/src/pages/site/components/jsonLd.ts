import type { AppInfo } from '../../../api/types';

/** JSON-LD: yalnızca bilinen alanlarla (boş/null olanlar atlanır). */
function clean<T extends Record<string, unknown>>(o: T): T {
  return Object.fromEntries(
    Object.entries(o).filter(([, v]) => v !== null && v !== undefined && v !== '' && !(Array.isArray(v) && !v.length)),
  ) as T;
}

/** Arama motorlarının "bukampus" / "BuKampüs" yazımlarını marka adıyla eşlemesi için alternatif adlar. */
const ALT_NAMES = ['bukampus', 'BuKampüs', 'BÜ Kampüs Bingöl Üniversitesi'];

/** WebSite: Google'ın site adı (sitelinks/başlık) için; alternatif adlarla "bukampus" aramasını markaya bağlar. */
export function websiteLd(info: AppInfo | undefined, origin: string): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: info?.appName ?? 'BÜ Kampüs',
    alternateName: ALT_NAMES,
    url: info?.website ?? origin,
    inLanguage: ['tr', 'en', 'ar'],
  };
}

export function organizationLd(info: AppInfo | undefined, origin: string): Record<string, unknown> {
  const sameAs = [info?.social.instagram, info?.social.twitter, info?.social.youtube].filter(
    (x): x is string => !!x,
  );
  return clean({
    '@context': 'https://schema.org',
    '@type': 'EducationalOrganization',
    name: info?.appName ?? 'BÜ Kampüs',
    alternateName: ALT_NAMES,
    url: info?.website ?? origin,
    logo: `${origin}/icon-512.png`,
    email: info?.contactEmail,
    telephone: info?.phone,
    address: info?.address ? { '@type': 'PostalAddress', streetAddress: info.address } : null,
    sameAs,
  });
}

export function mobileAppLd(
  info: AppInfo | undefined,
  links: { android: string | null; ios: string | null },
  origin: string,
): Record<string, unknown> {
  const installs = [links.android, links.ios].filter((x): x is string => !!x);
  return clean({
    '@context': 'https://schema.org',
    '@type': 'MobileApplication',
    name: info?.appName ?? 'BÜ Kampüs',
    alternateName: ALT_NAMES,
    // bağımsız öğrenci uygulaması: üniversite yayıncı DEĞİLDİR (publisher yazılmaz); kategori sosyal ağ
    applicationCategory: 'SocialNetworkingApplication',
    audience: { '@type': 'EducationalAudience', educationalRole: 'student' },
    operatingSystem: [links.android ? 'Android' : null, links.ios ? 'iOS' : null].filter(Boolean).join(', '),
    url: origin,
    installUrl: installs[0],
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

/** FAQPage: soru/yanıt çiftleri (yanıtlar düz metin). */
export function faqLd(entries: { question: string; answer: string }[]): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: entries.map((e) => ({
      '@type': 'Question',
      name: e.question,
      acceptedAnswer: { '@type': 'Answer', text: e.answer },
    })),
  };
}
