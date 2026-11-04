// SAYFA: 404 (tanıtım sitesi)
// API: yok. Not: routes.tsx'te '/legal' (liste) rotası olmadığından bu yol burada LegalListPage'e yönlendirilir.
import { useLocation, useNavigate } from 'react-router-dom';
import { Link } from '../../components/LocalizedLink';
import { Button, ButtonLink, ContourBackdrop, Icon } from '../../components/ui';
import type { IconName } from '../../components/ui/Icon';
import { useI18n } from '../../i18n/I18nProvider';
import type { TranslationKey } from '../../i18n';
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

const SUGGESTIONS: { to: string; icon: IconName; title: TranslationKey; text: TranslationKey }[] = [
  { to: paths.site.menu, icon: 'cup', title: 'pg.nav.menu', text: 'site.rd10.nf.menuText' },
  { to: paths.site.news, icon: 'news', title: 'pg.nav.news', text: 'site.rd10.nf.newsText' },
  { to: paths.site.features, icon: 'star', title: 'site.nav.features', text: 'site.rd10.nf.featuresText' },
  { to: paths.site.faq, icon: 'help', title: 'site.nav.faq', text: 'site.rd10.nf.faqText' },
];

function NotFound() {
  const { t } = useI18n();
  const navigate = useNavigate();
  const wrap = useHeadingFocus<HTMLDivElement>();
  usePageMeta({ title: t('site.notFound.title'), description: t('site.notFound.hint'), noindex: true });
  return (
    <div ref={wrap} tabIndex={-1} className={`container ${styles.page}`}>
      <p className={styles.crumb} aria-hidden="true">
        <span>{t('site.rd10.nf.eyebrow')}</span>
        <span className={styles.slash}>/</span>
        <strong aria-hidden="true">404</strong>
      </p>
      <section className={styles.panel}>
        <div className={styles.copy}>
          <p className={styles.code} aria-hidden="true">
            404
          </p>
          <h1 className={styles.title}>{t('site.notFound.title')}</h1>
          <p className={styles.lead}>{t('site.notFound.hint')}</p>
          <div className={styles.actions}>
            <ButtonLink to={paths.site.home} size="lg" leftIcon={<Icon name="home" size={18} />}>
              {t('site.notFound.home')}
            </ButtonLink>
            <ButtonLink to={paths.site.help} variant="secondary" size="lg">
              {t('site.rd10.nf.help')}
            </ButtonLink>
            <Button
              variant="ghost"
              size="lg"
              leftIcon={<Icon name="chevronLeft" size={18} className={styles.backIcon} />}
              onClick={() => navigate(-1)}
            >
              {t('site.rd10.nf.back')}
            </Button>
          </div>
        </div>
        <div className={styles.art} aria-hidden="true">
          <ContourBackdrop className={styles.contour} />
        </div>
      </section>
      <nav className={styles.try} aria-labelledby="nf-try">
        <h2 id="nf-try" className={styles.tryTitle}>
          {t('site.rd10.nf.linksTitle')}
        </h2>
        <ul className={styles.cards}>
          {SUGGESTIONS.map((s) => (
            <li key={s.to}>
              <Link to={s.to} className={styles.card}>
                <span className={styles.cardIcon} aria-hidden="true">
                  <Icon name={s.icon} size={22} />
                </span>
                <span className={styles.cardBody}>
                  <strong>{t(s.title)}</strong>
                  <span>{t(s.text)}</span>
                </span>
                <Icon name="chevronRight" size={18} className={styles.cardChev} />
              </Link>
            </li>
          ))}
        </ul>
      </nav>
      <p className={styles.report}>
        <Icon name="info" size={18} />
        <span>{t('site.rd10.nf.report')}</span>
        <Link to={paths.site.contact}>{t('site.nav.contact')}</Link>
      </p>
    </div>
  );
}
