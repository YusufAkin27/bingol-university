// SAYFA: Ana sayfa (/)
// API: GET /api/app/info (useAppInfo), mağaza bağlantıları için useStoreLinks (GET /api/app/version?platform=ANDROID|IOS).
// Not: Şimdilik iskelet kimliğini gösteren minimal bir kahraman bölümü içerir; tanıtım sitesi ajanı burayı dolduracak.
import { useStoreLinks } from '../../api/hooks';
import { StoreBadge } from '../../components/StoreBadge';
import { ButtonLink, ContourBackdrop } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import styles from './HomePage.module.css';

export default function HomePage() {
  const { t } = useI18n();
  const stores = useStoreLinks();
  usePageTitle('');
  return (
    <section className={styles.hero}>
      <ContourBackdrop className={styles.art} />
      <div className={`container ${styles.inner}`}>
        <h1 className={styles.title}>{t('site.home.heroTitle')}</h1>
        <p className={styles.lead}>{t('site.home.heroLead')}</p>
        <div className={styles.actions}>
          <ButtonLink to={paths.site.download} size="lg" variant="accent">
            {t('site.home.ctaDownload')}
          </ButtonLink>
          <ButtonLink to={paths.site.features} size="lg" variant="secondary">
            {t('site.home.ctaFeatures')}
          </ButtonLink>
        </div>
        <div className={styles.badges}>
          <StoreBadge store="android" href={stores.android} />
          <StoreBadge store="ios" href={stores.ios} />
        </div>
      </div>
    </section>
  );
}
