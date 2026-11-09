// SAYFA: Ana sayfa (/)
// API: GET /api/app/info (useAppInfo: bakım/iletişim), mağaza bağlantıları için useStoreLinks (info.stores ya da GET /api/app/version).
// Yapı: Hero (ortalı başlık + iki mağaza rozeti + alttan solan 3 telefon) > kampüsün sosyal tarafı (Keşfet telefonu + 4 madde) > ekran vitrini (4 kart, 2x2)
//       > 3 adım > öğrencilere özel güvenli alan (reklamsız, moderasyonlu) > alt CTA.
// Keşfet ekranı: uydurma, kampüs temalı içerikle üretilmiş GERÇEK uygulama görüntüsü (mobile/test/web_shots; gerçek kişi/fotoğraf yok).
// Mobil öncelikli (390 px); telefon görselleri uygulamanın kendi ekran çıktılarıdır (bkz. components/screenshots.ts).
import { Link } from '../../components/LocalizedLink';
import { useAppInfo, useStoreLinks } from '../../api/hooks';
import { Icon, type IconName } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { siteOrigin } from '../../seo/siteUrl';
import { CtaBand } from './components/CtaBand';
import { SHOWCASE } from './components/features';
import { mobileAppLd, organizationLd, websiteLd } from './components/jsonLd';
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
const TILES = SHOWCASE.filter((s) => ['clubs', 'events', 'menu', 'profile'].includes(s.id));
const SOCIAL_ICONS: IconName[] = ['image', 'users', 'community', 'message'];
const SAFE_ICONS: IconName[] = ['eyeOff', 'shield', 'check', 'download'];

export default function HomePage() {
  const { t } = useI18n();
  const stores = useStoreLinks();
  const info = useAppInfo();
  const h1 = useHeadingFocus<HTMLHeadingElement>();
  const origin = siteOrigin();
  usePageMeta({
    route: 'home',
    jsonLd: [websiteLd(info.data, origin), organizationLd(info.data, origin), mobileAppLd(info.data, stores, origin)],
  });

  const safe: Point[] = ([1, 2, 3, 4] as const).map((n) => ({
    icon: SAFE_ICONS[n - 1],
    text: t(`site.home.safe${n}` as 'site.home.safe1'),
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
              <span>{t('site.home.trust')}</span>
            </p>
            <Link to={paths.site.features} className={styles.more}>
              {t('site.home.ctaFeatures')}
              <Icon name="chevronRight" size={18} className={styles.moreIcon} />
            </Link>
          </div>
          {/* Üç telefon yelpazesi: ortadaki önde ve büyük (LCP), yanlar biraz aşağıda; hepsi alttan solar */}
          <div className={styles.stage}>
            <PhoneMockup shot="clubs" crop={0.6} className={styles.sideStart} />
            <PhoneMockup shot="home" crop={0.66} priority className={styles.center} />
            <PhoneMockup shot="profile" crop={0.6} className={styles.sideEnd} />
          </div>
        </div>
      </section>

      <section className={styles.sec} aria-labelledby="home-social">
        <div className={`container ${styles.social}`}>
          <div className={styles.socialCopy}>
            <SectionHeading id="home-social" title={t('site.home.social.title')} lead={t('site.home.social.lead')} />
            <ul className={styles.socialList}>
              {([1, 2, 3, 4] as const).map((n, i) => (
                <li key={n}>
                  <Reveal delay={(i % 2) * 70} className={styles.socialItem}>
                    <span className={styles.socialIco}>
                      <Icon name={SOCIAL_ICONS[n - 1]} size={20} />
                    </span>
                    <div>
                      <h3 className={styles.socialTitle}>{t(`site.home.social.p${n}.title` as 'site.home.social.p1.title')}</h3>
                      <p className={styles.socialText}>{t(`site.home.social.p${n}.text` as 'site.home.social.p1.text')}</p>
                    </div>
                  </Reveal>
                </li>
              ))}
            </ul>
          </div>
          <Reveal className={styles.socialFigure} delay={80}>
            <PhoneMockup shot="discover" crop={0.78} width="min(100%, 260px)" />
          </Reveal>
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
                <Reveal delay={(i % 2) * 80} className={styles.tile}>
                  <h3 className={styles.tileTitle}>{t(s.title)}</h3>
                  <p className={styles.tileText}>{t(s.text)}</p>
                  <div className={styles.tileShot}>
                    <PhoneMockup shot={s.shot} crop={0.56} />
                  </div>
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

      <section className={styles.sec} aria-labelledby="home-safe">
        <div className={`container ${styles.privacy}`}>
          <div className={styles.privacyHead}>
            <SectionHeading id="home-safe" title={t('site.home.safe.title')} lead={t('site.home.safe.lead')} />
            <Link to={paths.site.legal('PRIVACY')} className={styles.more}>
              {t('site.home.privacyLink')}
              <Icon name="chevronRight" size={18} className={styles.moreIcon} />
            </Link>
          </div>
          <PointList items={safe} />
        </div>
      </section>

      <CtaBand title={t('site.home.ctaTitle')} text={t('site.v3.cta.text')} />
    </>
  );
}
