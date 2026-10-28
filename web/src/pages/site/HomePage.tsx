// SAYFA: Ana sayfa (/)
// API: GET /api/app/info (useAppInfo: bakım/iletişim), mağaza bağlantıları için useStoreLinks (GET /api/app/version?platform=ANDROID|IOS).
// Mobil öncelikli: 360 px tabanından kurulur; telefon çizimleri mobil uygulamanın ekranlarını HTML/CSS ile yeniden çizer.
import { Link } from '../../components/LocalizedLink';
import { useAppInfo, useStoreLinks } from '../../api/hooks';
import { ButtonLink, ContourBackdrop, Icon, type IconName } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { FEATURES } from './components/features';
import { mobileAppLd, organizationLd } from './components/jsonLd';
import { MaintenanceNotice } from './components/Notices';
import { Phone } from './components/Phone';
import { useHeadingFocus } from './components/PageHero';
import { Ridge } from './components/Ridge';
import { StoreButton } from './components/StoreButton';
import { siteOrigin } from '../../seo/siteUrl';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './HomePage.module.css';

const HIGHLIGHTS = FEATURES.filter((f) => ['news', 'menu', 'events', 'chat'].includes(f.id));
const PROMISE_ICONS: IconName[] = ['shield', 'download', 'eyeOff', 'message'];

export default function HomePage() {
  const { t } = useI18n();
  const stores = useStoreLinks();
  const info = useAppInfo();
  const h1 = useHeadingFocus<HTMLHeadingElement>();
  const origin = siteOrigin();
  usePageMeta({
    route: 'home',
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
            <div className={styles.actions}>
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
            <Phone screen="menu" peek tilt={5} className={styles.phoneBack} />
            <Phone screen="home" peek tilt={-2} className={styles.phoneFront} />
          </div>
        </div>
        <Ridge />
      </section>

      <section className={`${styles.sec} ${styles.secFirst}`}>
        <div className={`container ${styles.flow}`}>
          <div className={styles.flowCopy}>
            <div className={shared.head}>
              <h2 className={shared.h2}>{t('site.home.highlightsTitle')}</h2>
              <p className={shared.lead}>{t('site.home.highlightsLead')}</p>
            </div>
            <ul className={styles.features}>
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

      <section className={`${styles.sec} ${styles.stepsSection}`}>
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
        <div className={`container ${shared.bandInner} ${styles.privacy}`}>
          <div className={styles.privacyCopy}>
            <h2 className={shared.h2}>{t('site.home.privacyTitle')}</h2>
            <Link to={paths.site.legal('PRIVACY')} className={styles.bandLink}>
              {t('site.home.privacyLink')}
              <Icon name="chevronRight" size={18} className={styles.bandLinkIcon} />
            </Link>
          </div>
          <ul className={styles.promises}>
            {([1, 2, 3, 4] as const).map((n) => (
              <li key={n}>
                <Icon name={PROMISE_ICONS[n - 1]} size={22} />
                <span>{t(`site.home.privacy${n}` as 'site.home.privacy1')}</span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className={styles.sec}>
        <div className="container">
          <div className={styles.cta}>
            <div className={styles.ctaCopy}>
              <h2 className={shared.h2}>{t('site.home.ctaTitle')}</h2>
              <p className={shared.lead}>{t('site.home.ctaText')}</p>
            </div>
            <div className={styles.ctaButtons}>
              <StoreButton store="android" href={stores.android} note={false} />
              <StoreButton store="ios" href={stores.ios} note={false} />
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
