// SAYFA: Site haritası (/sitemap) — herkese açık tüm sayfalar (public/sitemap.xml ile aynı küme).
// API: yok. Bağlantılar layouts/siteLinks.ts'ten gelir.
import { Link } from '../../components/LocalizedLink';
import { SITE_GROUPS } from '../../layouts/siteLinks';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './SitemapPage.module.css';

export default function SitemapPage() {
  const { t } = useI18n();
  const title = t('pg.sitemap.title');
  usePageMeta({ route: 'sitemap' });
  return (
    <>
      <PageHero title={title} lead={t('pg.sitemap.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.grid}`}>
          <section aria-labelledby="sm-home">
            <h2 id="sm-home" className={shared.h3}>
              {t('pg.crumb.home')}
            </h2>
            <ul>
              <li>
                <Link to={paths.site.home}>{t('site.nav.home')}</Link>
              </li>
            </ul>
          </section>
          {SITE_GROUPS.map((g) => (
            <section key={g.title} aria-labelledby={`sm-${g.title}`}>
              <h2 id={`sm-${g.title}`} className={shared.h3}>
                {t(g.title)}
              </h2>
              <ul>
                {g.links.map((l) => (
                  <li key={l.to}>
                    <Link to={l.to}>{t(l.label)}</Link>
                  </li>
                ))}
              </ul>
            </section>
          ))}
        </div>
      </section>
    </>
  );
}
