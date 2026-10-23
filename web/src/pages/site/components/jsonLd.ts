import type { AppInfo } from '../../../api/types';

/** JSON-LD: yalnızca bilinen alanlarla (boş/null olanlar atlanır). */
function clean<T extends Record<string, unknown>>(o: T): T {
  return Object.fromEntries(
    Object.entries(o).filter(([, v]) => v !== null && v !== undefined && v !== '' && !(Array.isArray(v) && !v.length)),
  ) as T;
}

export function organizationLd(info: AppInfo | undefined, origin: string): Record<string, unknown> {
  const sameAs = [info?.social.instagram, info?.social.twitter, info?.social.youtube].filter(
    (x): x is string => !!x,
  );
  return clean({
    '@context': 'https://schema.org',
    '@type': 'EducationalOrganization',
    name: info?.appName ?? 'Bingöl Üniversitesi',
    url: info?.website ?? origin,
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
    name: info?.appName ?? 'Bingöl Üniversitesi',
    applicationCategory: 'EducationApplication',
    operatingSystem: [links.android ? 'Android' : null, links.ios ? 'iOS' : null].filter(Boolean).join(', '),
    url: origin,
    installUrl: installs[0],
    publisher: { '@type': 'EducationalOrganization', name: 'Bingöl Üniversitesi' },
  });
}
