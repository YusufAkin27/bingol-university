// SAYFA: Uygulamayı indir (/download)
// API: useStoreLinks() → GET /api/app/info (info.stores varsa) ya da GET /api/app/version?platform=ANDROID|IOS (storeUrl).
// "Yayında / Yakında" durumu yönetimdeki mağaza bağlantısı ayarından (store_url_android / store_url_ios) türer:
// bağlantı varsa yayında, yoksa yakında. Rozet bağlantısız TIKLANAMAZ; uydurma mağaza adresi, QR kod, sürüm/boyut/
// sistem gereksinimi sayısı YOK (yalnız doğrulanabilir bilgi).
import { useAppInfo, useStoreLinks } from '../../api/hooks';
import { Breadcrumbs } from '../../components/Breadcrumbs';
import { ButtonLink, Icon } from '../../components/ui';
import type { IconName } from '../../components/ui/Icon';
import { useI18n } from '../../i18n/I18nProvider';
import { paths } from '../../paths';
import { siteOrigin } from '../../seo/siteUrl';
import { mobileAppLd } from './components/jsonLd';
import { MaintenanceNotice } from './components/Notices';
import { useHeadingFocus } from './components/PageHero';
import { PhoneMockup } from './components/PhoneMockup';
import { Reveal } from './components/Reveal';
import { SectionHeading } from './components/SectionHeading';
import type { ShotId } from './components/screenshots';
import { Steps } from './components/Steps';
import { StoreButton } from './components/StoreButton';
import { usePageMeta } from './components/usePageMeta';
import styles from './DownloadPage.module.css';

const SHOWCASE: { shot: ShotId; title: 'site.show.menu.title' | 'site.show.events.title' | 'site.show.chat.title' }[] = [
  { shot: 'menu', title: 'site.show.menu.title' },
  { shot: 'events', title: 'site.show.events.title' },
  { shot: 'chat', title: 'site.show.chat.title' },
];

const REQUIREMENTS: { id: 'account' | 'android' | 'ios'; icon: IconName }[] = [
  { id: 'account', icon: 'mail' },
  { id: 'android', icon: 'smartphone' },
  { id: 'ios', icon: 'smartphone' },
];

export default function DownloadPage() {
  const { t } = useI18n();
  const stores = useStoreLinks();
  const info = useAppInfo();
  const origin = siteOrigin();
  const h1 = useHeadingFocus<HTMLHeadingElement>();
  usePageMeta({
    route: 'download',
    jsonLd: mobileAppLd(info.data, stores, origin),
  });
  const contactEmail = info.data?.supportEmail || info.data?.contactEmail || null;
  const platforms = [
    { id: 'android', name: t('site.download.android'), href: stores.android },
    { id: 'ios', name: t('site.download.ios'), href: stores.ios },
  ] as const;

  return (
    <>
      <section className={styles.hero}>
        <div className={`container ${styles.heroGrid}`}>
          <div className={styles.heroCopy}>
            <MaintenanceNotice />
            <Breadcrumbs items={[{ label: t('site.nav.download') }]} />
            <p className={styles.eyebrow}>{t('site.v3.eyebrow')}</p>
            <h1 ref={h1} tabIndex={-1} className={styles.title}>
              {t('site.download.title')}
            </h1>
            <p className={styles.lead}>{t('site.download.lead')}</p>

            {/* durum bilgi yüklenene kadar yalnız platform adı görünür (yanlış "Yakında" yanıp sönmesin) */}
            <ul className={styles.status} aria-label={t('site.rd03.status.label')}>
              {platforms.map((p) => (
                <li key={p.id} className={`${styles.chip} ${stores.isLoading ? '' : p.href ? styles.live : styles.soon}`}>
                  <span className={styles.dot} aria-hidden="true" />
                  {p.name}
                  {!stores.isLoading && (
                    <span className={styles.chipState}>{p.href ? t('site.rd03.status.live') : t('site.rd03.status.soon')}</span>
                  )}
                </li>
              ))}
            </ul>

            <div className={styles.stores}>
              <StoreButton store="android" href={stores.android} size="lg" note={false} />
              <StoreButton store="ios" href={stores.ios} size="lg" note={false} />
            </div>

            <div className={styles.note}>
              <Icon name="shield" size={20} />
              <div>
                <strong>{t('site.download.noteTitle')}</strong>
                <p>{t('site.download.note')}</p>
                <p className={styles.independent}>{t('site.v3.independent')}</p>
              </div>
            </div>
          </div>

          <div className={styles.visual}>
            <span className={styles.glow} aria-hidden="true" />
            <PhoneMockup shot="home" tilt={-1.5} priority className={styles.front} />
            <PhoneMockup shot="clubs" tilt={3} className={styles.back} />
          </div>
        </div>
      </section>

      <section className={styles.sec} aria-labelledby="dl-req">
        <div className="container">
          <SectionHeading id="dl-req" title={t('site.rd03.reqTitle')} lead={t('site.rd03.reqLead')} />
          <ul className={styles.reqs}>
            {REQUIREMENTS.map((r, i) => (
              <li key={r.id}>
                <Reveal delay={i * 80} className={styles.req}>
                  <span className={styles.reqIcon}>
                    <Icon name={r.icon} size={22} />
                  </span>
                  <h3 className={styles.reqTitle}>{t(`site.rd03.req.${r.id}.title` as 'site.rd03.req.account.title')}</h3>
                  <p className={styles.reqText}>{t(`site.rd03.req.${r.id}.text` as 'site.rd03.req.account.text')}</p>
                </Reveal>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className={`${styles.sec} ${styles.tint}`} aria-labelledby="dl-after">
        <div className="container">
          <SectionHeading id="dl-after" title={t('site.download.afterTitle')} />
          <Steps
            items={([1, 2, 3] as const).map((n) => ({
              title: t(`site.download.after${n}` as 'site.download.after1'),
            }))}
          />
        </div>
      </section>

      <section className={styles.sec} aria-labelledby="dl-shots">
        <div className="container">
          <SectionHeading id="dl-shots" title={t('site.rd03.shotsTitle')} lead={t('site.rd03.shotsLead')} />
          <ul className={styles.shots}>
            {SHOWCASE.map((s, i) => (
              <li key={s.shot}>
                <Reveal delay={i * 90} className={styles.shot}>
                  <PhoneMockup shot={s.shot} />
                  <p className={styles.shotCaption}>{t(s.title)}</p>
                </Reveal>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className={styles.helpWrap} aria-labelledby="dl-help">
        <div className="container">
          <Reveal className={styles.help}>
            <span className={styles.helpIcon}>
              <Icon name="lifebuoy" size={24} />
            </span>
            <div className={styles.helpCopy}>
              <h2 id="dl-help" className={styles.helpTitle}>
                {t('site.rd03.help.title')}
              </h2>
              <p>{t('site.rd03.help.text')}</p>
            </div>
            <div className={styles.helpActions}>
              {contactEmail && (
                <a className={styles.mail} href={`mailto:${contactEmail}`}>
                  <Icon name="mail" size={18} />
                  <span dir="ltr">{contactEmail}</span>
                </a>
              )}
              <ButtonLink to={paths.site.help}>{t('site.rd03.help.center')}</ButtonLink>
              <ButtonLink to={paths.site.faq} variant="secondary">
                {t('site.nav.faq')}
              </ButtonLink>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
