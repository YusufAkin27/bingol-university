// SAYFA: Ana sayfa (/)
// API: GET /api/app/info (useAppInfo: bakım/iletişim), mağaza bağlantıları için useStoreLinks (info.stores ya da GET /api/app/version).
// Yapı: Hero (başlık + mağaza rozetleri + 2 büyük telefon) > ekran vitrini (4 kart, tam boy telefon) > 3 adım > güvenlik/gizlilik > alt CTA.
// Mobil öncelikli (390 px); telefon görselleri uygulamanın kendi ekran çıktılarıdır (bkz. components/screenshots.ts).
import { useEffect, useRef, useState } from 'react';
import { Link } from '../../components/LocalizedLink';
import { useAppInfo, useStoreLinks } from '../../api/hooks';
import { ContourBackdrop, Icon, type IconName } from '../../components/ui';
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
const TILES = SHOWCASE.filter((s) => ['menu', 'chat', 'clubs', 'events'].includes(s.id));
const PRIVACY_ICONS: IconName[] = ['shield', 'download', 'eyeOff', 'message'];
const STEP_ICONS: IconName[] = ['download', 'mail', 'check'];
/** Hero'daki kısa modül etiketleri (vitrin başlıklarından; uydurma sayı/iddia yok). */
const CHIPS = SHOWCASE.filter((s) => ['menu', 'events', 'chat', 'clubs'].includes(s.id));

/** Yatay şerit taşıyorsa (mobil) klavyeyle odaklanıp kaydırılabilsin; taşmıyorsa gereksiz sekme durağı olmasın. */
function useScrollable<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [scrollable, setScrollable] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return undefined;
    const measure = () => setScrollable(el.scrollWidth > el.clientWidth + 1);
    measure();
    if (typeof ResizeObserver === 'undefined') return undefined;
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, scrollable] as const;
}

export default function HomePage() {
  const { t } = useI18n();
  const stores = useStoreLinks();
  const info = useAppInfo();
  const h1 = useHeadingFocus<HTMLHeadingElement>();
  const [tilesRef, tilesScroll] = useScrollable<HTMLUListElement>();
  const origin = siteOrigin();
  usePageMeta({
    route: 'home',
    jsonLd: [websiteLd(info.data, origin), organizationLd(info.data, origin), mobileAppLd(info.data, stores, origin)],
  });

  const privacy: Point[] = ([1, 2, 3, 4] as const).map((n) => ({
    icon: PRIVACY_ICONS[n - 1],
    text: t(`site.home.privacy${n}` as 'site.home.privacy1'),
  }));

  return (
    <>
      <section className={styles.hero} aria-labelledby="home-title">
        <ContourBackdrop className={styles.contour} />
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
            <ul className={styles.chips} aria-label={t('site.nav.features')}>
              {CHIPS.map((s) => (
                <li key={s.id}>{t(s.title)}</li>
              ))}
            </ul>
            <Link to={paths.site.features} className={styles.more}>
              {t('site.home.ctaFeatures')}
              <Icon name="chevronRight" size={18} className={styles.moreIcon} />
            </Link>
          </div>
          <div className={styles.stage}>
            <span className={styles.glow} aria-hidden="true" />
            <PhoneMockup shot="home" tilt={-2} priority className={styles.front} />
            <PhoneMockup shot="discover" tilt={4} className={styles.back} />
          </div>
        </div>
      </section>

      <section className={styles.sec} aria-labelledby="home-show">
        <div className="container">
          <SectionHeading
            id="home-show"
            eyebrow={t('site.nav.features')}
            title={t('site.v3.home.showTitle')}
            lead={t('site.v3.home.showLead')}
            align="center"
          />
        </div>
        <div className={`container ${styles.tilesWrap}`}>
          <ul
            ref={tilesRef}
            className={styles.tiles}
            tabIndex={tilesScroll ? 0 : undefined}
            aria-labelledby={tilesScroll ? 'home-show' : undefined}
          >
            {TILES.map((s, i) => (
              <li key={s.id} className={styles.tileItem}>
                <Reveal delay={(i % 4) * 80} className={styles.tile}>
                  <h3 className={styles.tileTitle}>{t(s.title)}</h3>
                  <p className={styles.tileText}>{t(s.text)}</p>
                  <div className={styles.tileShot}>
                    <PhoneMockup shot={s.shot} className={styles.tilePhone} />
                  </div>
                </Reveal>
              </li>
            ))}
          </ul>
        </div>
        <div className="container">
          <p className={styles.all}>
            <Link to={paths.site.features} className={styles.allLink}>
              {t('site.home.allFeatures')}
              <Icon name="chevronRight" size={18} className={styles.moreIcon} />
            </Link>
          </p>
        </div>
      </section>

      <section className={`${styles.sec} ${styles.soft}`} aria-labelledby="home-steps">
        <div className="container">
          <SectionHeading id="home-steps" title={t('site.home.stepsTitle')} align="center" />
          <div className={styles.stepsWrap}>
            <Steps
              items={([1, 2, 3] as const).map((n) => ({
                title: t(`site.home.step${n}.title` as 'site.home.step1.title'),
                text: t(`site.home.step${n}.text` as 'site.home.step1.text'),
                icon: STEP_ICONS[n - 1],
              }))}
            />
          </div>
        </div>
      </section>

      <section className={styles.sec} aria-labelledby="home-privacy">
        <div className="container">
          <SectionHeading
            id="home-privacy"
            eyebrow={t('site.rd01.privacyEyebrow')}
            title={t('site.home.privacyTitle')}
            lead={t('site.home.trust')}
            align="center"
          />
          <div className={styles.privacyBody}>
            <PointList items={privacy} columns={4} />
          </div>
          <p className={styles.all}>
            <Link to={paths.site.legal('PRIVACY')} className={styles.more}>
              {t('site.home.privacyLink')}
              <Icon name="chevronRight" size={18} className={styles.moreIcon} />
            </Link>
          </p>
        </div>
      </section>

      <CtaBand title={t('site.home.ctaTitle')} text={t('site.v3.cta.text')} />
    </>
  );
}
