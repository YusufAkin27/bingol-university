// SAYFA: 404 (tanıtım sitesi)
// API: yok. Not: routes.tsx'te '/legal' (liste) rotası olmadığından bu yol burada LegalListPage'e yönlendirilir.
import { useLocation } from 'react-router-dom';
import { Link } from '../../components/LocalizedLink';
import { ButtonLink } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { useHeadingFocus } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import LegalListPage from './LegalListPage';
import styles from './NotFoundPage.module.css';

export default function NotFoundPage() {
  const { pathname } = useLocation();
  if (/^\/legal\/?$/.test(pathname)) return <LegalListPage />;
  return <NotFound />;
}

const SUGGESTIONS = [
  { to: paths.site.features, label: 'site.nav.features' },
  { to: paths.site.news, label: 'pg.nav.news' },
  { to: paths.site.menu, label: 'pg.nav.menu' },
  { to: paths.site.faq, label: 'site.nav.faq' },
  { to: paths.site.help, label: 'pg.nav.help' },
  { to: paths.site.contact, label: 'site.nav.contact' },
] as const;

function NotFound() {
  const { t } = useI18n();
  const wrap = useHeadingFocus<HTMLDivElement>();
  usePageMeta({ title: t('site.notFound.title'), description: t('site.notFound.hint'), noindex: true });
  return (
    <section className={styles.hero}>
      <div ref={wrap} tabIndex={-1} className={`container ${styles.inner}`}>
        <p className={styles.code} aria-hidden="true">
          404
        </p>
        <h1 className={styles.title}>{t('site.notFound.title')}</h1>
        <p className={styles.lead}>{t('site.notFound.hint')}</p>
        <ButtonLink to={paths.site.home}>{t('site.notFound.home')}</ButtonLink>
        <nav className={styles.try} aria-label={t('site.s2.notFound.try')}>
          <p className={styles.tryTitle}>{t('site.s2.notFound.try')}</p>
          <ul className={styles.chips}>
            {SUGGESTIONS.map((s) => (
              <li key={s.to}>
                <Link to={s.to} className={styles.chip}>
                  {t(s.label)}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </div>
    </section>
  );
}
