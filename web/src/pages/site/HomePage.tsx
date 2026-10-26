// SAYFA: Ana sayfa (/)
// API: GET /api/app/info (useAppInfo: bakım/iletişim), mağaza bağlantıları için useStoreLinks (GET /api/app/version?platform=ANDROID|IOS).
import { Link } from 'react-router-dom';
import { useAppInfo, useStoreLinks } from '../../api/hooks';
import { ButtonLink, ContourBackdrop, Icon } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { FEATURES } from './components/features';
import { mobileAppLd, organizationLd } from './components/jsonLd';
import { MaintenanceNotice } from './components/Notices';
import { Phone } from './components/Phone';
import { useHeadingFocus } from './components/PageHero';
import { Ridge } from './components/Ridge';
import { StoreButton } from './components/StoreButton';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './HomePage.module.css';

const HIGHLIGHTS = FEATURES.filter((f) => ['news', 'menu', 'events', 'chat'].includes(f.id));

export default function HomePage() {
  const { t } = useI18n();
  const stores = useStoreLinks();
  const info = useAppInfo();
  const h1 = useHeadingFocus<HTMLHeadingElement>();
  const origin = typeof window !== 'undefined' ? window.location.origin : '';
  usePageMeta({
    title: '',
    description: t('site.meta.home'),
    path: '/',
    jsonLd: [organizationLd(info.data, origin), mobileAppLd(info.data, stores, origin)],
  });

  return (
    <>
      <section className={styles.hero}>
        <ContourBackdrop className={styles.art} />
        <div className={`container ${styles.inner}`}>
          <div className={styles.copy}>
            <MaintenanceNotice />
            <h1 ref={h1} tabIndex={-1} className={styles.title}>
              {t('site.home.heroTitle')}
            </h1>
            <p className={styles.lead}>{t('site.home.heroLead')}</p>
            <div className={shared.actions}>
              <ButtonLink
                to={paths.site.download}
                size="lg"
                variant="accent"
                className={styles.heroCta}
                leftIcon={<Icon name="download" size={20} />}
              >
                {t('site.home.ctaDownload')}
              </ButtonLink>
              <ButtonLink to={paths.site.features} size="lg" variant="secondary" className={styles.ghost}>
                {t('site.home.ctaFeatures')}
              </ButtonLink>
            </div>
            <p className={styles.trust}>
              <Icon name="shield" size={18} />
              {t('site.home.trust')}
            </p>
          </div>
          <div className={styles.stage}>
            <Phone screen="menu" tilt={7} className={`${styles.phoneBack} ${styles.phone}`} />
            <Phone screen="home" tilt={-3} className={`${styles.phoneFront} ${styles.phone}`} />
          </div>
        </div>
        <Ridge />
      </section>

      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${shared.split}`}>
          <div>
            <div className={shared.head}>
              <h2 className={shared.h2}>{t('site.home.highlightsTitle')}</h2>
              <p className={shared.lead}>{t('site.home.highlightsLead')}</p>
            </div>
            <ul className={shared.ruled}>
              {HIGHLIGHTS.map((f) => (
                <li key={f.id}>
                  <span className={shared.ico}>
                    <Icon name={f.icon} size={22} />
                  </span>
                  <div>
                    <h3>{t(f.title)}</h3>
                    <p>{t(f.text)}</p>
                  </div>
                </li>
              ))}
            </ul>
            <p className={styles.more}>
              <Link to={paths.site.features}>{t('site.home.allFeatures')}</Link>
            </p>
          </div>
          <div className={styles.peeks}>
            <Phone screen="news" peek className={styles.peekA} />
            <Phone screen="events" peek className={styles.peekB} />
          </div>
        </div>
      </section>

      <section className={`${shared.section} ${styles.stepsSection}`}>
        <div className="container">
          <h2 className={shared.h2}>{t('site.home.stepsTitle')}</h2>
          <ol className={styles.steps}>
            {([1, 2, 3] as const).map((n) => (
              <li key={n}>
                <span className={styles.num} aria-hidden="true">
                  {n}
                </span>
                <h3 className={shared.h3}>{t(`site.home.step${n}.title` as 'site.home.step1.title')}</h3>
                <p className={shared.muted}>{t(`site.home.step${n}.text` as 'site.home.step1.text')}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className={shared.band}>
        <ContourBackdrop className={shared.bandArt} />
        <div className={`container ${shared.bandInner}`}>
          <h2 className={shared.h2} style={{ color: '#fff' }}>
            {t('site.home.privacyTitle')}
          </h2>
          <ul className={styles.promises}>
            {([1, 2, 3, 4] as const).map((n) => (
              <li key={n}>{t(`site.home.privacy${n}` as 'site.home.privacy1')}</li>
            ))}
          </ul>
          <Link to={paths.site.legal('PRIVACY')} className={styles.bandLink}>
            {t('site.home.privacyLink')}
          </Link>
        </div>
      </section>

      <section className={shared.section}>
        <div className={`container ${styles.cta}`}>
          <div>
            <h2 className={shared.h2}>{t('site.home.ctaTitle')}</h2>
            <p className={shared.lead}>{t('site.home.ctaText')}</p>
          </div>
          <div className={styles.ctaButtons}>
            <StoreButton store="android" href={stores.android} />
            <StoreButton store="ios" href={stores.ios} />
          </div>
        </div>
      </section>
    </>
  );
}
