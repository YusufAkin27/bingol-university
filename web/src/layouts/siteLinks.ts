import type { TranslationKey } from '../i18n';
import { paths } from '../paths';

export interface SiteLink {
  to: string;
  label: TranslationKey;
}

/** Herkese açık sitenin bağlantı grupları: alt bilgi ve site haritası aynı kaynaktan beslenir. Yönetim yolu burada ASLA yer almaz. */
export const SITE_GROUPS: { title: TranslationKey; links: SiteLink[] }[] = [
  {
    title: 'pg.foot.org',
    links: [
      { to: paths.site.about, label: 'site.nav.about' },
      { to: paths.site.contact, label: 'site.nav.contact' },
      { to: paths.site.brand, label: 'pg.brand.title' },
    ],
  },
  {
    title: 'pg.foot.product',
    links: [
      { to: paths.site.features, label: 'site.nav.features' },
      { to: paths.site.download, label: 'site.nav.download' },
      { to: paths.site.news, label: 'pg.nav.news' },
      { to: paths.site.menu, label: 'pg.nav.menu' },
      { to: paths.site.changelog, label: 'pg.changelog.title' },
    ],
  },
  {
    title: 'pg.foot.support',
    links: [
      { to: paths.site.help, label: 'pg.help.title' },
      { to: paths.site.faq, label: 'site.nav.faq' },
      { to: paths.site.status, label: 'pg.status.title' },
      { to: paths.site.deleteAccount, label: 'pg.delete.title' },
      { to: paths.site.dataRequest, label: 'site.dataRequest.title' },
    ],
  },
  {
    title: 'pg.foot.legal',
    links: [
      { to: paths.site.privacy, label: 'legal.title.PRIVACY' },
      { to: paths.site.terms, label: 'legal.title.TERMS' },
      { to: paths.site.legal('KVKK'), label: 'legal.title.KVKK' },
      { to: paths.site.cookies, label: 'pg.cookies.title' },
      { to: paths.site.guidelines, label: 'pg.guidelines.title' },
      { to: paths.site.accessibility, label: 'pg.accessibility.title' },
      { to: paths.site.security, label: 'pg.security.title' },
      { to: paths.site.sitemap, label: 'pg.sitemap.title' },
    ],
  },
];

/** Üst menü. */
export const MAIN_NAV: (SiteLink & { end?: boolean })[] = [
  { to: paths.site.home, label: 'site.nav.home', end: true },
  { to: paths.site.features, label: 'site.nav.features' },
  { to: paths.site.news, label: 'pg.nav.news' },
  { to: paths.site.menu, label: 'pg.nav.menu' },
  { to: paths.site.help, label: 'pg.nav.help' },
  { to: paths.site.about, label: 'site.nav.about' },
];
