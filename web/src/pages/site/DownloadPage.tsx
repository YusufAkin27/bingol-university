// SAYFA: Uygulamayı indir (/download)
// API: useStoreLinks() → GET /api/app/info (info.stores varsa) ya da GET /api/app/version?platform=ANDROID|IOS (storeUrl).
// Bağlantı yoksa rozet "Yakında" durumunda ve tıklanamaz; uydurma mağaza adresi YOK. QR kod gösterilmez.
import { useAppInfo, useStoreLinks } from '../../api/hooks';
import { Icon } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { siteOrigin } from '../../seo/siteUrl';
import { mobileAppLd } from './components/jsonLd';
import { PageHero } from './components/PageHero';
import { PhoneMockup } from './components/PhoneMockup';
import { Reveal } from './components/Reveal';
import { SectionHeading } from './components/SectionHeading';
import { Steps } from './components/Steps';
import { StoreButton } from './components/StoreButton';
import { AppleIcon, GooglePlayIcon } from './components/StoreIcons';
import { usePageMeta } from './components/usePageMeta';
import styles from './DownloadPage.module.css';

export default function DownloadPage() {
  const { t } = useI18n();
  const stores = useStoreLinks();
  const info = useAppInfo();
  const origin = siteOrigin();
  usePageMeta({
    route: 'download',
    jsonLd: mobileAppLd(info.data, stores, origin, t('seo.d.home')),
  });
  return (
    <>
      <PageHero eyebrow={t('site.v3.eyebrow')} title={t('site.download.title')} lead={t('site.download.lead')} />
      <section className={styles.sec}>
        <div className={`container ${styles.layout}`}>
          <div className={styles.main}>
            <div className={styles.platforms}>
              <div className={styles.platform}>
                <span className={styles.glyph}>
                  <GooglePlayIcon width={22} height={22} />
                </span>
                <h2 className={styles.platformTitle}>{t('site.download.android')}</h2>
                <StoreButton store="android" href={stores.android} size="lg" />
              </div>
              <div className={styles.platform}>
                <span className={styles.glyph}>
                  <AppleIcon width={22} height={22} />
                </span>
                <h2 className={styles.platformTitle}>{t('site.download.ios')}</h2>
                <StoreButton store="ios" href={stores.ios} size="lg" />
              </div>
            </div>

            <div className={styles.after}>
              <SectionHeading level={3} title={t('site.download.afterTitle')} />
              <Steps
                items={([1, 2, 3] as const).map((n) => ({
                  title: t(`site.download.after${n}` as 'site.download.after1'),
                }))}
              />
            </div>

            <Reveal className={styles.note}>
              <Icon name="info" size={20} />
              <div>
                <strong>{t('site.download.noteTitle')}</strong>
                <p>{t('site.download.note')}</p>
                <p className={styles.independent}>{t('site.v3.independent')}</p>
              </div>
            </Reveal>
          </div>
          <div className={styles.visual}>
            <span className={styles.glow} aria-hidden="true" />
            <PhoneMockup shot="clubs" tilt={4} className={styles.back} />
            <PhoneMockup shot="home" tilt={-1.5} priority className={styles.front} />
          </div>
        </div>
      </section>
    </>
  );
}
