// SAYFA: Ana sayfa (/)
// API: GET /api/app/info (useAppInfo: bakım/iletişim), mağaza bağlantıları için useStoreLinks (info.stores ya da GET /api/app/version).
// Yapı: Hero (başlık + iki mağaza rozeti + 2 telefon) > ekran vitrini (4 kart) > 3 adım > güvenlik/gizlilik > alt CTA.
// Mobil öncelikli (390 px); telefon görselleri uygulamanın kendi ekran çıktılarıdır (bkz. components/screenshots.ts).
import { Link } from '../../components/LocalizedLink';
import { useAppInfo, useStoreLinks } from '../../api/hooks';
import { Icon, type IconName } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { siteOrigin } from '../../seo/siteUrl';
import { CtaBand } from './components/CtaBand';
import { SHOWCASE } from './components/features';
import { mobileAppLd, organizationLd } from './components/jsonLd';
import { MaintenanceNotice } from './components/Notices';
import { useHeadingFocus } from './components/PageHero';
import { PhoneMockup } from './components/PhoneMockup';
import { PointList, type Point } from './components/PointList';
import { Reveal } from './components/Reveal';
import { SectionHeading } from './components/SectionHeading';
import { Steps } from './components/Steps';
import { StoreButton } from './components/StoreButton';
import { usePageMeta } from './components/usePageMeta';
import styles from './HomePage.module.css';

/** Ana sayfada kart olarak gösterilen vitrin özellikleri (tümü Özellikler sayfasında). */
const TILES = SHOWCASE.filter((s) => ['menu', 'chat', 'clubs', 'events'].includes(s.id));
const PRIVACY_ICONS: IconName[] = ['shield', 'download', 'eyeOff', 'message'];

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

  const privacy: Point[] = ([1, 2, 3, 4] as const).map((n) => ({
    icon: PRIVACY_ICONS[n - 1],
    text: t(`site.home.privacy${n}` as 'site.home.privacy1'),
  }));

  return (
    <>
      <section className={styles.hero} aria-labelledby="home-title">
        <div className={`container ${styles.inner}`}>
          <div className={styles.copy}>
            <MaintenanceNotice />
            <p className={styles.eyebrow}>{t('site.v3.eyebrow')}</p>
            <h1 id="home-title" ref={h1} tabIndex={-1} className={styles.title}>
              {t('site.home.heroTitle')}
            </h1>
            <p className={styles.lead}>{t('site.home.heroLead')}</p>
            <div className={styles.badges}>
              <StoreButton store="android" href={stores.android} size="lg" note={false} />
              <StoreButton store="ios" href={stores.ios} size="lg" note={false} />
            </div>
            <p className={styles.trust}>
              <Icon name="shield" size={18} />
              {t('site.home.trust')}
            </p>
            <Link to={paths.site.features} className={styles.more}>
              {t('site.home.ctaFeatures')}
              <Icon name="chevronRight" size={18} className={styles.moreIcon} />
            </Link>
          </div>
          <div className={styles.stage}>
            <span className={styles.glow} aria-hidden="true" />
            <PhoneMockup shot="discover" tilt={6} className={styles.back} />
            <PhoneMockup shot="home" tilt={-2} priority className={styles.front} />
          </div>
        </div>
      </section>

      <section className={styles.sec} aria-labelledby="home-show">
        <div className="container">
          <SectionHeading
            id="home-show"
            title={t('site.v3.home.showTitle')}
            lead={t('site.v3.home.showLead')}
            align="center"
          />
          <ul className={styles.tiles}>
            {TILES.map((s, i) => (
              <li key={s.id}>
                <Reveal delay={i * 80} className={styles.tile}>
                  <div className={styles.tileShot}>
                    <PhoneMockup shot={s.shot} crop={0.62} className={styles.tilePhone} />
                  </div>
                  <h3 className={styles.tileTitle}>{t(s.title)}</h3>
                  <p className={styles.tileText}>{t(s.text)}</p>
                </Reveal>
              </li>
            ))}
          </ul>
          <p className={styles.all}>
            <Link to={paths.site.features} className={styles.more}>
              {t('site.home.allFeatures')}
              <Icon name="chevronRight" size={18} className={styles.moreIcon} />
            </Link>
          </p>
        </div>
      </section>

      <section className={`${styles.sec} ${styles.soft}`} aria-labelledby="home-steps">
        <div className="container">
          <SectionHeading id="home-steps" title={t('site.home.stepsTitle')} />
          <div className={styles.stepsWrap}>
            <Steps
              items={([1, 2, 3] as const).map((n) => ({
                title: t(`site.home.step${n}.title` as 'site.home.step1.title'),
                text: t(`site.home.step${n}.text` as 'site.home.step1.text'),
              }))}
            />
          </div>
        </div>
      </section>

      <section className={styles.sec} aria-labelledby="home-privacy">
        <div className={`container ${styles.privacy}`}>
          <div className={styles.privacyHead}>
            <SectionHeading id="home-privacy" title={t('site.home.privacyTitle')} lead={t('site.home.trust')} />
            <Link to={paths.site.legal('PRIVACY')} className={styles.more}>
              {t('site.home.privacyLink')}
              <Icon name="chevronRight" size={18} className={styles.moreIcon} />
            </Link>
          </div>
          <PointList items={privacy} />
        </div>
      </section>

      <CtaBand title={t('site.home.ctaTitle')} text={t('site.v3.cta.text')} />
    </>
  );
}
